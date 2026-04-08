-- =====================================================================
-- UNITEE Phase 3 - Stored Procedures
-- File: 06_procedures.sql
-- Purpose: Announcement insertion, batch processing, KPI generation, archiving
-- =====================================================================

USE unitee;

-- =====================================================================
-- PROCEDURE 1: InsererAnnonce
-- Inserts or updates announcement with scoring and notifications
-- =====================================================================

DROP PROCEDURE IF EXISTS InsererAnnonce;

CREATE PROCEDURE InsererAnnonce(
    IN p_source_name VARCHAR(100),
    IN p_external_id VARCHAR(255),
    IN p_titre VARCHAR(255),
    IN p_description LONGTEXT,
    IN p_montant_estime DECIMAL(15,2),
    IN p_devise VARCHAR(10),
    IN p_date_publication DATETIME,
    IN p_date_limite_reponse DATETIME,
    IN p_lieu VARCHAR(255),
    IN p_region VARCHAR(100),
    IN p_acheteur_id INT,
    IN p_lien_source VARCHAR(500),
    OUT p_annonce_id INT,
    OUT p_result_status VARCHAR(50),
    OUT p_result_message VARCHAR(255)
)
SQL SECURITY INVOKER
NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
    DECLARE v_source_id INT;
    DECLARE v_existing_id INT;
    DECLARE v_score INT;
    DECLARE v_jours_restants INT;
    DECLARE v_alert_level VARCHAR(50);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_result_status = 'ERROR';
        SET p_result_message = 'Transaction rolled back due to error';
        ROLLBACK;
    END;
    
    START TRANSACTION;
    
    -- 1. GET source_id
    SELECT source_id INTO v_source_id
    FROM sources
    WHERE source_name = p_source_name
    LIMIT 1;
    
    IF v_source_id IS NULL THEN
        SET p_result_status = 'ERROR';
        SET p_result_message = 'Source not found';
        SET p_annonce_id = -1;
        ROLLBACK;
        LEAVE InsererAnnonce;
    END IF;
    
    -- 2. CHECK for doublon (source_id + external_id)
    SELECT announcement_id INTO v_existing_id
    FROM announcements
    WHERE source_id = v_source_id
      AND external_id = p_external_id
    LIMIT 1;
    
    IF v_existing_id IS NOT NULL THEN
        -- DOUBLON: Update with new data
        UPDATE announcements
        SET title = p_titre,
            description = p_description,
            estimated_amount = p_montant_estime,
            currency = p_devise,
            publication_date = p_date_publication,
            response_deadline = p_date_limite_reponse,
            location = p_lieu,
            region = p_region,
            source_link = p_lien_source,
            updated_at = NOW()
        WHERE announcement_id = v_existing_id;
        
        -- Log update in business logs
        INSERT INTO business_logs (announcement_id, operation_type, description, timestamp)
        VALUES (v_existing_id, 'UPDATE', CONCAT('Updated from ', p_source_name), NOW());
        
        SET p_annonce_id = v_existing_id;
        SET p_result_status = 'UPDATED';
        SET p_result_message = 'Announcement updated (doublon)';
    ELSE
        -- NEW: Insert announcement
        INSERT INTO announcements (
            source_id, buyer_id, external_id, title, description,
            estimated_amount, currency, publication_date, response_deadline,
            location, region, source_link, status, imported_at
        ) VALUES (
            v_source_id, COALESCE(p_acheteur_id, 1), p_external_id, p_titre, p_description,
            p_montant_estime, p_devise, p_date_publication, p_date_limite_reponse,
            p_lieu, p_region, p_lien_source, 'NEW', NOW()
        );
        
        SET v_existing_id = LAST_INSERT_ID();
        SET p_annonce_id = v_existing_id;
        
        -- Log creation
        INSERT INTO business_logs (announcement_id, operation_type, description, timestamp)
        VALUES (v_existing_id, 'CREATE', CONCAT('Created from ', p_source_name), NOW());
        
        -- 3. CALCULATE score
        SET v_score = CalculerScorePertinence(
            p_titre, p_description, p_montant_estime,
            p_region, p_date_limite_reponse
        );
        
        -- 4. INSERT qualification score
        INSERT INTO qualification_scores (
            announcement_id, pertinence_score, alert_level,
            calculated_at, updated_at
        ) VALUES (
            v_existing_id,
            v_score,
            CategoriserAlerte(v_score, DATEDIFF(p_date_limite_reponse, NOW())),
            NOW(),
            NOW()
        );
        
        -- 5. CREATE notification if score is high
        IF v_score > 75 THEN
            INSERT INTO notifications (
                announcement_id, alert_type, status, priority
            ) VALUES (
                v_existing_id,
                'CRITIQUE',
                'NEW',
                3
            );
        END IF;
        
        SET p_result_status = 'INSERTED';
        SET p_result_message = CONCAT('Announcement inserted with score: ', v_score);
    END IF;
    
    COMMIT;
END;

-- =====================================================================
-- PROCEDURE 2: TraiterLotAnnonces
-- Processes batch of NEW announcements
-- =====================================================================

DROP PROCEDURE IF EXISTS TraiterLotAnnonces;

