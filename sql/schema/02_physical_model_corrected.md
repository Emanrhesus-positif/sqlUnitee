# UNITEE Phase 3 - Physical Data Model (MPD) - CORRECTED

**Project**: Automated Public Market Surveillance System  
**Version**: 2.0 (Corrected - English Naming, Actual Implementation)  
**Date**: 2026-04-08  
**Status**: Production-Ready

---

## Executive Summary

This document describes the **Physical Data Model (MPD)** as actually implemented in MySQL, correcting the discrepancies between the theoretical Logical Data Model (MLD - in French) and the actual deployed database structure (in English).

### Key Correction Points
- **Naming**: All table and column names use **English** (not French as in the MLD)
- **Structure**: Reflects the **11 tables actually deployed** in MySQL
- **Implementation**: Includes actual constraints, indexes, and relationships
- **Scope**: Covers core business tables, audit logging, archiving, and data quality

---

## 1. Physical Schema Overview

### 1.1 Database Configuration
```sql
CREATE DATABASE unitee CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

| Property | Value |
|----------|-------|
| **Database Name** | unitee |
| **Character Set** | utf8mb4 |
| **Collation** | utf8mb4_unicode_ci |
| **Engine** | InnoDB (default for all tables) |
| **Storage** | SSD recommended (I/O intensive) |

### 1.2 Table Inventory

| # | Table Name | Type | Purpose | Rows (Est.) | Growth |
|---|---|---|---|---|---|
| 1 | `sources` | Reference | Data source registry | 10-50 | Slow |
| 2 | `buyers` | Reference | Public buyer registry | 500-2000 | Slow |
| 3 | `keywords` | Reference | Keyword catalog | 100-500 | Slow |
| 4 | `announcements` | **CORE** | Main business data | 50K-500K | **Fast** |
| 5 | `announcement_keywords` | Junction | N:N mapping | 200K-2M | **Fast** |
| 6 | `qualification_scores` | Derived | Scoring results (1:1) | 50K-500K | **Fast** |
| 7 | `notifications` | Transactional | Alert notifications | 100K-1M | **Fast** |
| 8 | `technical_logs` | Audit | System operation logs | 1M-10M | **Very Fast** |
| 9 | `business_logs` | Audit | Business audit trail | 100K-1M | **Fast** |
| 10 | `announcement_history` | Archive | Version control/GDPR | 200K-2M | **Fast** |
| 11 | `backup_logs` | Audit | Backup tracking | 1K-10K | Slow |

**Total Tables**: 11  
**Reference Tables**: 3  
**Core Business Tables**: 1 (+ 3 supporting)  
**Audit/Archive Tables**: 4

---

## 2. Table Definitions

### 2.1 SOURCES - Reference Table

**Purpose**: Registry of data sources (APIs, web scraping, RSS feeds)  
**Cardinality**: 1 source → many announcements (1:N)  
**Growth**: Slow (new sources added quarterly)  
**Retention**: Permanent

| Column | Type | Key | Nullable | Default | Comment |
|--------|------|-----|----------|---------|---------|
| `source_id` | INT | PK | NO | AUTO_INCREMENT | Unique source identifier |
| `source_name` | VARCHAR(100) | UNIQUE | NO | — | Source name (BOAMP, data.gouv.fr, synthetic) |
| `description` | TEXT | — | YES | NULL | Source description and usage notes |
| `api_base_url` | VARCHAR(500) | — | YES | NULL | API base URL for programmatic access |
| `source_type` | VARCHAR(50) | — | NO | 'API' | Type: API, SCRAPING, or FLUX_RSS |
| `active` | BOOLEAN | — | NO | true | Is source currently active |
| `created_at` | DATETIME | — | NO | CURRENT_TIMESTAMP | Creation timestamp |

**Indexes**:
- PRIMARY KEY (source_id)
- UNIQUE (source_name)
- INDEX idx_sources_type (source_type)
- INDEX idx_sources_active (active)

**Constraints**:
- PK: source_id
- UNIQUE: source_name
- CHECK: source_type IN ('API', 'SCRAPING', 'FLUX_RSS')

**Example Data**:
```sql
INSERT INTO sources VALUES
  (1, 'BOAMP', 'Official French public procurement bulletin', 'https://api.boamp.fr', 'API', true, NOW()),
  (2, 'data.gouv.fr', 'French government open data portal', 'https://api.data.gouv.fr', 'API', true, NOW()),
  (3, 'SYNTHETIC', 'Synthetic test data for development', NULL, 'SCRAPING', true, NOW());
```

---

### 2.2 BUYERS - Reference Table

**Purpose**: Registry of public buyers (collectivités, état, public enterprises)  
**Cardinality**: 1 buyer → many announcements (1:N)  
**Growth**: Slow (new buyers added as they enter market)  
**Retention**: Permanent (historical reference)

| Column | Type | Key | Nullable | Default | Comment |
|--------|------|-----|----------|---------|---------|
| `buyer_id` | INT | PK | NO | AUTO_INCREMENT | Unique buyer identifier |
| `buyer_name` | VARCHAR(255) | UNIQUE | NO | — | Official buyer name |
| `buyer_type` | VARCHAR(100) | — | YES | NULL | Type: COLLECTIVITE, ETAT, or ENTREPRISE_PUBLIQUE |
| `region` | VARCHAR(100) | — | YES | NULL | Region for geographic filtering (Île-de-France, etc.) |
| `contact_email` | VARCHAR(255) | — | YES | NULL | Contact email address |
| `contact_phone` | VARCHAR(20) | — | YES | NULL | Contact phone number |
| `created_at` | DATETIME | — | NO | CURRENT_TIMESTAMP | Creation timestamp |

**Indexes**:
- PRIMARY KEY (buyer_id)
- UNIQUE (buyer_name)
- INDEX idx_buyers_type (buyer_type)
- INDEX idx_buyers_region (region)
- INDEX idx_buyers_type_region (buyer_type, region) — Composite for filtering

**Constraints**:
- PK: buyer_id
- UNIQUE: buyer_name
- CHECK: buyer_type IN ('COLLECTIVITE', 'ETAT', 'ENTREPRISE_PUBLIQUE')

**Example Data**:
```sql
INSERT INTO buyers VALUES
  (1, 'Mairie de Paris', 'COLLECTIVITE', 'Île-de-France', 'contact@paris.fr', NULL, NOW()),
  (2, 'Ministère des Affaires Sociales', 'ETAT', 'Île-de-France', 'contact@social.gouv.fr', NULL, NOW());
