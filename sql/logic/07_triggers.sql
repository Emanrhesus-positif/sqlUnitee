-- ============================================================================
-- UNITEE - Triggers
-- Fichier : 07_triggers.sql
-- Correspond aux tables : annonces, qualification_scores, notifications,
--                         log_technique, log_metier, historique_annonces
-- ============================================================================

USE unitee;

DELIMITER $$

DROP TRIGGER IF EXISTS avant_insert_annonce $$
DROP TRIGGER IF EXISTS apres_insert_annonce $$
DROP TRIGGER IF EXISTS apres_update_annonce $$
DROP TRIGGER IF EXISTS avant_delete_annonce $$
DROP TRIGGER IF EXISTS apres_insert_notification $$
DROP TRIGGER IF EXISTS avant_insert_score $$

-- ============================================================================
-- TRIGGER 1 : avant_insert_annonce
-- Événement : BEFORE INSERT ON annonces
-- Rôle : Valide les données avant écriture, applique les valeurs par défaut
-- Contrôles :
--   - titre obligatoire et non vide
--   - id_externe obligatoire
--   - date_publication <= date_limite_reponse
--   - montant_estime >= 0 si fourni
--   - normalisation automatique de la région si absente
-- ============================================================================

CREATE TRIGGER avant_insert_annonce
BEFORE INSERT ON annonces
FOR EACH ROW
BEGIN
    -- Titre obligatoire
    IF NEW.titre IS NULL OR TRIM(NEW.titre) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Le titre de l''annonce est obligatoire';
    END IF;

    -- Identifiant externe obligatoire
    IF NEW.id_externe IS NULL OR TRIM(NEW.id_externe) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'L''identifiant externe (id_externe) est obligatoire';
    END IF;

    -- Cohérence des dates
    IF NEW.date_publication IS NOT NULL AND NEW.date_limite_reponse IS NOT NULL THEN
        IF NEW.date_limite_reponse < NEW.date_publication THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La date limite de réponse ne peut pas précéder la date de publication';
        END IF;
    END IF;

    -- Montant positif
    IF NEW.montant_estime IS NOT NULL AND NEW.montant_estime < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Le montant estimé doit être positif ou NULL';
    END IF;

    -- Normalisation région si absente
    IF NEW.region IS NULL OR TRIM(NEW.region) = '' THEN
        SET NEW.region = NormaliserRegion(NEW.localisation);
    END IF;

    -- Valeurs par défaut
    IF NEW.devise IS NULL OR NEW.devise = '' THEN
        SET NEW.devise = 'EUR';
    END IF;

    IF NEW.statut IS NULL OR NEW.statut = '' THEN
        SET NEW.statut = 'NEW';
    END IF;

    SET NEW.timestamp_import = COALESCE(NEW.timestamp_import, NOW());
    SET NEW.timestamp_maj    = NOW();
END $$

-- ============================================================================
-- TRIGGER 2 : apres_insert_annonce
-- Événement : AFTER INSERT ON annonces
-- Rôle : Calcule automatiquement le score, insère dans qualification_scores,
--        crée une notification si le niveau d'alerte est CRITIQUE ou URGENT,
--        trace l'opération dans log_technique
-- ============================================================================

CREATE TRIGGER apres_insert_annonce
AFTER INSERT ON annonces
FOR EACH ROW
BEGIN
    DECLARE v_score       INT;
    DECLARE v_jours       INT;
    DECLARE v_niveau      VARCHAR(50);

    -- Calcul du score de pertinence via la fonction métier
    SET v_score  = CalculerScorePertinence(
                        NEW.titre, NEW.description, NEW.montant_estime,
                        NEW.region, NEW.date_limite_reponse);

    SET v_jours  = DATEDIFF(NEW.date_limite_reponse, NOW());
    SET v_niveau = CategoriserAlerte(v_score, v_jours);

    -- Insertion du score (relation 1:1 avec annonces)
    INSERT INTO qualification_scores (
        annonce_id, score_pertinence, niveau_alerte, raison_scoring, date_calcul
    ) VALUES (
        NEW.id_annonce, v_score, v_niveau,
        CONCAT('Score auto: keywords+montant+region+deadline. Niveau: ', v_niveau),
        NOW()
    );

    -- Notification si opportunité critique ou urgente
    IF v_niveau IN ('CRITIQUE', 'URGENT') THEN
        INSERT INTO notifications (
            annonce_id, type_alerte, statut, priorite, message, date_creation
        ) VALUES (
            NEW.id_annonce,
            CASE v_niveau WHEN 'CRITIQUE' THEN 'OPPORTUNITE_CRITIQUE'
                          ELSE 'OPPORTUNITE_URGENTE' END,
            'NEW',
            CASE v_niveau WHEN 'CRITIQUE' THEN 1 ELSE 2 END,
            CONCAT('[', v_niveau, '] Score ', v_score, '/100 - Délai : ', v_jours, ' jours - ', NEW.titre),
            NOW()
        );
    END IF;

    -- Trace dans log_technique
    INSERT INTO log_technique (type_operation, source_operation, status, message)
    VALUES ('IMPORT_ANNONCE', 'trigger:apres_insert_annonce', 'OK',
            CONCAT('Annonce #', NEW.id_annonce, ' importée. Score=', v_score, ' Niveau=', v_niveau));
