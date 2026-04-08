-- ============================================================================
-- UNITEE - Fonctions SQL métier
-- Fichier : 05_functions.sql
-- Correspond aux tables : annonces, qualification_scores, mots_cles
-- ============================================================================

USE unitee;

DELIMITER $$

DROP FUNCTION IF EXISTS CalculerScorePertinence $$
DROP FUNCTION IF EXISTS CategoriserAlerte $$
DROP FUNCTION IF EXISTS NormaliserRegion $$

-- ============================================================================
-- FONCTION 1 : CalculerScorePertinence
-- Rôle : Calcule le score de pertinence 0-100 d'une annonce de marché public
-- Paramètres :
--   p_titre         VARCHAR(500) - Titre de l'annonce
--   p_description   LONGTEXT     - Description complète (peut être NULL)
--   p_montant       DECIMAL      - Montant estimé EUR (peut être NULL)
--   p_region        VARCHAR(100) - Région (peut être NULL)
--   p_deadline      DATETIME     - Date limite réponse (peut être NULL)
-- Retour : INT (0-100)
-- Hypothèses : Score plafonné à 100. NULL tolérés sur tous les paramètres sauf titre.
-- Cas limites : deadline passée → bonus deadline = 0 ; montant NULL → bonus minimal
-- ============================================================================

CREATE FUNCTION CalculerScorePertinence(
    p_titre       VARCHAR(500),
    p_description LONGTEXT,
    p_montant     DECIMAL(15,2),
    p_region      VARCHAR(100),
    p_deadline    DATETIME
)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_score INT DEFAULT 0;
    DECLARE v_jours_restants INT;
    DECLARE v_texte TEXT;

    SET v_texte = LOWER(CONCAT(COALESCE(p_titre, ''), ' ', COALESCE(p_description, '')));

    -- 1. BONUS MOTS-CLÉS (+30 pts max)
    -- Détection des termes métier prioritaires dans titre + description
    IF v_texte LIKE '%modulaire%'
       OR v_texte LIKE '%préfabriqué%'
       OR v_texte LIKE '%prefabrique%'
       OR v_texte LIKE '%assemblage rapide%'
       OR v_texte LIKE '%bâtiment en kit%'
       OR v_texte LIKE '%base vie%' THEN
        SET v_score = v_score + 30;
    ELSEIF v_texte LIKE '%construction%'
        OR v_texte LIKE '%extension%'
        OR v_texte LIKE '%classe temporaire%' THEN
        SET v_score = v_score + 15;
    END IF;

    -- 2. BONUS MONTANT (+25 pts max)
    -- Plus le marché est important, plus il est pertinent
    IF p_montant IS NOT NULL THEN
        IF p_montant > 500000 THEN
            SET v_score = v_score + 25;
        ELSEIF p_montant > 100000 THEN
            SET v_score = v_score + 15;
        ELSEIF p_montant > 50000 THEN
            SET v_score = v_score + 8;
        ELSE
            SET v_score = v_score + 3;
        END IF;
    ELSE
        SET v_score = v_score + 3; -- montant non communiqué : bonus minimal
    END IF;

    -- 3. BONUS RÉGION (+20 pts)
    -- Région identifiée = annonce géolocalisable
    IF p_region IS NOT NULL AND p_region != '' AND p_region != 'Unknown' THEN
        SET v_score = v_score + 20;
    ELSE
        SET v_score = v_score + 5;
    END IF;

    -- 4. BONUS URGENCE DEADLINE (+15 pts max)
    -- Plus la date limite est proche, plus l'annonce est urgente
    IF p_deadline IS NOT NULL THEN
        SET v_jours_restants = DATEDIFF(p_deadline, NOW());
        IF v_jours_restants < 0 THEN
            SET v_score = v_score + 0; -- annonce expirée
        ELSEIF v_jours_restants <= 7 THEN
            SET v_score = v_score + 15;
        ELSEIF v_jours_restants <= 14 THEN
            SET v_score = v_score + 10;
        ELSEIF v_jours_restants <= 30 THEN
            SET v_score = v_score + 5;
        ELSE
            SET v_score = v_score + 2;
        END IF;
    END IF;

    -- 5. BONUS ACHETEUR (+5 pts)
    -- Bonus de base : l'acheteur est connu dans la base
    SET v_score = v_score + 5;

    -- Plafonnement entre 0 et 100
    RETURN LEAST(100, GREATEST(0, v_score));
END $$