```

---

### 2.3 KEYWORDS - Reference Table

**Purpose**: Catalog of relevant keywords for market surveillance filtering  
**Cardinality**: 1 keyword → many announcements (1:N via junction)  
**Growth**: Slow (new keywords added as business needs evolve)  
**Retention**: Permanent (reference)

| Column | Type | Key | Nullable | Default | Comment |
|--------|------|-----|----------|---------|---------|
| `keyword_id` | INT | PK | NO | AUTO_INCREMENT | Unique keyword identifier |
| `keyword_text` | VARCHAR(100) | UNIQUE | NO | — | Exact keyword text (e.g., "modulaire", "préfabriqué") |
| `category` | VARCHAR(50) | — | NO | 'SECONDARY' | Category: PRIMARY, SECONDARY, or EXTRACTED |
| `created_at` | DATETIME | — | NO | CURRENT_TIMESTAMP | Creation timestamp |

**Indexes**:
- PRIMARY KEY (keyword_id)
- UNIQUE (keyword_text)
- INDEX idx_keywords_category (category)

**Constraints**:
- PK: keyword_id
- UNIQUE: keyword_text
- CHECK: category IN ('PRIMARY', 'SECONDARY', 'EXTRACTED')

**Example Data**:
```sql
INSERT INTO keywords VALUES
  (1, 'modulaire', 'PRIMARY', NOW()),
  (2, 'préfabriqué', 'PRIMARY', NOW()),
  (3, 'assemblage', 'PRIMARY', NOW()),
  (4, 'construction', 'SECONDARY', NOW());
```

**Scoring Impact**: Keywords in PRIMARY category provide +30 points to announcement score (see Qualification_Scores)

---

### 2.4 ANNOUNCEMENTS - Core Business Table ⭐

**Purpose**: Main business table containing all public market announcements  
**Cardinality**: Central hub; 1:N relationships with sources, buyers, keywords, scores, notifications  
**Growth**: **Very fast** — 500-5000 new announcements daily (scalability concern)  
**Retention**: Permanent with soft-delete (status field)

| Column | Type | Key | Nullable | Default | Comment |
|--------|------|-----|----------|---------|---------|
| `announcement_id` | BIGINT | PK | NO | AUTO_INCREMENT | Unique announcement identifier |
| `source_id` | INT | FK | NO | — | Foreign key to sources table |
| `buyer_id` | INT | FK | NO | — | Foreign key to buyers table |
| `external_id` | VARCHAR(100) | — | NO | — | External ID from source system (unique per source) |
| `title` | VARCHAR(500) | — | NO | — | Announcement title (min 6 characters) |
| `description` | LONGTEXT | — | YES | NULL | Full announcement description (can be very large) |
| `estimated_amount` | DECIMAL(15,2) | — | YES | NULL | Estimated budget in EUR (nullable for undisclosed amounts) |
| `currency` | VARCHAR(3) | — | NO | 'EUR' | Currency code (ISO 4217) |
| `publication_date` | DATETIME | — | NO | — | **CRITICAL**: Date announcement was published |
| `response_deadline` | DATETIME | — | NO | — | **CRITICAL**: Deadline for responding to opportunity |
| `location` | VARCHAR(255) | — | YES | NULL | Geographic location where work will be executed |
| `region` | VARCHAR(100) | — | YES | NULL | Region code for filtering (Île-de-France, etc.) |
| `source_link` | VARCHAR(500) | UNIQUE | YES | NULL | URL to source announcement (max 1 per announcement) |
| `status` | VARCHAR(50) | — | NO | 'NEW' | Status: NEW, QUALIFIED, IGNORED, or RESPONDED |
| `imported_at` | DATETIME | — | NO | CURRENT_TIMESTAMP | When announcement was first imported |
| `updated_at` | DATETIME | — | NO | CURRENT_TIMESTAMP | Last modification timestamp (auto-updated) |

**Foreign Keys**:
```sql
CONSTRAINT fk_announcements_source 
  FOREIGN KEY (source_id) REFERENCES sources(source_id)
  ON DELETE RESTRICT ON UPDATE CASCADE

CONSTRAINT fk_announcements_buyer 
  FOREIGN KEY (buyer_id) REFERENCES buyers(buyer_id)
  ON DELETE RESTRICT ON UPDATE CASCADE
```

**Unique Constraints**:
```sql
CONSTRAINT uk_announcement_doublon
  UNIQUE (source_id, external_id)  -- No duplicates per source
```

**Check Constraints**:
```sql
CONSTRAINT ck_title_length
  CHECK (CHAR_LENGTH(title) > 5)  -- Min 6 characters

CONSTRAINT ck_amount_positive
  CHECK (estimated_amount IS NULL OR estimated_amount >= 0)  -- No negative amounts

CONSTRAINT ck_dates_logic 
  CHECK (publication_date <= response_deadline)  -- Publication before deadline
