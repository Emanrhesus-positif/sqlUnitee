-- ============================================================================
-- UNITEE - Procédures stockées
-- Fichier : 06_procedures.sql
-- Correspond aux tables : annonces, qualification_scores, log_technique, log_metier
-- ============================================================================

USE unitee;

DELIMITER $$

DROP PROCEDURE IF EXISTS InsererAnnonce $$
DROP PROCEDURE IF EXISTS TraiterLotAnnonces $$
DROP PROCEDURE IF EXISTS GenererKPIDashboard $$
DROP PROCEDURE IF EXISTS ArchiverDonneesAnciennes $$

-- ============================================================================
-- PROCÉDURE 1 : InsererAnnonce
-- Rôle : Insère ou met à jour une annonce avec contrôle doublon et traçabilité
-- Paramètres IN :
--   p_nom_source          - Nom de la source (doit exister dans sources)
--   p_id_externe          - Identifiant externe fourni par la source
--   p_titre               - Titre de l'annonce
--   p_description         - Description complète
--   p_montant_estime      - Montant estimé EUR
--   p_date_publication    - Date de publication
--   p_date_limite_reponse - Date limite de réponse
--   p_localisation        - Lieu d'exécution
--   p_region              - Région (si NULL, NormaliserRegion est appelé)
--   p_id_acheteur         - ID acheteur dans la table acheteurs
--   p_lien_source         - URL de l'annonce source
-- Paramètres OUT :
--   p_annonce_id          - ID de l'annonce insérée ou mise à jour (-1 si erreur)
--   p_statut              - 'INSEREE', 'MISE_A_JOUR', 'ERREUR'
--   p_message             - Message descriptif du résultat
-- Transaction : START / COMMIT / ROLLBACK en cas d'erreur SQL
-- ============================================================================

CREATE PROCEDURE InsererAnnonce(
    IN  p_nom_source          VARCHAR(100),
    IN  p_id_externe          VARCHAR(255),
    IN  p_titre               VARCHAR(500),
    IN  p_description         LONGTEXT,
    IN  p_montant_estime      DECIMAL(15,2),
    IN  p_date_publication    DATETIME,
    IN  p_date_limite_reponse DATETIME,
    IN  p_localisation        VARCHAR(255),
    IN  p_region              VARCHAR(100),
    IN  p_id_acheteur         INT,
    IN  p_lien_source         VARCHAR(500),
    OUT p_annonce_id          INT,
    OUT p_statut              VARCHAR(50),
    OUT p_message             VARCHAR(255)
)
SQL SECURITY INVOKER
NOT DETERMINISTIC
MODIFIES SQL DATA
main_block: BEGIN
    DECLARE v_id_source  INT;
    DECLARE v_existant   INT;
    DECLARE v_region     VARCHAR(100);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_annonce_id = -1;
        SET p_statut     = 'ERREUR';
        SET p_message    = 'Erreur SQL : transaction annulée';
        ROLLBACK;
    END;

    START TRANSACTION;

    -- 1. Résoudre l'id_source à partir du nom
    SELECT id_source INTO v_id_source
    FROM sources
    WHERE nom_source = p_nom_source
    LIMIT 1;

    IF v_id_source IS NULL THEN
        SET p_annonce_id = -1;
        SET p_statut     = 'ERREUR';
        SET p_message    = CONCAT('Source introuvable : ', p_nom_source);
        ROLLBACK;
        LEAVE main_block;
    END IF;

    -- 2. Normaliser la région si non fournie
    SET v_region = IF(p_region IS NULL OR p_region = '',
                     NormaliserRegion(p_localisation),
                     p_region);

    -- 3. Détection doublon : même source + même id_externe
    SELECT id_annonce INTO v_existant
    FROM annonces
    WHERE id_source  = v_id_source
      AND id_externe = p_id_externe
    LIMIT 1;

    IF v_existant IS NOT NULL THEN
        -- DOUBLON : mise à jour des champs modifiables
        UPDATE annonces
        SET titre                = p_titre,
            description          = p_description,
            montant_estime       = p_montant_estime,
            date_limite_reponse  = p_date_limite_reponse,
            localisation         = p_localisation,
            region               = v_region,
            lien_source          = p_lien_source,
            timestamp_maj        = NOW()
        WHERE id_annonce = v_existant;

        INSERT INTO log_metier (annonce_id, type_operation, utilisateur, description)
        VALUES (v_existant, 'MISE_A_JOUR', p_nom_source,
                CONCAT('Annonce mise à jour depuis ', p_nom_source));

        SET p_annonce_id = v_existant;
        SET p_statut     = 'MISE_A_JOUR';
        SET p_message    = 'Annonce mise à jour (doublon détecté)';
    ELSE
        -- NOUVELLE annonce
        INSERT INTO annonces (
            id_source, id_acheteur, id_externe, titre, description,
            montant_estime, devise, date_publication, date_limite_reponse,
            localisation, region, lien_source, statut, timestamp_import
        ) VALUES (
            v_id_source, p_id_acheteur, p_id_externe, p_titre, p_description,
            p_montant_estime, 'EUR', p_date_publication, p_date_limite_reponse,
            p_localisation, v_region, p_lien_source, 'NEW', NOW()
        );

        SET p_annonce_id = LAST_INSERT_ID();
        SET p_statut     = 'INSEREE';
        SET p_message    = 'Annonce insérée avec succès';
    END IF;

    COMMIT;
