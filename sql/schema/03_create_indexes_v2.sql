-- ============================================================================
-- UNITEE - STRATEGIC INDEXES (V2 - Based on UML)
-- Date: 2026-04-08
-- Version: 2.0
-- 
-- Strategic indexes for performance optimization
-- ============================================================================

USE unitee;

-- ============================================================================
-- SOURCES TABLE INDEXES
-- ============================================================================
CREATE INDEX idx_sources_type ON sources (source_type);
CREATE INDEX idx_sources_active ON sources (active);

-- ============================================================================
-- BUYERS TABLE INDEXES
-- ============================================================================
CREATE INDEX idx_buyers_type ON buyers (buyer_type);
CREATE INDEX idx_buyers_region ON buyers (region);
CREATE INDEX idx_buyers_type_region ON buyers (buyer_type, region);

-- ============================================================================
-- KEYWORDS TABLE INDEXES
-- ============================================================================
CREATE INDEX idx_keywords_category ON keywords (category);

-- ============================================================================
-- ANNOUNCEMENTS TABLE INDEXES (CRITICAL PERFORMANCE)
-- ============================================================================
-- Deadline is CRITICAL for urgency calculation
CREATE INDEX idx_announcements_response_deadline ON announcements (response_deadline DESC);

-- Geographic filtering
CREATE INDEX idx_announcements_region ON announcements (region);

-- Status for filtering
CREATE INDEX idx_announcements_status ON announcements (status);

-- Date-based queries
CREATE INDEX idx_announcements_publication_date ON announcements (publication_date DESC);

-- Source tracking
CREATE INDEX idx_announcements_source ON announcements (source_id);

-- Buyer tracking
CREATE INDEX idx_announcements_buyer ON announcements (buyer_id);

-- Import tracking
CREATE INDEX idx_announcements_imported_at ON announcements (imported_at DESC);

-- Update tracking
CREATE INDEX idx_announcements_updated_at ON announcements (updated_at DESC);

-- Composite indexes for common queries
CREATE INDEX idx_announcements_status_deadline ON announcements (status, response_deadline DESC);
CREATE INDEX idx_announcements_region_deadline ON announcements (region, response_deadline DESC);

-- ============================================================================
-- ANNOUNCEMENT_KEYWORDS TABLE INDEXES
-- ============================================================================
CREATE INDEX idx_ank_keyword ON announcement_keywords (keyword_id);
CREATE INDEX idx_ank_relevance ON announcement_keywords (relevance_score);
CREATE INDEX idx_ank_type ON announcement_keywords (extraction_type);
CREATE INDEX idx_ank_keyword_relevance ON announcement_keywords (keyword_id, relevance_score DESC);

-- ============================================================================
-- QUALIFICATION_SCORES TABLE INDEXES (CRITICAL FOR ALERTS)
-- ============================================================================
-- Alert level is critical for notification routing
CREATE INDEX idx_qs_score ON qualification_scores (pertinence_score DESC);
CREATE INDEX idx_qs_alert_level ON qualification_scores (alert_level);

-- Composite for alert queries
CREATE INDEX idx_qs_alert_score ON qualification_scores (alert_level, pertinence_score DESC);

-- ============================================================================
-- NOTIFICATIONS TABLE INDEXES
-- ============================================================================
CREATE INDEX idx_notif_status ON notifications (status);
CREATE INDEX idx_notif_priority ON notifications (priority);
CREATE INDEX idx_notif_created_at ON notifications (created_at DESC);
CREATE INDEX idx_notif_status_priority ON notifications (status, priority);

-- ============================================================================
-- TECHNICAL_LOGS TABLE INDEXES
-- ============================================================================
CREATE INDEX idx_tech_logs_timestamp ON technical_logs (timestamp DESC);
CREATE INDEX idx_tech_logs_type ON technical_logs (operation_type);
CREATE INDEX idx_tech_logs_status ON technical_logs (status);
CREATE INDEX idx_tech_logs_status_timestamp ON technical_logs (status, timestamp DESC);

-- ============================================================================
-- BUSINESS_LOGS TABLE INDEXES
-- ============================================================================
CREATE INDEX idx_bus_logs_announcement ON business_logs (announcement_id);
CREATE INDEX idx_bus_logs_timestamp ON business_logs (timestamp DESC);
CREATE INDEX idx_bus_logs_type ON business_logs (operation_type);
CREATE INDEX idx_bus_logs_announcement_timestamp ON business_logs (announcement_id, timestamp DESC);

-- ============================================================================
-- ANNOUNCEMENT_HISTORY TABLE INDEXES
-- ============================================================================
CREATE INDEX idx_hist_announcement ON announcement_history (announcement_id);
CREATE INDEX idx_hist_timestamp ON announcement_history (timestamp DESC);
CREATE INDEX idx_hist_announcement_timestamp ON announcement_history (announcement_id, timestamp DESC);

-- ============================================================================
-- BACKUP_LOGS TABLE INDEXES
-- ============================================================================
CREATE INDEX idx_backup_timestamp ON backup_logs (timestamp DESC);
CREATE INDEX idx_backup_status ON backup_logs (status);
CREATE INDEX idx_backup_status_timestamp ON backup_logs (status, timestamp DESC);

-- ============================================================================
-- VERIFICATION: Count all indexes
-- ============================================================================

SELECT 
  'SUCCESS: Strategic indexes created' as message,
  COUNT(*) as index_count
FROM information_schema.statistics
WHERE table_schema = DATABASE() 
  AND index_name != 'PRIMARY';

-- ============================================================================
-- END OF SCRIPT
-- ============================================================================