```

**Critical Indexes** (Performance-sensitive):
```sql
PRIMARY KEY (announcement_id)
UNIQUE (source_link)
UNIQUE (source_id, external_id)
INDEX idx_announcements_response_deadline (response_deadline DESC)  -- MOST CRITICAL for urgency
INDEX idx_announcements_region (region)  -- Geographic filtering
INDEX idx_announcements_status (status)  -- Status filtering
INDEX idx_announcements_publication_date (publication_date DESC)  -- Timeline
INDEX idx_announcements_source (source_id)  -- Source tracking
INDEX idx_announcements_buyer (buyer_id)  -- Buyer tracking
INDEX idx_announcements_imported_at (imported_at DESC)  -- Import tracking
INDEX idx_announcements_updated_at (updated_at DESC)  -- Change tracking
-- Composite indexes for common queries:
INDEX idx_announcements_status_deadline (status, response_deadline DESC)
INDEX idx_announcements_region_deadline (region, response_deadline DESC)
```

**Triggers**:
1. `before_announcement_insert` — Validate title length, dates, amounts
2. `after_announcement_insert` — Auto-calculate scoring via `CalculerScorePertinence()`
3. `after_announcement_update` — Detect and log changes
4. `before_announcement_delete` — Archive to `announcement_history`

**Example Data**:
```sql
INSERT INTO announcements VALUES (
  NULL,  -- announcement_id (AUTO_INCREMENT)
  1,     -- source_id (BOAMP)
  1,     -- buyer_id (Mairie de Paris)
  'BOAMP-2026-0001234',  -- external_id
  'Construction of modular office complex in Île-de-France region',  -- title
  'Full description...', -- description (LONGTEXT)
  250000.00,  -- estimated_amount
  'EUR',  -- currency
  '2026-04-08 10:00:00',  -- publication_date
  '2026-05-08 17:00:00',  -- response_deadline (30 days)
  'Paris, Île-de-France',  -- location
  'Île-de-France',  -- region
  'https://boamp.fr/annonce/2026-0001234',  -- source_link
  'NEW',  -- status
  CURRENT_TIMESTAMP,  -- imported_at
  CURRENT_TIMESTAMP   -- updated_at
);
```

---

### 2.5 ANNOUNCEMENT_KEYWORDS - Junction Table (N:N)

**Purpose**: Maps announcements to keywords (N:N relationship with relevance tracking)  
**Cardinality**: Many announcement-keyword pairs  
**Growth**: Fast — scales with announcements and keywords  
**Retention**: Cascade delete with announcements

| Column | Type | Key | Nullable | Default | Comment |
|--------|------|-----|----------|---------|---------|
| `announcement_id` | BIGINT | PK, FK | NO | — | Foreign key to announcements |
| `keyword_id` | INT | PK, FK | NO | — | Foreign key to keywords |
| `relevance_score` | INT | — | NO | 50 | Relevance score 0-100 (default 50) |
| `extraction_type` | VARCHAR(50) | — | NO | 'REGEX' | How keyword was extracted: TF-IDF, REGEX, MANUAL, or LLM |
| `extracted_at` | DATETIME | — | NO | CURRENT_TIMESTAMP | Extraction timestamp |

**Foreign Keys**:
```sql
CONSTRAINT fk_ank_announcement 
  FOREIGN KEY (announcement_id) REFERENCES announcements(announcement_id)
  ON DELETE CASCADE ON UPDATE CASCADE

CONSTRAINT fk_ank_keyword 
  FOREIGN KEY (keyword_id) REFERENCES keywords(keyword_id)
  ON DELETE RESTRICT ON UPDATE CASCADE
```

**Composite Key**:
```sql
PRIMARY KEY (announcement_id, keyword_id)
```

**Check Constraints**:
```sql
CONSTRAINT ck_relevance_score
  CHECK (relevance_score >= 0 AND relevance_score <= 100)
```

**Indexes**:
```sql
PRIMARY KEY (announcement_id, keyword_id)
INDEX idx_ank_keyword (keyword_id)  -- For keyword-centric queries
INDEX idx_ank_relevance (relevance_score)  -- For filtering by relevance
INDEX idx_ank_type (extraction_type)  -- For tracking extraction methods
INDEX idx_ank_keyword_relevance (keyword_id, relevance_score DESC)  -- Composite
```

**Example Data**:
```sql
INSERT INTO announcement_keywords VALUES
  (1, 1, 95, 'REGEX', NOW()),      -- Strong match on 'modulaire'
  (1, 2, 87, 'REGEX', NOW()),      -- Match on 'préfabriqué'
  (1, 3, 72, 'TF-IDF', NOW());     -- Extract match on 'assemblage'
```

---

### 2.6 QUALIFICATION_SCORES - Derived/Scoring Table

**Purpose**: Stores calculated relevance scores and alert levels (1:1 relationship with announcements)  
**Cardinality**: Exactly 1 score per announcement (enforced by UNIQUE constraint)  
**Growth**: Fast — same as announcements  
**Retention**: Cascade delete with announcements

| Column | Type | Key | Nullable | Default | Comment |
|--------|------|-----|----------|---------|---------|
| `score_id` | INT | PK | NO | AUTO_INCREMENT | Unique score identifier |
| `announcement_id` | BIGINT | FK, UNIQUE | NO | — | Foreign key to announcements (1:1) |
| `pertinence_score` | INT | — | NO | — | Final relevance score 0-100 |
| `alert_level` | VARCHAR(50) | — | NO | 'NORMAL' | Alert category: CRITIQUE, URGENT, NORMAL, or IGNORE |
| `scoring_reason` | TEXT | — | YES | NULL | Explanation of score calculation |
| `keyword_bonus` | INT | — | NO | 0 | Bonus from keywords (+0 to +30) |
| `amount_bonus` | INT | — | NO | 0 | Bonus from amount (+0 to +25) |
| `deadline_bonus` | INT | — | NO | 0 | Bonus from deadline urgency (+0 to +15) |
| `buyer_bonus` | INT | — | NO | 0 | Bonus from buyer preference (+0 to +5) |
| `calculated_at` | DATETIME | — | NO | CURRENT_TIMESTAMP | When score was calculated |
| `updated_at` | DATETIME | — | NO | CURRENT_TIMESTAMP | When score was last updated |

**Foreign Keys**:
```sql
CONSTRAINT fk_qs_announcement 
  FOREIGN KEY (announcement_id) REFERENCES announcements(announcement_id)
  ON DELETE CASCADE ON UPDATE CASCADE
```

**Check Constraints**:
```sql
CONSTRAINT ck_score_range
  CHECK (pertinence_score >= 0 AND pertinence_score <= 100)