END $$

-- ============================================================================
-- PROCÉDURE 2 : TraiterLotAnnonces
-- Rôle : Traite un lot d'annonces de test ; démontre SAVEPOINT + rollback partiel
-- Usage pédagogique : illustre la gestion transactionnelle sur plusieurs INSERT
-- ============================================================================

CREATE PROCEDURE TraiterLotAnnonces(
    IN  p_id_source INT,
    IN  p_id_acheteur INT,
    OUT p_nb_inseres   INT,
    OUT p_nb_erreurs   INT
)
SQL SECURITY INVOKER
NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
    DECLARE v_i        INT DEFAULT 1;
    DECLARE v_max      INT DEFAULT 5;  -- lot de 5 annonces test
    DECLARE v_titre    VARCHAR(500);
    DECLARE v_ext_id   VARCHAR(100);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_nb_erreurs = p_nb_erreurs + 1;
        ROLLBACK TO SAVEPOINT sp_annonce;
        RELEASE SAVEPOINT sp_annonce;
    END;

    SET p_nb_inseres = 0;
    SET p_nb_erreurs = 0;

    START TRANSACTION;

    WHILE v_i <= v_max DO
        SET v_ext_id = CONCAT('LOT_TEST_', v_i, '_', UNIX_TIMESTAMP());
        SET v_titre  = CONCAT('Annonce lot test #', v_i, ' - Construction modulaire');

        SAVEPOINT sp_annonce;

        INSERT INTO annonces (
            id_source, id_acheteur, id_externe, titre,
            montant_estime, devise, date_publication, date_limite_reponse,
            region, statut, timestamp_import
        ) VALUES (
            p_id_source, p_id_acheteur, v_ext_id, v_titre,
            100000 * v_i, 'EUR', NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY),
            'Île-de-France', 'NEW', NOW()
        );

        RELEASE SAVEPOINT sp_annonce;
        SET p_nb_inseres = p_nb_inseres + 1;
        SET v_i = v_i + 1;
    END WHILE;

    COMMIT;
END $$

-- ============================================================================
-- PROCÉDURE 3 : GenererKPIDashboard
-- Rôle : Calcule et retourne les indicateurs clés pour le tableau de bord
-- Usage : appelée par les scripts de reporting ou planifiée (EVENT)
-- ============================================================================

CREATE PROCEDURE GenererKPIDashboard()
SQL SECURITY INVOKER
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    SELECT
        COUNT(*)                                                      AS total_annonces,
        COUNT(CASE WHEN s.score_pertinence > 50 THEN 1 END)          AS annonces_pertinentes,
        COUNT(CASE WHEN s.niveau_alerte = 'CRITIQUE' THEN 1 END)     AS critique,
        COUNT(CASE WHEN s.niveau_alerte = 'URGENT'   THEN 1 END)     AS urgent,
        COUNT(CASE WHEN s.niveau_alerte = 'NORMAL'   THEN 1 END)     AS normal,
        COUNT(CASE WHEN s.niveau_alerte = 'IGNORE'   THEN 1 END)     AS ignore_count,
        ROUND(AVG(s.score_pertinence), 1)                            AS score_moyen,
        ROUND(AVG(a.montant_estime), 0)                              AS montant_moyen,
        COUNT(DISTINCT a.region)                                      AS regions_couvertes,
        COUNT(DISTINCT a.id_source)                                   AS sources_actives,
        NOW()                                                         AS genere_le
    FROM annonces a
    LEFT JOIN qualification_scores s ON a.id_annonce = s.id_annonce
    WHERE a.statut IN ('NEW', 'QUALIFIED');
END $$

-- ============================================================================
-- PROCÉDURE 4 : ArchiverDonneesAnciennes
-- Rôle : Archive et supprime les logs techniques de plus de N jours
-- Paramètre : p_jours_retention INT - nombre de jours à conserver (défaut 90)
-- Transaction : garantit cohérence log + suppression
-- ============================================================================

CREATE PROCEDURE ArchiverDonneesAnciennes(
    IN  p_jours_retention INT,
    OUT p_nb_archives      INT
)
SQL SECURITY INVOKER
NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
    DECLARE v_date_limite DATETIME;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_nb_archives = -1;
        ROLLBACK;
    END;

    IF p_jours_retention IS NULL OR p_jours_retention <= 0 THEN
        SET p_jours_retention = 90;
    END IF;

    SET v_date_limite = DATE_SUB(NOW(), INTERVAL p_jours_retention DAY);

    START TRANSACTION;

    -- Supprimer les logs techniques anciens
    DELETE FROM log_technique
    WHERE timestamp < v_date_limite;

    SET p_nb_archives = ROW_COUNT();

    -- Tracer l'opération de maintenance
    INSERT INTO log_technique (type_operation, source_operation, status, message)
    VALUES ('ARCHIVAGE', 'ArchiverDonneesAnciennes', 'OK',
            CONCAT(p_nb_archives, ' logs techniques archivés (>', p_jours_retention, ' jours)'));

    COMMIT;
END $$

DELIMITER ;
