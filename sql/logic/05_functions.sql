-- =====================================================================
-- UNITEE Phase 3 - Simplified Scoring Functions
-- File: 05_functions.sql
-- =====================================================================

USE unitee;

-- Drop if exists
DROP FUNCTION IF EXISTS CalculerScorePertinence;
DROP FUNCTION IF EXISTS CategoriserAlerte;
DROP FUNCTION IF EXISTS NormaliserRegion;

-- =====================================================================
-- FUNCTION 1: CalculerScorePertinence
-- Simplified scoring based on amount, region, and deadline
-- Returns: 0-100 score
-- =====================================================================

CREATE FUNCTION CalculerScorePertinence(
    p_titre VARCHAR(255),
    p_description LONGTEXT,
    p_montant DECIMAL(15,2),
    p_region VARCHAR(100),
    p_deadline DATETIME
)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_score INT DEFAULT 0;
    DECLARE v_jours_restants INT;
    DECLARE v_keyword_matches INT DEFAULT 0;
    
    -- ========== SCORING LOGIC (0-100) ==========
    
    -- 1. KEYWORD MATCHING (+30 points)
    -- Simple check for common keywords
    IF LOWER(CONCAT(p_titre, ' ', COALESCE(p_description, ''))) LIKE '%modulaire%' 
       OR LOWER(CONCAT(p_titre, ' ', COALESCE(p_description, ''))) LIKE '%prefabrique%'
       OR LOWER(CONCAT(p_titre, ' ', COALESCE(p_description, ''))) LIKE '%assemblage%' THEN
        SET v_score = v_score + 30;
    ELSEIF LOWER(CONCAT(p_titre, ' ', COALESCE(p_description, ''))) LIKE '%construction%' THEN
        SET v_score = v_score + 15;
    ELSE
        SET v_score = v_score + 0;
    END IF;
    
    -- 2. AMOUNT VALIDATION (+25 points)
    IF p_montant IS NOT NULL THEN
        IF p_montant > 100000 THEN
            SET v_score = v_score + 25;
        ELSEIF p_montant > 50000 THEN
            SET v_score = v_score + 15;
        ELSEIF p_montant > 10000 THEN
            SET v_score = v_score + 8;
        ELSE
            SET v_score = v_score + 3;
        END IF;
    ELSE
        SET v_score = v_score + 3;
    END IF;
    
    -- 3. REGION BONUS (+20 points)
    IF p_region IS NOT NULL AND p_region != 'Unknown' THEN
        SET v_score = v_score + 20;
    ELSE
        SET v_score = v_score + 5;
    END IF;
    
    -- 4. DEADLINE URGENCY (+15 points)
    IF p_deadline IS NOT NULL THEN
        SET v_jours_restants = DATEDIFF(p_deadline, NOW());
        
        IF v_jours_restants < 0 THEN
            SET v_score = v_score + 0;
        ELSEIF v_jours_restants < 7 THEN
            SET v_score = v_score + 15;
        ELSEIF v_jours_restants < 14 THEN
            SET v_score = v_score + 12;
        ELSEIF v_jours_restants < 30 THEN
            SET v_score = v_score + 8;
        ELSE
            SET v_score = v_score + 2;
        END IF;
    END IF;
    
    -- 5. BUYER MATCHING (+5 points)
    SET v_score = v_score + 5;
    
    -- CAP SCORE
    SET v_score = LEAST(100, GREATEST(0, v_score));
    
    RETURN v_score;
END;

-- =====================================================================
-- FUNCTION 2: CategoriserAlerte
-- Categorizes alert level based on score and urgency
-- Returns: 'CRITIQUE', 'URGENT', 'NORMAL', 'IGNORE'
-- =====================================================================

CREATE FUNCTION CategoriserAlerte(
    p_score INT,
    p_days_left INT
)
RETURNS VARCHAR(50)
DETERMINISTIC
READS SQL DATA
BEGIN
    -- Expired announcements always IGNORE
    IF p_days_left < 0 THEN
        RETURN 'IGNORE';
    -- CRITIQUE: High score + very urgent deadline (7 days or less)
    ELSEIF p_score > 75 AND p_days_left <= 7 THEN
        RETURN 'CRITIQUE';
    -- URGENT: High/Medium score + urgent deadline (14 days or less)
    ELSEIF (p_score > 75 OR p_score > 60) AND p_days_left <= 14 THEN
        RETURN 'URGENT';
    -- NORMAL: Good score regardless of deadline
    ELSEIF p_score > 50 THEN
        RETURN 'NORMAL';
    -- IGNORE: Low score
    ELSE
        RETURN 'IGNORE';
    END IF;
END;

-- =====================================================================
-- FUNCTION 3: NormaliserRegion
-- Normalizes location to region name
-- Returns: Standardized region name
-- =====================================================================

CREATE FUNCTION NormaliserRegion(p_location VARCHAR(255))
RETURNS VARCHAR(100)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_location_lower VARCHAR(255);
    SET v_location_lower = LOWER(COALESCE(p_location, 'Unknown'));
    
    CASE
        WHEN v_location_lower LIKE '%paris%' OR v_location_lower LIKE '%75%' THEN
            RETURN 'Île-de-France';
        WHEN v_location_lower LIKE '%lyon%' OR v_location_lower LIKE '%rhone%' OR v_location_lower LIKE '%69%' THEN
            RETURN 'Auvergne-Rhône-Alpes';
        WHEN v_location_lower LIKE '%marseille%' OR v_location_lower LIKE '%nice%' OR v_location_lower LIKE '%provence%' THEN
            RETURN 'Provence-Alpes-Côte d''Azur';
        WHEN v_location_lower LIKE '%strasbourg%' OR v_location_lower LIKE '%grand est%' THEN
            RETURN 'Grand Est';
        WHEN v_location_lower LIKE '%lille%' OR v_location_lower LIKE '%hauts-de-france%' THEN
            RETURN 'Hauts-de-France';
        WHEN v_location_lower LIKE '%rouen%' OR v_location_lower LIKE '%normandie%' THEN
            RETURN 'Normandie';
        WHEN v_location_lower LIKE '%bordeaux%' OR v_location_lower LIKE '%aquitaine%' THEN
            RETURN 'Nouvelle-Aquitaine';
        WHEN v_location_lower LIKE '%toulouse%' OR v_location_lower LIKE '%occitanie%' THEN
            RETURN 'Occitanie';
        ELSE
            RETURN 'Unknown';
    END CASE;
END;

-- =====================================================================
-- TEST: Quick validation
-- =====================================================================

SELECT 'Test 1: High-value modulaire' AS test_name,
       CalculerScorePertinence('Marche modulaire', 'Construction modulaire batiment', 250000, 'Île-de-France', DATE_ADD(NOW(), INTERVAL 10 DAY)) AS score;

SELECT 'Test 2: CRITIQUE alert' AS test_name,
       CategoriserAlerte(85, 5) AS alert_level;

SELECT 'Test 3: Region - Paris' AS test_name,
       NormaliserRegion('75001 Paris') AS region;