```

**Indexes**:
```sql
PRIMARY KEY (score_id)
UNIQUE (announcement_id)  -- Enforces 1:1 relationship
INDEX idx_qs_score (pertinence_score DESC)  -- For score-based filtering
INDEX idx_qs_alert_level (alert_level)  -- For alert categorization
INDEX idx_qs_alert_score (alert_level, pertinence_score DESC)  -- Composite
```

**Triggers**:
- Before insert: Validate score range (0-100) and alert level values
- After update: Log changes to business_logs for audit trail

**Alert Level Logic** (via `CategoriserAlerte()` function):
```
CRITIQUE:  score > 75 AND deadline_days ≤ 7
URGENT:    (score > 75 OR score > 60) AND deadline_days ≤ 14
NORMAL:    score > 50 (and not expired)
IGNORE:    score ≤ 50 OR deadline_days < 0
```

**Example Data**:
```sql
INSERT INTO qualification_scores VALUES (
  NULL,  -- score_id (AUTO_INCREMENT)
  1,     -- announcement_id
  92,    -- pertinence_score (high)
  'CRITIQUE',  -- alert_level (urgent + high score)
  'High-value modular construction opportunity with tight deadline',  -- scoring_reason
  30,    -- keyword_bonus (matched PRIMARY keywords)
  25,    -- amount_bonus (€250k > €100k)
  15,    -- deadline_bonus (< 7 days)
  5,     -- buyer_bonus
  NOW(), -- calculated_at
  NOW()  -- updated_at
);
```

---

### 2.7 NOTIFICATIONS - Transactional Table

**Purpose**: Alert notifications generated for qualified announcements  
**Cardinality**: 1 announcement → many notifications (can have multiple alert types)  
**Growth**: Fast — varies with alert rules  
**Retention**: Automatic archival after 90 days (via stored procedure)

| Column | Type | Key | Nullable | Default | Comment |
|--------|------|-----|----------|---------|---------|
| `notification_id` | BIGINT | PK | NO | AUTO_INCREMENT | Unique notification identifier |
| `announcement_id` | BIGINT | FK | NO | — | Foreign key to announcements |
| `alert_type` | VARCHAR(50) | — | NO | — | Type: NEW_OPPORTUNITY, DEADLINE_CRITICAL, etc |
| `status` | VARCHAR(50) | — | NO | 'NEW' | Status: NEW, SENT, ACKNOWLEDGED, or ARCHIVED |
| `priority` | INT | — | NO | 3 | Priority level 1-5 (1=urgent, 5=low) |
| `created_at` | DATETIME | — | NO | CURRENT_TIMESTAMP | When notification was created |
| `sent_at` | DATETIME | — | YES | NULL | When notification was actually sent |
| `acknowledged_at` | DATETIME | — | YES | NULL | When user acknowledged notification |
| `message` | LONGTEXT | — | YES | NULL | Alert message content (can be large) |

**Foreign Keys**:
```sql
CONSTRAINT fk_notif_announcement 
  FOREIGN KEY (announcement_id) REFERENCES announcements(announcement_id)
  ON DELETE CASCADE ON UPDATE CASCADE
```

**Check Constraints**:
```sql
CONSTRAINT ck_priority_range
  CHECK (priority >= 1 AND priority <= 5)

CONSTRAINT ck_status_values
  CHECK (status IN ('NEW', 'SENT', 'ACKNOWLEDGED', 'ARCHIVED'))
```

**Indexes**:
```sql
PRIMARY KEY (notification_id)
INDEX idx_notif_status (status)  -- For filtering pending notifications
INDEX idx_notif_priority (priority)  -- For priority-based routing
INDEX idx_notif_created_at (created_at DESC)  -- For timeline queries
INDEX idx_notif_status_priority (status, priority)  -- Composite for routing
FOREIGN KEY (announcement_id)  -- Implicit index
```

**Triggers**:
- After insert: Log notification creation to technical_logs

**Example Data**:
```sql
INSERT INTO notifications VALUES (
  NULL,  -- notification_id (AUTO_INCREMENT)
  1,     -- announcement_id
  'NEW_OPPORTUNITY',  -- alert_type
  'SENT',  -- status
  1,     -- priority (urgent)
  '2026-04-08 10:30:00',  -- created_at
  '2026-04-08 10:35:00',  -- sent_at
  NULL,  -- acknowledged_at (not yet)
  'CRITIQUE alert: €250k modular construction opportunity, deadline 2026-05-08'  -- message
);
```

---

### 2.8 TECHNICAL_LOGS - Audit Table

**Purpose**: Technical operation audit trail (90-day retention by default)  
**Cardinality**: Many logs per operation  
**Growth**: **Very fast** — thousands per day  
**Retention**: Pruning by `ArchiverDonneesAncienne()` stored procedure (90 days)

| Column | Type | Key | Nullable | Default | Comment |
|--------|------|-----|----------|---------|---------|
| `log_id` | BIGINT | PK | NO | AUTO_INCREMENT | Unique log identifier |
| `timestamp` | DATETIME | — | NO | CURRENT_TIMESTAMP | Operation timestamp |
| `operation_type` | VARCHAR(100) | — | NO | — | Type: IMPORT_API, SCORE_CALCULATION, BACKUP, TRIGGER_FIRE, etc |
| `operation_source` | VARCHAR(100) | — | YES | NULL | Source of operation (trigger name, notebook, etc) |
| `status` | VARCHAR(50) | — | NO | 'OK' | Status: OK, WARNING, or ERROR |
| `message` | TEXT | — | YES | NULL | Log message (human-readable) |
| `details_json` | JSON | — | YES | NULL | Structured details (stack trace, HTTP status, response codes) |
| `duration_ms` | INT | — | YES | NULL | Operation duration in milliseconds |

**Indexes**:
```sql
PRIMARY KEY (log_id)
INDEX idx_tech_logs_timestamp (timestamp DESC)  -- For time-range queries
INDEX idx_tech_logs_type (operation_type)  -- For operation-specific filtering
INDEX idx_tech_logs_status (status)  -- For error analysis
INDEX idx_tech_logs_status_timestamp (status, timestamp DESC)  -- Composite
```

**Retention Policy**:
- Automatic purging: Older than 90 days (executed by `ArchiverDonneesAncienne()`)
- Can be overridden by changing the retention interval

**Example Data**:
```sql
INSERT INTO technical_logs VALUES (
  NULL,  -- log_id (AUTO_INCREMENT)
  NOW(),  -- timestamp
  'SCORE_CALCULATION',  -- operation_type
  'trigger: after_announcement_insert',  -- operation_source
  'OK',  -- status
  'Score calculated: 92/100, alert=CRITIQUE',  -- message
  JSON_OBJECT('score', 92, 'components', JSON_OBJECT('keywords', 30, 'amount', 25)),  -- details_json
  147  -- duration_ms
);
```

---

### 2.9 BUSINESS_LOGS - Audit Table

**Purpose**: Business-level audit trail (full history, no automatic pruning)  
**Cardinality**: Many logs per announcement  
**Growth**: Fast — one per significant change  
**Retention**: Permanent (GDPR compliance)

| Column | Type | Key | Nullable | Default | Comment |
|--------|------|-----|----------|---------|---------|
| `log_id` | BIGINT | PK | NO | AUTO_INCREMENT | Unique log identifier |
| `announcement_id` | BIGINT | FK | NO | — | Foreign key to announcements |
| `timestamp` | DATETIME | — | NO | CURRENT_TIMESTAMP | When change occurred |
| `operation_type` | VARCHAR(100) | — | NO | — | Type: STATUS_CHANGE, SCORE_RECALC, KEYWORD_ADD, RESPONSE_RECORDED, etc |
| `user` | VARCHAR(255) | — | YES | NULL | User or system that made the change |
| `description` | TEXT | — | YES | NULL | Human-readable description of change |
| `before_state` | JSON | — | YES | NULL | State before change (snapshot of affected columns) |
| `after_state` | JSON | — | YES | NULL | State after change (snapshot of affected columns) |

**Foreign Keys**:
```sql
CONSTRAINT fk_bl_announcement 
  FOREIGN KEY (announcement_id) REFERENCES announcements(announcement_id)
  ON DELETE CASCADE ON UPDATE CASCADE