CREATE PROCEDURE TraiterLotAnnonces(
    IN p_source_id INT,
    IN p_batch_size INT,
    OUT p_inserted INT,
    OUT p_updated INT,
    OUT p_errors INT
)
SQL SECURITY INVOKER
NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
    DECLARE v_done INT DEFAULT 0;
    DECLARE v_ann_id INT;
    DECLARE v_status VARCHAR(50);
    DECLARE v_message VARCHAR(255);
    DECLARE v_cursor CURSOR FOR
        SELECT announcement_id FROM announcements
        WHERE source_id = p_source_id AND status = 'NEW'
        LIMIT p_batch_size;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
    
    SET p_inserted = 0;
    SET p_updated = 0;
    SET p_errors = 0;
    
    START TRANSACTION;
    
    OPEN v_cursor;
    FETCH v_cursor INTO v_ann_id;
    
    WHILE v_done = 0 DO
        -- Recalculate score for each announcement
        BEGIN
            DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
            BEGIN
                SET p_errors = p_errors + 1;
            END;
            
            -- Get announcement data and recalculate score
            UPDATE announcements a
            SET status = CASE WHEN status = 'NEW' THEN 'QUALIFIED' ELSE status END
            WHERE announcement_id = v_ann_id;
            
            SET p_inserted = p_inserted + 1;
        END;
        
        FETCH v_cursor INTO v_ann_id;
    END WHILE;
    
    CLOSE v_cursor;
    
    -- Log the batch processing
    IF p_errors < (p_inserted + p_updated) * 0.2 THEN
        COMMIT;
        INSERT INTO technical_logs (action, details, status, created_at)
        VALUES ('BATCH_PROCESS', CONCAT('Processed ', p_inserted, ' announcements'),  'OK', NOW());
    ELSE
        ROLLBACK;
        INSERT INTO technical_logs (action, details, status, created_at)
        VALUES ('BATCH_PROCESS', CONCAT('Batch failed with ', p_errors, ' errors'), 'ERROR', NOW());
    END IF;
END;

-- =====================================================================
-- PROCEDURE 3: GenererKPIDashboard
-- Generates KPI summary for dashboard
-- =====================================================================

DROP PROCEDURE IF EXISTS GenererKPIDashboard;

CREATE PROCEDURE GenererKPIDashboard()
SQL SECURITY INVOKER
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    -- Returns KPI summary as SELECT
    SELECT
        COUNT(*) as total_announcements,
        SUM(CASE WHEN qs.pertinence_score > 75 THEN 1 ELSE 0 END) as high_priority,
        SUM(CASE WHEN qs.pertinence_score > 50 AND qs.pertinence_score <= 75 THEN 1 ELSE 0 END) as medium_priority,
        COUNT(DISTINCT a.region) as regions,
        COUNT(DISTINCT a.buyer_id) as buyers,
        AVG(a.estimated_amount) as avg_amount,
        MIN(a.publication_date) as earliest_date,
        MAX(a.response_deadline) as latest_deadline,
        NOW() as generated_at
    FROM announcements a
    LEFT JOIN qualification_scores qs ON a.announcement_id = qs.announcement_id
    WHERE a.status IN ('NEW', 'QUALIFIED');
END;

-- =====================================================================
-- PROCEDURE 4: ArchiverDonneesAncienne
-- Archives old announcements and logs
-- =====================================================================

DROP PROCEDURE IF EXISTS ArchiverDonneesAncienne;

CREATE PROCEDURE ArchiverDonneesAncienne(
    IN p_days_retention INT,
    OUT p_archived_count INT
)
SQL SECURITY INVOKER
NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
    DECLARE v_cutoff_date DATETIME;
    SET v_cutoff_date = DATE_SUB(NOW(), INTERVAL p_days_retention DAY);
    SET p_archived_count = 0;
    
    START TRANSACTION;
    
    -- Archive old announcements to archive table
    INSERT INTO announcement_history (announcement_id, status, details, archived_at)
    SELECT announcement_id, status, CONCAT('Archived from ', region), NOW()
    FROM announcements
    WHERE created_at < v_cutoff_date AND status IN ('RESPONDED', 'CLOSED');
    
    SET p_archived_count = ROW_COUNT();
    
    -- Log in backup logs
    INSERT INTO backup_logs (backup_type, status, details, created_at)
    VALUES ('ARCHIVE', 'SUCCESS', CONCAT('Archived ', p_archived_count, ' old announcements'), NOW());
    
    COMMIT;
END;

-- =====================================================================
-- TEST: Call procedures
-- =====================================================================

-- Test 1: Simple announcement insert
-- CALL InsererAnnonce(
--     'synthetic', 'TEST_001', 'Test Announcement',
--     'This is a test announcement for modulaire construction',
--     150000.00, 'EUR', NOW(), DATE_ADD(NOW(), INTERVAL 15 DAY),
--     '75001 Paris', 'Île-de-France', 4, 'http://example.com',
--     @ann_id, @status, @message
-- );
-- SELECT @ann_id AS announcement_id, @status AS status, @message AS message;

-- Test 2: Generate KPIs
-- CALL GenererKPIDashboard();

-- =====================================================================
-- END OF FILE: 06_procedures.sql
-- =====================================================================