END $$

-- ============================================================================
-- TRIGGER 3 : apres_update_annonce
-- Événement : AFTER UPDATE ON annonces
-- Rôle : Détecte les champs modifiés, recalcule le score si pertinent,
--        et trace le changement dans log_metier
-- ============================================================================

CREATE TRIGGER apres_update_annonce
AFTER UPDATE ON annonces
FOR EACH ROW
BEGIN
    DECLARE v_score  INT;
    DECLARE v_jours  INT;
    DECLARE v_niveau VARCHAR(50);

    -- Recalcul si données métier modifiées
    IF NOT (OLD.titre              <=> NEW.titre)
    OR NOT (OLD.montant_estime     <=> NEW.montant_estime)
    OR NOT (OLD.date_limite_reponse <=> NEW.date_limite_reponse)
    OR NOT (OLD.region             <=> NEW.region) THEN

        SET v_score  = CalculerScorePertinence(
                            NEW.titre, NEW.description, NEW.montant_estime,
                            NEW.region, NEW.date_limite_reponse);
        SET v_jours  = DATEDIFF(NEW.date_limite_reponse, NOW());
        SET v_niveau = CategoriserAlerte(v_score, v_jours);

        UPDATE qualification_scores
        SET score_pertinence = v_score,
            niveau_alerte    = v_niveau,
            raison_scoring   = CONCAT('Recalcul après modification. Niveau: ', v_niveau),
            date_maj         = NOW()
        WHERE annonce_id = NEW.id_annonce;
    END IF;

    -- Traçabilité : enregistrement dans log_metier
    INSERT INTO log_metier (annonce_id, type_operation, utilisateur, description, avant_state, apres_state)
    VALUES (
        NEW.id_annonce,
        'MISE_A_JOUR',
        'systeme',
        'Mise à jour annonce',
        JSON_OBJECT('statut', OLD.statut, 'montant', OLD.montant_estime),
        JSON_OBJECT('statut', NEW.statut, 'montant', NEW.montant_estime)
    );
END $$

-- ============================================================================
-- TRIGGER 4 : avant_delete_annonce
-- Événement : BEFORE DELETE ON annonces
-- Rôle : Archive les données avant suppression (conformité RGPD)
--        L'annonce supprimée est conservée dans historique_annonces
-- ============================================================================

CREATE TRIGGER avant_delete_annonce
BEFORE DELETE ON annonces
FOR EACH ROW
BEGIN
    INSERT INTO historique_annonces (
        annonce_id, type_modification, colonne_modifiee,
        valeur_ancienne, valeur_nouvelle
    ) VALUES (
        OLD.id_annonce,
        'SUPPRESSION',
        'COMPLET',
        CONCAT('titre=', OLD.titre, '|statut=', OLD.statut, '|montant=', COALESCE(OLD.montant_estime, 'NULL')),
        NULL
    );
END $$

-- ============================================================================
-- TRIGGER 5 : apres_insert_notification
-- Événement : AFTER INSERT ON notifications
-- Rôle : Trace la création de chaque notification dans log_technique
-- ============================================================================

CREATE TRIGGER apres_insert_notification
AFTER INSERT ON notifications
FOR EACH ROW
BEGIN
    INSERT INTO log_technique (type_operation, source_operation, status, message)
    VALUES (
        'CREATION_NOTIFICATION',
        'trigger:apres_insert_notification',
        'OK',
        CONCAT('Notification #', NEW.id_notification,
               ' créée pour annonce #', NEW.annonce_id,
               ' - Type: ', NEW.type_alerte,
               ' - Priorité: ', NEW.priorite)
    );
END $$

-- ============================================================================
-- TRIGGER 6 : avant_insert_score
-- Événement : BEFORE INSERT ON qualification_scores
-- Rôle : Valide que le score est bien dans la plage 0-100
-- ============================================================================

CREATE TRIGGER avant_insert_score
BEFORE INSERT ON qualification_scores
FOR EACH ROW
BEGIN
    IF NEW.score_pertinence < 0 OR NEW.score_pertinence > 100 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'score_pertinence doit être compris entre 0 et 100';
    END IF;
END $$

DELIMITER ;
