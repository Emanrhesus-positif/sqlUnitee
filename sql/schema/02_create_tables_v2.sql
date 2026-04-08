-- ============================================================================
-- UNITEE - DATABASE SCHEMA (CORRECTED FROM UML)
-- Project: Automated Public Market Surveillance
-- Date: 2026-04-08
-- Version: 2.0 (Based on MLD.puml)
-- 
-- This script creates 11 tables as per the logical data model
-- ============================================================================

-- ============================================================================
-- 1. SOURCES - Data sources reference
-- ============================================================================
CREATE TABLE IF NOT EXISTS sources (
  source_id INT PRIMARY KEY AUTO_INCREMENT COMMENT 'Unique source identifier',
  source_name VARCHAR(100) UNIQUE NOT NULL COMMENT 'Unique name (data.gouv.fr, BOAMP, synthetic)',
  description TEXT COMMENT 'Source description and usage notes',
  api_base_url VARCHAR(500) COMMENT 'API base URL',
  source_type VARCHAR(50) DEFAULT 'API' COMMENT 'API, SCRAPING, or FLUX_RSS',
  active BOOLEAN DEFAULT true COMMENT 'Is source active',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation timestamp'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Sources - Reference table for data sources';

-- ============================================================================
-- 2. BUYERS - Public buyers reference
-- ============================================================================
CREATE TABLE IF NOT EXISTS buyers (
  buyer_id INT PRIMARY KEY AUTO_INCREMENT COMMENT 'Unique buyer identifier',
  buyer_name VARCHAR(255) UNIQUE NOT NULL COMMENT 'Official buyer name',
  buyer_type VARCHAR(100) COMMENT 'COLLECTIVITE, ETAT, or ENTREPRISE_PUBLIQUE',
  region VARCHAR(100) COMMENT 'Region (for geographic filtering)',
  contact_email VARCHAR(255) COMMENT 'Contact email',
  contact_phone VARCHAR(20) COMMENT 'Contact phone',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation timestamp'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Buyers - Reference table for public buyers';

-- ============================================================================
-- 3. KEYWORDS - Relevant keywords catalog
-- ============================================================================
CREATE TABLE IF NOT EXISTS keywords (
  keyword_id INT PRIMARY KEY AUTO_INCREMENT COMMENT 'Unique keyword identifier',
  keyword_text VARCHAR(100) UNIQUE NOT NULL COMMENT 'Exact keyword text',
  category VARCHAR(50) DEFAULT 'SECONDARY' COMMENT 'PRIMARY, SECONDARY, or EXTRACTED',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation timestamp'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Keywords - Relevant keywords for market surveillance';

-- ============================================================================
-- 4. ANNOUNCEMENTS - Main announcements table (CORE BUSINESS)
-- ============================================================================
CREATE TABLE IF NOT EXISTS announcements (
  announcement_id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT 'Unique announcement identifier',
  source_id INT NOT NULL COMMENT 'Foreign key: source',
  buyer_id INT NOT NULL COMMENT 'Foreign key: buyer',
  external_id VARCHAR(100) NOT NULL COMMENT 'External ID from source',
  title VARCHAR(500) NOT NULL COMMENT 'Announcement title (min 6 chars)',
  description LONGTEXT COMMENT 'Full announcement description',
  estimated_amount DECIMAL(15,2) COMMENT 'Estimated amount in EUR',
  currency VARCHAR(3) DEFAULT 'EUR' COMMENT 'Currency code',
  publication_date DATETIME NOT NULL COMMENT 'Publication date',
  response_deadline DATETIME NOT NULL COMMENT 'Response deadline (CRITICAL)',
  location VARCHAR(255) COMMENT 'Execution location',
  region VARCHAR(100) COMMENT 'Region for geographic filtering',
  source_link VARCHAR(500) UNIQUE COMMENT 'Source URL (max 1 per announcement)',
  status VARCHAR(50) DEFAULT 'NEW' COMMENT 'NEW, QUALIFIED, IGNORED, or RESPONDED',
  imported_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Import timestamp',
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
  
  CONSTRAINT fk_announcements_source 
    FOREIGN KEY (source_id) REFERENCES sources(source_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_announcements_buyer 
    FOREIGN KEY (buyer_id) REFERENCES buyers(buyer_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT uk_announcement_doublon 
    UNIQUE (source_id, external_id),
  
  CONSTRAINT ck_title_length
    CHECK (CHAR_LENGTH(title) > 5),
  
  CONSTRAINT ck_amount_positive
    CHECK (estimated_amount IS NULL OR estimated_amount >= 0),
  
  CONSTRAINT ck_dates_logic 
    CHECK (publication_date <= response_deadline)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Announcements - Main business table for market opportunities';

-- ============================================================================
-- 5. ANNOUNCEMENT_KEYWORDS - N:N junction table
-- ============================================================================
CREATE TABLE IF NOT EXISTS announcement_keywords (
  announcement_id BIGINT NOT NULL COMMENT 'Foreign key: announcement',
  keyword_id INT NOT NULL COMMENT 'Foreign key: keyword',
  relevance_score INT DEFAULT 50 COMMENT 'Relevance score 0-100',
  extraction_type VARCHAR(50) DEFAULT 'REGEX' COMMENT 'TF-IDF, REGEX, MANUAL, or LLM',
  extracted_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Extraction timestamp',
  
  PRIMARY KEY (announcement_id, keyword_id),
  
  CONSTRAINT fk_ank_announcement 
    FOREIGN KEY (announcement_id) REFERENCES announcements(announcement_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  
  CONSTRAINT fk_ank_keyword 
    FOREIGN KEY (keyword_id) REFERENCES keywords(keyword_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT ck_relevance_score
    CHECK (relevance_score >= 0 AND relevance_score <= 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Announcement_Keywords - N:N junction for announcements and keywords';

-- ============================================================================
-- 6. QUALIFICATION_SCORES - Relevance scoring (1:1 with announcements)
-- ============================================================================
CREATE TABLE IF NOT EXISTS qualification_scores (
  score_id INT PRIMARY KEY AUTO_INCREMENT COMMENT 'Unique score identifier',
  announcement_id BIGINT UNIQUE NOT NULL COMMENT 'Foreign key: announcement (1:1)',
  pertinence_score INT NOT NULL COMMENT 'Final score 0-100',
  alert_level VARCHAR(50) DEFAULT 'NORMAL' COMMENT 'CRITIQUE, URGENT, NORMAL, or IGNORE',
  scoring_reason TEXT COMMENT 'Explanation of score',
  keyword_bonus INT DEFAULT 0 COMMENT 'Keyword bonus points',
  amount_bonus INT DEFAULT 0 COMMENT 'Amount bonus points',
  deadline_bonus INT DEFAULT 0 COMMENT 'Deadline urgency bonus',
  buyer_bonus INT DEFAULT 0 COMMENT 'Buyer preference bonus',
  calculated_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Calculation timestamp',
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
  
  CONSTRAINT fk_qs_announcement 
    FOREIGN KEY (announcement_id) REFERENCES announcements(announcement_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  
  CONSTRAINT ck_score_range
    CHECK (pertinence_score >= 0 AND pertinence_score <= 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Qualification_Scores - Relevance scoring for announcements';

-- ============================================================================
-- 7. NOTIFICATIONS - Alerts for qualified announcements
-- ============================================================================
CREATE TABLE IF NOT EXISTS notifications (
  notification_id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT 'Unique notification identifier',
  announcement_id BIGINT NOT NULL COMMENT 'Foreign key: announcement',
  alert_type VARCHAR(50) NOT NULL COMMENT 'NEW_OPPORTUNITY, DEADLINE_CRITICAL, etc',
  status VARCHAR(50) DEFAULT 'NEW' COMMENT 'NEW, SENT, ACKNOWLEDGED, or ARCHIVED',
  priority INT DEFAULT 3 COMMENT '1=urgent, 5=low',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation timestamp',
  sent_at DATETIME COMMENT 'Send timestamp',
  acknowledged_at DATETIME COMMENT 'Acknowledgment timestamp',
  message LONGTEXT COMMENT 'Alert message content',
  
  CONSTRAINT fk_notif_announcement 
    FOREIGN KEY (announcement_id) REFERENCES announcements(announcement_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  
  CONSTRAINT ck_priority_range
    CHECK (priority >= 1 AND priority <= 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Notifications - Alerts for qualified announcements';

-- ============================================================================
-- 8. TECHNICAL_LOGS - Technical audit (90-day retention)
-- ============================================================================
CREATE TABLE IF NOT EXISTS technical_logs (
  log_id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT 'Unique log identifier',
  timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Operation timestamp',
  operation_type VARCHAR(100) NOT NULL COMMENT 'IMPORT_API, SCORE_CALCULATION, BACKUP, etc',
  operation_source VARCHAR(100) COMMENT 'Notebook name, trigger name, etc',
  status VARCHAR(50) DEFAULT 'OK' COMMENT 'OK, WARNING, or ERROR',
  message TEXT COMMENT 'Log message',
  details_json JSON COMMENT 'Structured details (stack trace, HTTP status, etc)',
  duration_ms INT COMMENT 'Operation duration in milliseconds'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Technical_Logs - Technical audit trail (90-day retention)';

-- ============================================================================
-- 9. BUSINESS_LOGS - Business audit (full history)
-- ============================================================================
CREATE TABLE IF NOT EXISTS business_logs (
  log_id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT 'Unique log identifier',
  announcement_id BIGINT NOT NULL COMMENT 'Foreign key: announcement',
  timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Operation timestamp',
  operation_type VARCHAR(100) NOT NULL COMMENT 'STATUS_CHANGE, SCORE_RECALC, KEYWORD_ADD, etc',
  user VARCHAR(255) COMMENT 'User or system that made the change',
  description TEXT COMMENT 'Description of change',
  before_state JSON COMMENT 'State before change',
  after_state JSON COMMENT 'State after change',
  
  CONSTRAINT fk_bl_announcement 
    FOREIGN KEY (announcement_id) REFERENCES announcements(announcement_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Business_Logs - Business audit trail (full history)';

-- ============================================================================
-- 10. ANNOUNCEMENT_HISTORY - Version control (RGPD compliance)
-- ============================================================================
CREATE TABLE IF NOT EXISTS announcement_history (
  history_id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT 'Unique history identifier',
  announcement_id BIGINT NOT NULL COMMENT 'Foreign key: announcement',
  timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Modification timestamp',
  modification_type VARCHAR(100) COMMENT 'INSERT, UPDATE, or DELETE',
  modified_column VARCHAR(100) COMMENT 'Column that was modified',
  old_value TEXT COMMENT 'Old value',
  new_value TEXT COMMENT 'New value',
  
  CONSTRAINT fk_ah_announcement 
    FOREIGN KEY (announcement_id) REFERENCES announcements(announcement_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Announcement_History - Version control (RGPD compliant)';

-- ============================================================================
-- 11. BACKUP_LOGS - Backup audit (RTO/RPO tracking)
-- ============================================================================
CREATE TABLE IF NOT EXISTS backup_logs (
  backup_id INT PRIMARY KEY AUTO_INCREMENT COMMENT 'Unique backup identifier',
  timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Backup timestamp',
  backup_type VARCHAR(50) DEFAULT 'FULL' COMMENT 'FULL or INCREMENTAL',
  backup_file VARCHAR(500) NOT NULL COMMENT 'Backup file path',
  status VARCHAR(50) DEFAULT 'OK' COMMENT 'OK or ERROR',
  file_size BIGINT COMMENT 'Backup file size in bytes',
  duration_seconds INT COMMENT 'Backup duration in seconds',
  error_message TEXT COMMENT 'Error message if backup failed'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Backup_Logs - Backup audit trail';

-- ============================================================================
-- VERIFICATION: Count all created tables
-- ============================================================================

SELECT 
  'SUCCESS: All 11 tables created' as message,
  COUNT(*) as table_count
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN (
    'sources', 'buyers', 'keywords', 'announcements',
    'announcement_keywords', 'qualification_scores', 'notifications',
    'technical_logs', 'business_logs', 'announcement_history', 'backup_logs'
  );

-- ============================================================================
-- END OF SCRIPT
-- ============================================================================