-- ============================================================================
-- FONCTION 2 : CategoriserAlerte
-- Rôle : Détermine le niveau d'alerte à partir du score et du délai restant
-- Paramètres :
--   p_score         INT - Score de pertinence (0-100)
--   p_jours_restants INT - Jours avant date limite (négatif = expiré)
-- Retour : VARCHAR(50) parmi 'CRITIQUE', 'URGENT', 'NORMAL', 'IGNORE'
-- Logique :
--   CRITIQUE : score > 75 ET délai ≤ 7 jours
--   URGENT   : score > 60 ET délai ≤ 14 jours
--   NORMAL   : score > 50
--   IGNORE   : score ≤ 50 ou expiré
-- ============================================================================

CREATE FUNCTION CategoriserAlerte(
    p_score          INT,
    p_jours_restants INT
)
RETURNS VARCHAR(50)
DETERMINISTIC
READS SQL DATA
BEGIN
    IF p_jours_restants < 0 THEN
        RETURN 'IGNORE';  -- annonce expirée
    ELSEIF p_score > 75 AND p_jours_restants <= 7 THEN
        RETURN 'CRITIQUE';
    ELSEIF p_score > 60 AND p_jours_restants <= 14 THEN
        RETURN 'URGENT';
    ELSEIF p_score > 50 THEN
        RETURN 'NORMAL';
    ELSE
        RETURN 'IGNORE';
    END IF;
END $$

-- ============================================================================
-- FONCTION 3 : NormaliserRegion
-- Rôle : Convertit une chaîne de localisation libre en région française normalisée
-- Paramètre : p_localisation VARCHAR(255) - Ville, département, texte libre
-- Retour : VARCHAR(100) - Nom de région normalisé ou 'Unknown'
-- Cas limites : NULL en entrée → 'Unknown'
-- ============================================================================

CREATE FUNCTION NormaliserRegion(p_localisation VARCHAR(255))
RETURNS VARCHAR(100)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_loc VARCHAR(255);
    SET v_loc = LOWER(COALESCE(p_localisation, ''));

    CASE
        WHEN v_loc LIKE '%paris%'      OR v_loc LIKE '%75%'
          OR v_loc LIKE '%île-de-france%'                        THEN RETURN 'Île-de-France';
        WHEN v_loc LIKE '%lyon%'       OR v_loc LIKE '%rhone%'
          OR v_loc LIKE '%auvergne%'                             THEN RETURN 'Auvergne-Rhône-Alpes';
        WHEN v_loc LIKE '%marseille%'  OR v_loc LIKE '%nice%'
          OR v_loc LIKE '%provence%'   OR v_loc LIKE '%paca%'    THEN RETURN 'Provence-Alpes-Côte d''Azur';
        WHEN v_loc LIKE '%strasbourg%' OR v_loc LIKE '%grand est%'
          OR v_loc LIKE '%alsace%'     OR v_loc LIKE '%lorraine%' THEN RETURN 'Grand Est';
        WHEN v_loc LIKE '%lille%'      OR v_loc LIKE '%hauts-de-france%'
          OR v_loc LIKE '%nord%'                                  THEN RETURN 'Hauts-de-France';
        WHEN v_loc LIKE '%rouen%'      OR v_loc LIKE '%normandie%' THEN RETURN 'Normandie';
        WHEN v_loc LIKE '%bordeaux%'   OR v_loc LIKE '%aquitaine%'
          OR v_loc LIKE '%nouvelle-aquitaine%'                    THEN RETURN 'Nouvelle-Aquitaine';
        WHEN v_loc LIKE '%toulouse%'   OR v_loc LIKE '%occitanie%'
          OR v_loc LIKE '%montpellier%'                           THEN RETURN 'Occitanie';
        WHEN v_loc LIKE '%nantes%'     OR v_loc LIKE '%bretagne%'
          OR v_loc LIKE '%pays de la loire%'                      THEN RETURN 'Pays de la Loire';
        ELSE RETURN 'Unknown';
    END CASE;
END $$

DELIMITER ;

-- ============================================================================
-- TESTS RAPIDES
-- ============================================================================

SELECT 'Test CalculerScorePertinence - annonce modulaire haute valeur' AS test_nom,
       CalculerScorePertinence(
           'Marché modulaire construction préfabriquée',
           'Assemblage rapide de bâtiment modulaire',
           350000,
           'Île-de-France',
           DATE_ADD(NOW(), INTERVAL 10 DAY)
       ) AS score_attendu_env_80;

SELECT 'Test CategoriserAlerte - CRITIQUE' AS test_nom,
       CategoriserAlerte(80, 5) AS niveau_attendu_CRITIQUE;

SELECT 'Test CategoriserAlerte - IGNORE expiré' AS test_nom,
       CategoriserAlerte(90, -1) AS niveau_attendu_IGNORE;

SELECT 'Test NormaliserRegion - Paris' AS test_nom,
       NormaliserRegion('75001 Paris') AS region_attendue_IDF;