```

**Indexes**:
```sql
PRIMARY KEY (log_id)
INDEX idx_bus_logs_announcement (announcement_id)  -- For announcement-centric audit
INDEX idx_bus_logs_timestamp (timestamp DESC)  -- For timeline queries
INDEX idx_bus_logs_type (operation_type)  -- For change type analysis
INDEX idx_bus_logs_announcement_timestamp (announcement_id, timestamp DESC)  -- Composite
```

**Example Data**:
```sql
INSERT INTO business_logs VALUES (
  NULL,  -- log_id (AUTO_INCREMENT)
  1,     -- announcement_id
  NOW(),  -- timestamp
  'STATUS_CHANGE',  -- operation_type
  'system:trigger',  -- user
  'Automatic status update based on score',  -- description
  JSON_OBJECT('status', 'NEW'),  -- before_state
  JSON_OBJECT('status', 'QUALIFIED')  -- after_state
);
```

---

### 2.10 ANNOUNCEMENT_HISTORY - Archive Table

**Purpose**: Version control and soft-delete tracking (GDPR-compliant)  
**Cardinality**: Multiple versions per announcement  
**Growth**: Fast — one entry per modification  
**Retention**: Permanent (GDPR requirement)

| Column | Type | Key | Nullable | Default | Comment |
|--------|------|-----|----------|---------|---------|
| `history_id` | BIGINT | PK | NO | AUTO_INCREMENT | Unique history entry identifier |
| `announcement_id` | BIGINT | FK | NO | — | Foreign key to announcements |
| `timestamp` | DATETIME | — | NO | CURRENT_TIMESTAMP | When change occurred |
| `modification_type` | VARCHAR(100) | — | YES | NULL | Type: INSERT, UPDATE, or DELETE |
| `modified_column` | VARCHAR(100) | — | YES | NULL | Name of column that was modified |
| `old_value` | TEXT | — | YES | NULL | Previous value (before change) |
| `new_value` | TEXT | — | YES | NULL | New value (after change) |

**Foreign Keys**:
```sql
CONSTRAINT fk_ah_announcement 
  FOREIGN KEY (announcement_id) REFERENCES announcements(announcement_id)
  ON DELETE CASCADE ON UPDATE CASCADE
```

**Indexes**:
```sql
PRIMARY KEY (history_id)
INDEX idx_hist_announcement (announcement_id)  -- For version retrieval
INDEX idx_hist_timestamp (timestamp DESC)  -- For timeline queries
INDEX idx_hist_announcement_timestamp (announcement_id, timestamp DESC)  -- Composite
```

**Example Data**:
```sql
INSERT INTO announcement_history VALUES (
  NULL,  -- history_id (AUTO_INCREMENT)
  1,     -- announcement_id
  NOW(),  -- timestamp
  'UPDATE',  -- modification_type
  'title',  -- modified_column
  'Construction of modular office complex',  -- old_value
  'Construction of premium modular office complex',  -- new_value
);
```

---

### 2.11 BACKUP_LOGS - Audit Table

**Purpose**: Backup audit trail for RTO/RPO tracking  
**Cardinality**: One entry per backup  
**Growth**: Slow (daily or weekly backups)  
**Retention**: 1 year or per compliance policy

| Column | Type | Key | Nullable | Default | Comment |
|--------|------|-----|----------|---------|---------|
| `backup_id` | INT | PK | NO | AUTO_INCREMENT | Unique backup identifier |
| `timestamp` | DATETIME | — | NO | CURRENT_TIMESTAMP | When backup was created |
| `backup_type` | VARCHAR(50) | — | NO | 'FULL' | Type: FULL or INCREMENTAL |
| `backup_file` | VARCHAR(500) | — | NO | — | Path to backup file |
| `status` | VARCHAR(50) | — | NO | 'OK' | Status: OK or ERROR |
| `file_size` | BIGINT | — | YES | NULL | Backup file size in bytes |
| `duration_seconds` | INT | — | YES | NULL | Backup duration in seconds |
| `error_message` | TEXT | — | YES | NULL | Error message if backup failed |

**Indexes**:
```sql
PRIMARY KEY (backup_id)
INDEX idx_backup_timestamp (timestamp DESC)  -- For backup history
INDEX idx_backup_status (status)  -- For failure analysis
INDEX idx_backup_status_timestamp (status, timestamp DESC)  -- Composite
```

**Retention Policy**:
- 1 year standard retention
- Can be extended per compliance requirements

**Example Data**:
```sql
INSERT INTO backup_logs VALUES (
  NULL,  -- backup_id (AUTO_INCREMENT)
  NOW(),  -- timestamp
  'FULL',  -- backup_type
  '/backups/unitee_2026-04-08_220000.sql.gz',  -- backup_file
  'OK',  -- status
  1073741824,  -- file_size (1GB)
  3600,  -- duration_seconds (1 hour)
  NULL  -- error_message (no error)
);
```

---

## 3. Relationships & Cardinality

### 3.1 Entity Relationship Diagram (Text Representation)

```
SOURCES (1) ────── (N) ANNOUNCEMENTS
  │                      │
  │                      │ (N:N via announcement_keywords)
  │                      │
  └──────────────────────┤
                         │
BUYERS (1) ────── (N) ANNOUNCEMENTS ──── (1) QUALIFICATION_SCORES
                         │
                         ├──── (N) NOTIFICATIONS
                         │
                         ├──── (N) ANNOUNCEMENT_KEYWORDS ──── KEYWORDS (1)
                         │                (1):(N)
                         │
                         ├──── (N) BUSINESS_LOGS
                         │
                         ├──── (N) ANNOUNCEMENT_HISTORY
                         │
                         └──── (Referenced by) TECHNICAL_LOGS
                         
