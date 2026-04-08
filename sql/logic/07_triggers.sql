-- =====================================================================
-- UNITEE Phase 3 - Triggers for Announcements
-- File: 07_triggers.sql
-- Purpose: BEFORE/AFTER validation, logging, scoring, and notifications
-- =====================================================================

USE unitee;

DELIMITER $$

-- =====================================================================
-- TRIGGER 1: before_announcement_insert
-- Validates data before insert and sets defaults
-- =====================================================================

DROP TRIGGER IF EXISTS before_announcement_insert $$

CREATE TRIGGER before_announcement_insert
BEFORE INSERT ON announcements
FOR EACH ROW
BEGIN
    -- 1. VALIDATE required fields
    IF NEW.title IS NULL OR NEW.title = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: Announcement title is required and cannot be empty';
    END IF;
    
    IF NEW.external_id IS NULL OR NEW.external_id = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: External ID is required and cannot be empty';
    END IF;
    
    -- 2. VALIDATE dates
    IF NEW.publication_date IS NOT NULL AND NEW.response_deadline IS NOT NULL THEN
        IF NEW.response_deadline < NEW.publication_date THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ERROR: Response deadline cannot be before publication date';
        END IF;
    END IF;
    
    -- 3. VALIDATE amount (if provided, must be positive)
    IF NEW.estimated_amount IS NOT NULL AND NEW.estimated_amount <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: Estimated amount must be positive or NULL';
    END IF;
    
    -- 4. NORMALIZE region if blank
    IF NEW.region IS NULL OR NEW.region = '' THEN
        SET NEW.region = NormaliserRegion(NEW.location);
    END IF;
    
    -- 5. SET default currency if missing
    IF NEW.currency IS NULL OR NEW.currency = '' THEN
        SET NEW.currency = 'EUR';
    END IF;
    
    -- 6. SET default status
    IF NEW.status IS NULL OR NEW.status = '' THEN
        SET NEW.status = 'NEW';
    END IF;
    
    -- 7. SET timestamps
    IF NEW.imported_at IS NULL THEN
        SET NEW.imported_at = NOW();
    END IF;
    
    IF NEW.updated_at IS NULL THEN
        SET NEW.updated_at = NOW();
    END IF;
END $$

-- =====================================================================
-- TRIGGER 2: after_announcement_insert
-- Creates qualification score, notifications, and logs after insert
-- =====================================================================

DROP TRIGGER IF EXISTS after_announcement_insert $$

CREATE TRIGGER after_announcement_insert
AFTER INSERT ON announcements
FOR EACH ROW
BEGIN
    DECLARE v_score INT;
    DECLARE v_alert_level VARCHAR(50);
    DECLARE v_days_left INT;
    
    -- 1. CALCULATE pertinence score
    SET v_score = CalculerScorePertinence(
        NEW.title,
        NEW.description,
        NEW.estimated_amount,
        NEW.region,
        NEW.response_deadline
    );
    
    -- 2. CALCULATE alert level
    SET v_days_left = DATEDIFF(NEW.response_deadline, NOW());
    SET v_alert_level = CategoriserAlerte(v_score, v_days_left);
    
    -- 3. INSERT qualification score
    INSERT INTO qualification_scores (
        announcement_id,
        pertinence_score,
        alert_level,
        created_at,
        updated_at
    ) VALUES (
        NEW.announcement_id,
        v_score,
        v_alert_level,
        NOW(),
        NOW()
    );
    
    -- 4. CREATE notification for CRITIQUE/URGENT alerts
    IF v_alert_level IN ('CRITIQUE', 'URGENT') THEN
        INSERT INTO notifications (
            announcement_id,
            alert_type,
            status,
            priority
        ) VALUES (
            NEW.announcement_id,
            v_alert_level,
            'NEW',
            CASE 
                WHEN v_alert_level = 'CRITIQUE' THEN 3
                WHEN v_alert_level = 'URGENT' THEN 2
                ELSE 1
            END
        );
    END IF;
    
    -- 5. LOG creation in business logs
    INSERT INTO business_logs (
        announcement_id,
        action,
        details,
        created_at
    ) VALUES (
        NEW.announcement_id,
        'INSERT',
        CONCAT('New announcement created from source_id=', NEW.source_id, 
               ', score=', v_score, ', alert_level=', v_alert_level),
        NOW()
    );
    
    -- 6. LOG technical action
    INSERT INTO technical_logs (
        action,
        details,
        status,
        created_at
    ) VALUES (
        'ANNOUNCEMENT_INSERT',
        CONCAT('Announcement ', NEW.announcement_id, ' inserted with score ', v_score),
        'OK',
        NOW()
    );
END $$

-- =====================================================================
-- TRIGGER 3: after_announcement_update
-- Logs updates and recalculates scores when needed
-- =====================================================================

DROP TRIGGER IF EXISTS after_announcement_update $$

CREATE TRIGGER after_announcement_update
AFTER UPDATE ON announcements
FOR EACH ROW
BEGIN
    DECLARE v_score INT;
    DECLARE v_alert_level VARCHAR(50);
    DECLARE v_days_left INT;
    DECLARE v_changes VARCHAR(500);
    
    -- 1. DETECT what changed
    SET v_changes = '';
    
    IF COALESCE(OLD.title, '') != COALESCE(NEW.title, '') THEN
        SET v_changes = CONCAT(v_changes, 'title;');
    END IF;
    IF COALESCE(OLD.description, '') != COALESCE(NEW.description, '') THEN
        SET v_changes = CONCAT(v_changes, 'description;');
    END IF;
    IF COALESCE(OLD.estimated_amount, 0) != COALESCE(NEW.estimated_amount, 0) THEN
        SET v_changes = CONCAT(v_changes, 'amount;');
    END IF;
    IF COALESCE(OLD.response_deadline, '') != COALESCE(NEW.response_deadline, '') THEN
        SET v_changes = CONCAT(v_changes, 'deadline;');
    END IF;
    IF COALESCE(OLD.status, '') != COALESCE(NEW.status, '') THEN
        SET v_changes = CONCAT(v_changes, 'status;');
    END IF;
    IF COALESCE(OLD.region, '') != COALESCE(NEW.region, '') THEN
        SET v_changes = CONCAT(v_changes, 'region;');
    END IF;
    
    -- 2. RECALCULATE score if content or deadline changed
    IF v_changes LIKE '%title%' OR v_changes LIKE '%description%' 
       OR v_changes LIKE '%amount%' OR v_changes LIKE '%deadline%' 
       OR v_changes LIKE '%region%' THEN
        
        SET v_score = CalculerScorePertinence(
            NEW.title,
            NEW.description,
            NEW.estimated_amount,
            NEW.region,
            NEW.response_deadline
        );
        
        SET v_days_left = DATEDIFF(NEW.response_deadline, NOW());
        SET v_alert_level = CategoriserAlerte(v_score, v_days_left);
        
        -- UPDATE qualification score
        UPDATE qualification_scores
        SET pertinence_score = v_score,
            alert_level = v_alert_level,
            updated_at = NOW()
        WHERE announcement_id = NEW.announcement_id;
    END IF;
    
    -- 3. LOG update
    INSERT INTO business_logs (
        announcement_id,
        action,
        details,
        created_at
    ) VALUES (
        NEW.announcement_id,
        'UPDATE',
        CONCAT('Updated fields: ', TRIM(TRAILING ';' FROM v_changes),
               ', status changed from ', OLD.status, ' to ', NEW.status),
        NOW()
    );
END $$

-- =====================================================================
-- TRIGGER 4: before_announcement_delete
-- Archives announcement before deletion (soft delete pattern)
-- =====================================================================

DROP TRIGGER IF EXISTS before_announcement_delete $$

CREATE TRIGGER before_announcement_delete
BEFORE DELETE ON announcements
FOR EACH ROW
BEGIN
    -- 1. ARCHIVE announcement to history table
    INSERT INTO announcement_history (
        announcement_id,
        status,
        details,
        archived_at
    ) VALUES (
        OLD.announcement_id,
        OLD.status,
        CONCAT('Archived announcement: title=', OLD.title, 
               ', region=', OLD.region, 
               ', amount=', OLD.estimated_amount),
        NOW()
    );
    
    -- 2. LOG deletion
    INSERT INTO business_logs (
        announcement_id,
        action,
        details,
        created_at
    ) VALUES (
        OLD.announcement_id,
        'DELETE',
        CONCAT('Announcement deleted with status=', OLD.status),
        NOW()
    );
    
    -- 3. LOG technical action
    INSERT INTO technical_logs (
        action,
        details,
        status,
        created_at
    ) VALUES (
        'ANNOUNCEMENT_DELETE',
        CONCAT('Announcement ', OLD.announcement_id, ' deleted'),
        'OK',
        NOW()
    );
END $$

-- =====================================================================
-- TRIGGER 5: after_notification_insert
-- Logs when notifications are created
-- =====================================================================

DROP TRIGGER IF EXISTS after_notification_insert $$

CREATE TRIGGER after_notification_insert
AFTER INSERT ON notifications
FOR EACH ROW
BEGIN
    -- LOG notification creation
    INSERT INTO technical_logs (
        action,
        details,
        status,
        created_at
    ) VALUES (
        'NOTIFICATION_INSERT',
        CONCAT('Notification created for announcement ', NEW.announcement_id,
               ', alert_type=', NEW.alert_type, ', priority=', NEW.priority),
        'OK',
        NOW()
    );
END $$

-- =====================================================================
-- TRIGGER 6: before_qualification_scores_insert
-- Validates score values
-- =====================================================================

DROP TRIGGER IF EXISTS before_qualification_scores_insert $$

CREATE TRIGGER before_qualification_scores_insert
BEFORE INSERT ON qualification_scores
FOR EACH ROW
BEGIN
    -- 1. VALIDATE score range (0-100)
    IF NEW.pertinence_score < 0 OR NEW.pertinence_score > 100 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: Pertinence score must be between 0 and 100';
    END IF;
    
    -- 2. VALIDATE alert level
    IF NEW.alert_level NOT IN ('CRITIQUE', 'URGENT', 'NORMAL', 'IGNORE') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: Invalid alert level. Must be CRITIQUE, URGENT, NORMAL, or IGNORE';
    END IF;
    
    -- 3. SET timestamps
    IF NEW.calculated_at IS NULL THEN
        SET NEW.calculated_at = NOW();
    END IF;
    
    IF NEW.updated_at IS NULL THEN
        SET NEW.updated_at = NOW();
    END IF;
END $$

DELIMITER ;

-- =====================================================================
-- END OF FILE: 07_triggers.sql
-- =====================================================================