BACKUP_LOGS (independent)
```

### 3.2 Foreign Key Relationships

| Relationship | Type | Cardinality | Actions |
|---|---|---|---|
| sources → announcements | 1:N | 1 source : N announcements | FK: ON DELETE RESTRICT, ON UPDATE CASCADE |
| buyers → announcements | 1:N | 1 buyer : N announcements | FK: ON DELETE RESTRICT, ON UPDATE CASCADE |
| announcements → qualification_scores | 1:1 | 1 announcement : 1 score | FK: ON DELETE CASCADE, ON UPDATE CASCADE |
| announcements → announcement_keywords | 1:N | 1 announcement : N keywords | FK: ON DELETE CASCADE, ON UPDATE CASCADE |
| keywords → announcement_keywords | 1:N | 1 keyword : N announcements | FK: ON DELETE RESTRICT, ON UPDATE CASCADE |
| announcements → notifications | 1:N | 1 announcement : N notifications | FK: ON DELETE CASCADE, ON UPDATE CASCADE |
| announcements → business_logs | 1:N | 1 announcement : N logs | FK: ON DELETE CASCADE, ON UPDATE CASCADE |
| announcements → announcement_history | 1:N | 1 announcement : N versions | FK: ON DELETE CASCADE, ON UPDATE CASCADE |

### 3.3 Cardinality Notes

**High-Growth Relationships**:
- announcements ← technical_logs (Very high, ~1000s logs/day)
- announcements ← announcement_keywords (High, ~2-10 keywords per announcement)
- announcements ← notifications (Medium, ~1 notification per announcement)

**Cascade Delete Behavior**:
- Deleting an announcement cascades to:
  - qualification_scores (1:1)
  - announcement_keywords (N:N)
  - notifications (N:N)
  - business_logs (audit trail)
  - announcement_history (version control)
- Deleting a source or buyer is RESTRICTED (no cascade)

---

## 4. Dashboard Views

### 4.1 View: `vw_kpi_resume` (KPI Summary)

**Purpose**: Global summary statistics for executive dashboard  
**Refresh**: Real-time (or cached every 5 minutes)

| Column | Type | Meaning |
|--------|------|---------|
| `total_announcements` | INT | Total active announcements (NEW, QUALIFIED) |
| `active_sources` | INT | Number of currently active sources |
| `active_buyers` | INT | Number of buyers with recent announcements |
| `regions_covered` | INT | Geographic coverage (distinct regions) |
| `announcements_with_amount` | INT | Announcements with estimated budget |
| `avg_amount` | DECIMAL | Average estimated amount |
| `min_amount` | DECIMAL | Minimum estimated amount |
| `max_amount` | DECIMAL | Maximum estimated amount |
| `earliest_publication` | DATETIME | Oldest active announcement |
| `latest_publication` | DATETIME | Newest announcement |
| `earliest_deadline` | DATETIME | Next upcoming deadline |
| `latest_deadline` | DATETIME | Furthest deadline |
| `generated_at` | DATETIME | When view was generated |

**Example**:
```
| total | sources | buyers | regions | with_amount | avg_amount | min | max | earliest_pub | latest_pub | earliest_deadline | latest_deadline |
|-------|---------|--------|---------|-------------|------------|-----|-----|------|------|------|------|
| 156 | 3 | 45 | 12 | 143 | 187543.00 | 10000.00 | 2500000.00 | 2026-03-01 | 2026-04-08 | 2026-04-15 | 2026-07-15 |
```

---

### 4.2 View: `vw_evolution_temporelle` (Timeline Evolution)

**Purpose**: Time-series analysis of announcement volume and budget trends  
**Refresh**: Daily aggregation

| Column | Type | Meaning |
|--------|------|---------|
| `date_publication` | DATE | Publication date (grouped by day) |
| `nb_announcements` | INT | Number of announcements published that day |
| `nb_sources` | INT | Number of sources contributing that day |
| `avg_amount` | DECIMAL | Average budget that day |
| `nb_regions` | INT | Regions involved that day |
| `generated_at` | DATETIME | View generation timestamp |

---

### 4.3 View: `vw_repartition_geo` (Geographic Distribution)

**Purpose**: Regional breakdown for geographic analysis  
**Refresh**: Real-time or hourly

| Column | Type | Meaning |
|--------|------|---------|
| `region` | VARCHAR | Region name |
| `nb_announcements` | INT | Count of announcements in region |
| `nb_sources` | INT | Number of sources covering region |
| `nb_buyers` | INT | Number of buyers in region |
| `montant_total` | DECIMAL | Total budget in region |
| `montant_moyen` | DECIMAL | Average budget in region |
| `date_premiere` | DATETIME | Earliest announcement |
| `dernier_deadline` | DATETIME | Latest deadline |
| `generated_at` | DATETIME | View generation timestamp |

---

### 4.4 View: `vw_alertes_prioritaires` (Priority Alerts)

**Purpose**: High-priority announcements requiring immediate attention  
**Refresh**: Real-time (critical for operations)

| Column | Type | Meaning |
|--------|------|---------|
| `announcement_id` | BIGINT | Announcement ID |
| `external_id` | VARCHAR | Source reference ID |
| `title` | VARCHAR | Announcement title |
| `estimated_amount` | DECIMAL | Budget |
| `source_name` | VARCHAR | Data source |
| `region` | VARCHAR | Geographic region |
| `publication_date` | DATETIME | Published when |
| `response_deadline` | DATETIME | When to respond |
| `jours_restants` | INT | Days remaining (negative = expired) |
| `days_left` | INT | Days remaining (duplicate for clarity) |
| `niveau_alerte` | VARCHAR | Alert level: CRITIQUE, URGENT, NORMAL, IGNORE |
| `generated_at` | DATETIME | View generation timestamp |

**Alert Logic** (embedded in view):
```
CRITIQUE:  score > 75 AND days_left ≤ 7
URGENT:    score > 75/60 AND days_left ≤ 14
NORMAL:    score > 50
IGNORE:    score ≤ 50 OR days_left < 0
```

---

### 4.5 View: `vw_performance_sources` (Source Performance)

**Purpose**: Data quality and volume metrics per source  
**Refresh**: Hourly

| Column | Type | Meaning |
|--------|------|---------|
| `source_name` | VARCHAR | Source name |
| `nb_announcements` | INT | Total announcements from source |
| `nb_buyers` | INT | Number of unique buyers |
| `nb_regions` | INT | Geographic coverage |
| `montant_moyen` | DECIMAL | Average budget |
| `montant_max` | DECIMAL | Highest budget from source |
| `derniers_7j` | INT | Announcements in last 7 days |
| `derniers_30j` | INT | Announcements in last 30 days |
| `date_premiere_ann` | DATETIME | First announcement date |
| `date_derniere_ann` | DATETIME | Latest announcement date |
| `generated_at` | DATETIME | View generation timestamp |

---

### 4.6 View: `vw_acheteurs_principaux` (Top Buyers)

**Purpose**: Buyer analysis and volume trends  
**Refresh**: Hourly

| Column | Type | Meaning |
|--------|------|---------|
| `buyer_id` | INT | Buyer ID |
| `buyer_name` | VARCHAR | Buyer name |
| `buyer_type` | VARCHAR | Type: COLLECTIVITE, ETAT, ENTREPRISE_PUBLIQUE |
| `region` | VARCHAR | Primary region |
| `nb_announcements` | INT | Total announcements from buyer |
| `nb_sources` | INT | Number of data sources covering buyer |
| `montant_moyen` | DECIMAL | Average budget |
| `montant_total` | DECIMAL | Total budget from buyer |
| `date_premiere` | DATETIME | First announcement date |
| `date_derniere` | DATETIME | Latest announcement date |
| `generated_at` | DATETIME | View generation timestamp |

---

### 4.7 View: `vw_mots_cles_populaires` (Popular Keywords)

**Purpose**: Keyword frequency and value analysis  
**Refresh**: Daily

| Column | Type | Meaning |
|--------|------|---------|
| `keyword_text` | VARCHAR | Keyword text |
| `category` | VARCHAR | Category: PRIMARY, SECONDARY, EXTRACTED |
| `nb_annonces` | INT | Number of announcements mentioning keyword |
| `nb_sources` | INT | Number of sources with keyword |
| `montant_moyen` | DECIMAL | Average budget for announcements with keyword |
| `generated_at` | DATETIME | View generation timestamp |

---

### 4.8 View: `vw_quality_metrics` (Data Quality)

**Purpose**: Data completeness and quality assessment  
**Refresh**: Hourly

| Column | Type | Meaning |
|--------|------|---------|
| `total_announcements` | INT | Total records |
| `valid_titles` | INT | Announcements with valid titles (>5 chars) |
| `valid_descriptions` | INT | Announcements with descriptions (>10 chars) |
| `valid_amounts` | INT | Announcements with amounts (>0) |
| `valid_pub_dates` | INT | Announcements with publication dates |
| `valid_deadlines` | INT | Announcements with response deadlines |
| `valid_regions` | INT | Announcements with region data |
| `unique_rate_percent` | DECIMAL | Percentage of unique external IDs |
| `generated_at` | DATETIME | View generation timestamp |

**Quality Threshold**: All metrics should be >95% for production

---

## 5. Index Strategy

### 5.1 Critical Indexes (Performance-Essential)

| Table | Index | Reason | Selectivity |
|-------|-------|--------|-------------|
| announcements | idx_announcements_response_deadline | Urgency calculation (MOST CRITICAL) | High |
| announcements | idx_announcements_status | Status filtering | Medium |
| announcements | idx_announcements_region_deadline | Geographic + urgency queries | High |
| qualification_scores | idx_qs_alert_level | Alert routing | Medium |
| qualification_scores | idx_qs_alert_score | Combined alert queries | High |

### 5.2 Supporting Indexes

| Table | Index | Reason |
|-------|-------|--------|
| announcements | idx_announcements_source | Source tracking |
| announcements | idx_announcements_buyer | Buyer tracking |
| announcements | idx_announcements_publication_date | Timeline queries |
| announcement_keywords | idx_ank_keyword | Keyword-centric queries |
| notifications | idx_notif_status | Notification routing |
| business_logs | idx_bus_logs_announcement_timestamp | Audit retrieval |
| announcement_history | idx_hist_announcement_timestamp | Version control |

### 5.3 Total Index Count
- **Total Indexes**: 59 (per 03_create_indexes_v2.sql)
- **Critical**: 5
- **Supporting**: 30+
- **Foreign Key**: 8 (implicit)

---

## 6. Data Constraints & Validation

### 6.1 Entity Constraints

| Table | Constraint Type | Details |
|-------|---|---|
| sources | PK | source_id |
| | UNIQUE | source_name |
| | CHECK | source_type IN ('API', 'SCRAPING', 'FLUX_RSS') |
| buyers | PK | buyer_id |
| | UNIQUE | buyer_name |
| | CHECK | buyer_type IN ('COLLECTIVITE', 'ETAT', 'ENTREPRISE_PUBLIQUE') |
| keywords | PK | keyword_id |
| | UNIQUE | keyword_text |
| | CHECK | category IN ('PRIMARY', 'SECONDARY', 'EXTRACTED') |
| announcements | PK | announcement_id |
| | UNIQUE | (source_id, external_id) — No duplicates per source |
| | UNIQUE | source_link — One URL per announcement |
| | CHECK | CHAR_LENGTH(title) > 5 — Min 6 chars |
| | CHECK | estimated_amount >= 0 OR NULL — No negative |
| | CHECK | publication_date <= response_deadline — Logic |
| | FK | source_id → sources |
| | FK | buyer_id → buyers |
| announcement_keywords | PK | (announcement_id, keyword_id) |
| | CHECK | relevance_score BETWEEN 0 AND 100 |
| | FK | announcement_id → announcements (CASCADE) |
| | FK | keyword_id → keywords (RESTRICT) |
| qualification_scores | PK | score_id |
| | UNIQUE | announcement_id — 1:1 relationship |
| | CHECK | pertinence_score BETWEEN 0 AND 100 |
| | FK | announcement_id → announcements (CASCADE) |
| notifications | PK | notification_id |
| | CHECK | priority BETWEEN 1 AND 5 |
| | CHECK | status IN ('NEW', 'SENT', 'ACKNOWLEDGED', 'ARCHIVED') |
| | FK | announcement_id → announcements (CASCADE) |

### 6.2 Referential Integrity

All foreign keys use:
- **ON DELETE**: CASCADE (for derived/audit tables), RESTRICT (for reference tables)
- **ON UPDATE**: CASCADE (always — ensures referential consistency)

---

## 7. Storage & Performance Estimation

### 7.1 Row Size Estimation

| Table | Avg Row Size | Estimated Rows | Est. Storage |
|-------|---|---|---|
| sources | 800 B | 50 | 40 KB |
| buyers | 500 B | 1,000 | 500 KB |
| keywords | 200 B | 300 | 60 KB |
| announcements | 2.5 KB | 100,000 | 250 MB |
| announcement_keywords | 100 B | 500,000 | 50 MB |
| qualification_scores | 500 B | 100,000 | 50 MB |
| notifications | 2 KB | 300,000 | 600 MB |
| technical_logs | 1.5 KB | 1,000,000 | 1.5 GB |
| business_logs | 2.5 KB | 200,000 | 500 MB |
| announcement_history | 800 B | 500,000 | 400 MB |
| backup_logs | 600 B | 5,000 | 3 MB |
| **TOTAL** | — | — | **≈ 4 GB** |

### 7.2 Index Storage

- **Total Indexes**: 59
- **Estimated Storage**: 500 MB - 1 GB
- **Total Database Size**: 4-5 GB

### 7.3 Growth Projections

| Year | Announcements | Notifications | Technical Logs | Total Size |
|------|---|---|---|---|
| Year 1 | 100K | 300K | 1M | 4 GB |
| Year 2 | 500K | 1.5M | 5M | 18 GB |
| Year 3 | 1M | 3M | 10M | 35 GB |

**Scalability**: Database is suitable for growth to Year 2-3 with current schema. Consider archiving old technical_logs after Year 3.

---

## 8. Security & Access Control

### 8.1 Roles & Permissions

| Role | Tables | Operations | Purpose |
|------|--------|-----------|---------|
| data_import | announcements, sources, buyers | INSERT, UPDATE | API data import |
| scorer | qualification_scores | INSERT, UPDATE | Scoring engine |
| analyst | All (read-only) | SELECT | Business analysis |
| admin | All | All | Database administration |
| app_user | announcements, notifications (partial) | SELECT | User interface |

### 8.2 Sensitive Data

| Column | Sensitivity | Protection |
|--------|---|---|
| contact_email (buyers) | Medium | Access via analyst role only |
| contact_phone (buyers) | Medium | Access via analyst role only |
| external_id (announcements) | Low | Public reference IDs |
| All others | Low | Standard access control |

**No highly sensitive data** (passwords, financial details, PII) stored in this schema.

---

## 9. Maintenance & Operations

### 9.1 Backup Strategy

| Frequency | Type | Retention |
|-----------|------|-----------|
| Daily | Full | 7 days |
| Weekly | Full | 4 weeks |
| Monthly | Full | 12 months |
| Hourly | Incremental | 24 hours |

**RTO**: 1 hour  
**RPO**: 1 hour  
**Backup Location**: Separate storage system (not on same server)

### 9.2 Maintenance Tasks

| Task | Frequency | Impact | Command |
|------|-----------|--------|---------|
| ANALYZE tables | Weekly | Low | `ANALYZE TABLE announcements;` |
| OPTIMIZE tables | Monthly | Medium | `OPTIMIZE TABLE announcements;` |
| Purge technical_logs | Weekly | Low | `DELETE FROM technical_logs WHERE timestamp < DATE_SUB(NOW(), INTERVAL 90 DAY);` |
| Update statistics | Daily | Low | `ANALYZE TABLE ...;` |

### 9.3 Monitoring

| Metric | Threshold | Alert |
|--------|-----------|-------|
| Disk usage | >80% | Critical |
| Query time | >5s | Warning |
| Row count (announcements) | >500K | Monitor |
| Replica lag | >10s | Critical |

---

## 10. Migration Notes (MLD → MPD)

### 10.1 Naming Convention Changes

All column names were changed from French (MLD) to English (MPD) for implementation:

**MLD (Documented)** → **MPD (Implemented)**:
- id_annonce → announcement_id
- id_source → source_id
- id_acheteur → buyer_id
- id_mot_cle → keyword_id
- nom_source → source_name
- nom_acheteur → buyer_name
- texte_mot_cle → keyword_text
- titre → title
- description → description (same)
- montant_estime → estimated_amount
- devise → currency
- date_publication → publication_date
- date_limite_reponse → response_deadline
- localisation → location
- region → region (same)
- lien_source → source_link
- statut → status
- timestamp_import → imported_at
- timestamp_maj → updated_at
- score_pertinence → pertinence_score
- niveau_alerte → alert_level
- raison_scoring → scoring_reason
- type_alerte → alert_type
- priorite → priority
- log_technique → technical_logs
- log_metier → business_logs
- historique_annonces → announcement_history
- log_sauvegardes → backup_logs

### 10.2 Structural Changes

| Element | MLD | MPD | Reason |
|---------|-----|-----|--------|
| external_id | Documented | Present | Track source system IDs |
| currency | Documented | Present | Support multi-currency |
| location | Documented | Present | Geographic detail |
| extraction_type | Documented | Present | Keyword tracking method |
| buyer_type | Documented | Present | Buyer categorization |
| backup_logs | Documented | Present | Backup audit trail |
| 8 Dashboard views | Documented | Present | Real-time analytics |

---

## 11. Glossary

| Term | Definition |
|------|-----------|
| **Announcement** | A public market opportunity (project, call for bids) |
| **Source** | Data provider (BOAMP, data.gouv.fr, RSS feed) |
| **Buyer** | Public organization issuing the announcement |
| **Keyword** | Search term for filtering relevant announcements |
| **Score** | Relevance score (0-100) for an announcement |
| **Alert Level** | Priority categorization (CRITIQUE, URGENT, NORMAL, IGNORE) |
| **Qualification** | Process of scoring and categorizing announcements |
| **Notification** | Alert sent to users for qualified announcements |
| **Audit Log** | Record of all system/business changes (compliance) |
| **Soft Delete** | Marking record as deleted without removing from database |
| **Cascade** | Automatic deletion of related records |
| **FK/ForeignKey** | Link between tables ensuring referential integrity |

---

## 12. Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-04-08 | Initial MPD (corrected from MLD) |
| 2.0 | 2026-04-08 | Added 8 dashboard views, storage estimates, glossary |

---

## 13. References

- **Source Code**: `sql/schema/02_create_tables_v2.sql`
- **Indexes**: `sql/schema/03_create_indexes_v2.sql`
- **Views**: `sql/analytics/09_views_dashboard.sql`
- **Stored Procedures**: `sql/logic/06_procedures.sql`
- **Triggers**: `sql/logic/07_triggers.sql`
- **Functions**: `sql/logic/05_functions.sql`

---

**Document Prepared By**: OpenCode Agent  
**Status**: COMPLETE & PRODUCTION-READY  
**Next Step**: Create mapping document (MLD ↔ MPD) and ERD diagram
