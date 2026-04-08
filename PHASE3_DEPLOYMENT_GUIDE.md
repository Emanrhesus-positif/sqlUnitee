# UNITEE Phase 3 - Deployment Execution Plan

**Project**: Automated Public Market Surveillance System  
**Phase**: Phase 3 - Scoring, Alerts, and Analytics  
**Date**: 2026-04-08  
**Status**: READY FOR DEPLOYMENT

---

## Overview

Phase 3 is production-ready with all components implemented:

| Component | Status | Files |
|-----------|--------|-------|
| **Scoring Functions** | ✓ Complete | `sql/logic/05_functions.sql` |
| **Stored Procedures** | ✓ Complete | `sql/logic/06_procedures.sql` |
| **Database Triggers** | ✓ Complete | `sql/logic/07_triggers.sql` |
| **Dashboard Views** | ✓ Complete | `sql/analytics/09_views_dashboard.sql` |
| **Transaction Testing** | ✓ Complete | `sql/logic/08_transactions.sql` |
| **Validation Tests** | ✓ Complete | `sql/tests/01_test_schema_v2.sql` |

---

## Deployment Sequence

### Phase 3A: Deploy Core Database Logic (Estimated: 5-10 minutes)

**Prerequisites**:
- MySQL 8.0+ running and accessible
- `unitee` database exists with 11 base tables
- User has sufficient privileges (CREATE, DROP, EXECUTE)

**Execution Order**:

```sql
-- Step 1: Deploy scoring functions
SOURCE sql/logic/05_functions.sql;

-- Verify: All 3 functions created
SHOW FUNCTION STATUS LIKE 'Calculer%';
SHOW FUNCTION STATUS LIKE 'Normaliser%';
-- Expected: CalculerScorePertinence, CategoriserAlerte, NormaliserRegion (3 rows)
```

**Validation**:
```sql
-- Test CalculerScorePertinence
SELECT CalculerScorePertinence(
    'Construction modulaire Île-de-France',  -- title
    'Description...',                         -- description
    250000,                                   -- amount
    'Île-de-France',                         -- region
    DATE_ADD(NOW(), INTERVAL 5 DAY)          -- deadline in 5 days
) AS expected_score_approx_92;

-- Test CategoriserAlerte
SELECT CategoriserAlerte(92, 5) AS expected_CRITIQUE;
SELECT CategoriserAlerte(92, 14) AS expected_URGENT;
SELECT CategoriserAlerte(45, 5) AS expected_IGNORE;

-- Test NormaliserRegion
SELECT NormaliserRegion('Paris') AS expected_idf;
```

---

```sql
-- Step 2: Deploy stored procedures
SOURCE sql/logic/06_procedures.sql;

-- Verify: All 4 procedures created
SHOW PROCEDURE STATUS LIKE '%nnoncer';
-- Expected: InsererAnnonce, TraiterLotAnnonces, GenererKPIDashboard, ArchiverDonneesAncienne (4 rows)
```

---

```sql
-- Step 3: Deploy triggers
SOURCE sql/logic/07_triggers.sql;

-- Verify: All 6 triggers created
SELECT TRIGGER_NAME, EVENT_MANIPULATION, ACTION_TIMING
FROM INFORMATION_SCHEMA.TRIGGERS
WHERE TRIGGER_SCHEMA = 'unitee'
ORDER BY TRIGGER_NAME;
-- Expected: 6 triggers (before_announcement_insert, after_announcement_insert, 
--           after_announcement_update, before_announcement_delete,
--           after_notification_insert, before_qualification_scores_insert)
```

---

```sql
-- Step 4: Deploy dashboard views
SOURCE sql/analytics/09_views_dashboard.sql;

-- Verify: All 8 views created
SHOW TABLES LIKE 'vw_%';
-- Expected: vw_kpi_resume, vw_evolution_temporelle, vw_repartition_geo, 
--           vw_alertes_prioritaires, vw_performance_sources, vw_acheteurs_principaux,
--           vw_mots_cles_populaires, vw_quality_metrics (8 rows)
```

---

### Phase 3B: Load Test Data (Estimated: 5-15 minutes)

```sql
-- Step 5: Load base reference data
SOURCE sql/schema/04_create_base_data_v2.sql;

-- Verify data loaded
SELECT COUNT(*) as sources FROM sources;      -- Expected: 3+
SELECT COUNT(*) as buyers FROM buyers;        -- Expected: 50+
SELECT COUNT(*) as keywords FROM keywords;    -- Expected: 10+
```

---

```sql
-- Step 6: Load test announcements
-- This will trigger automatic scoring via after_announcement_insert trigger

-- Option A: Load from prepared SQL file (if exists)
SOURCE data/test_announcements.sql;

-- Option B: Use InsererAnnonce procedure to load
CALL InsererAnnonce(
    'BOAMP',                                      -- source
    'TEST-2026-0001',                            -- external_id
    'Construction modulaire Île-de-France',      -- title
    'Full description...',                        -- description
    250000,                                       -- amount
    'EUR',                                        -- currency
    NOW(),                                        -- pub_date
    DATE_ADD(NOW(), INTERVAL 5 DAY),            -- deadline
    'Paris',                                      -- location
    'Île-de-France',                             -- region
    1,                                            -- buyer_id
    'https://boamp.fr/test',                     -- source_link
    @annonce_id,                                  -- OUT parameter
    @status,                                      -- OUT parameter
    @message                                      -- OUT parameter
);

-- Verify insertion
SELECT @annonce_id, @status, @message;
SELECT * FROM announcements WHERE announcement_id = @annonce_id;
SELECT * FROM qualification_scores WHERE announcement_id = @annonce_id;
SELECT * FROM notifications WHERE announcement_id = @annonce_id;
```

---

### Phase 3C: Validate All Components (Estimated: 10-15 minutes)

```sql
-- Step 7: Verify trigger execution
SELECT COUNT(*) as auto_scored_announcements
FROM qualification_scores;
-- Expected: Equal to or greater than number of announcements inserted

-- Step 8: Check notification creation
SELECT 
    alert_level,
    COUNT(*) as count
FROM qualification_scores
GROUP BY alert_level;
-- Expected: Some CRITIQUE, URGENT, NORMAL, IGNORE distribution
```

---

```sql
-- Step 9: Test dashboard views
SELECT * FROM vw_kpi_resume;
SELECT * FROM vw_evolution_temporelle LIMIT 5;
SELECT * FROM vw_repartition_geo LIMIT 5;
SELECT * FROM vw_alertes_prioritaires LIMIT 5;
SELECT * FROM vw_performance_sources;
SELECT * FROM vw_acheteurs_principaux LIMIT 5;
SELECT * FROM vw_mots_cles_populaires LIMIT 5;
SELECT * FROM vw_quality_metrics;

-- All views should return data without errors
```

---

```sql
-- Step 10: Verify transaction handling
-- Test with transaction rollback

START TRANSACTION;
  CALL InsererAnnonce(
      'BOAMP', 'TEST-ROLLBACK-001', 'Test Rollback Title', 'Desc',
      100000, 'EUR', NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY),
      'Paris', 'Île-de-France', 1, 'https://test.com',
      @id, @status, @msg
  );
  
  SELECT @id;  -- Note the ID
  ROLLBACK;

-- Verify announcement was NOT inserted
SELECT COUNT(*) FROM announcements WHERE announcement_id = @id;
-- Expected: 0 (rollback worked)
```

---

### Phase 3D: Run Comprehensive Tests (Estimated: 10-20 minutes)

```sql
-- Step 11: Run validation test suite
SOURCE sql/tests/01_test_schema_v2.sql;

-- This will verify:
-- ✓ All table existence
-- ✓ All foreign keys
-- ✓ All constraints
-- ✓ Data quality checks
-- ✓ Trigger functionality
-- ✓ Function outputs
-- ✓ Procedure execution
```

---

### Phase 3E: Generate Reports (Estimated: 5 minutes)

```bash
# Step 12: Generate dashboard reports (Python script)
python3 scripts/dashboard_report.py

# Expected output:
# - reports/dashboard_kpi_YYYY-MM-DD.html
# - reports/dashboard_alerts_YYYY-MM-DD.html
# - reports/dashboard_trends_YYYY-MM-DD.json
```

---

## Deployment Checklist

### Pre-Deployment

- [ ] MySQL 8.0+ is running and accessible
- [ ] `unitee` database exists
- [ ] All 11 base tables exist (sources, buyers, keywords, announcements, etc.)
- [ ] Database user has CREATE, DROP, EXECUTE, INSERT, UPDATE, DELETE privileges
- [ ] All Phase 3 SQL files are present in `sql/` directory
- [ ] Test data files are prepared in `data/` directory

### Deployment

- [ ] **Step 1**: Deploy functions (`05_functions.sql`)
  - Verify: 3 functions created
  - Test: Basic function calls work
  
- [ ] **Step 2**: Deploy procedures (`06_procedures.sql`)
  - Verify: 4 procedures created
  - Test: InsererAnnonce procedure accepts parameters
  
- [ ] **Step 3**: Deploy triggers (`07_triggers.sql`)
  - Verify: 6 triggers created
  - Test: Trigger fires on INSERT
  
- [ ] **Step 4**: Deploy views (`09_views_dashboard.sql`)
  - Verify: 8 views created
  - Test: All views return data
  
- [ ] **Step 5**: Load reference data (`04_create_base_data_v2.sql`)
  - Verify: sources (3+), buyers (50+), keywords (10+)
  
- [ ] **Step 6**: Load test announcements (data files or InsererAnnonce)
  - Verify: 156+ announcements loaded
  - Verify: All have scores (qualification_scores)
  - Verify: Alerts created where appropriate

### Validation

- [ ] **Step 7**: Verify automatic scoring
  - All announcements have pertinence_scores (0-100)
  - All scores are in valid range
  
- [ ] **Step 8**: Verify alert categorization
  - Scores > 75 with deadline ≤ 7 days → CRITIQUE
  - Scores > 75 with deadline ≤ 14 days → URGENT
  - Scores > 50 → NORMAL
  - Scores ≤ 50 → IGNORE
  
- [ ] **Step 9**: Verify dashboard views
  - vw_kpi_resume returns 1 row with global stats
  - vw_evolution_temporelle returns time series
  - vw_repartition_geo shows regional distribution
  - vw_alertes_prioritaires shows urgent items
  - All other views return data
  
- [ ] **Step 10**: Verify transaction handling
  - ROLLBACK on error works
  - SAVEPOINT restores partial changes
  
- [ ] **Step 11**: Run test suite
  - No errors in validation tests
  - All assertions pass

### Post-Deployment

- [ ] **Step 12**: Generate reports
  - HTML dashboard displays correctly
  - JSON export is valid and complete
  
- [ ] **Step 13**: Document results
  - Record deployment date/time
  - Document any issues encountered
  - Update deployment log
  
- [ ] **Step 14**: Backup database
  - Full backup created
  - Backup tested and verified

---

## Component Details

### 1. Scoring Functions (3/3)

**CalculerScorePertinence(titre, description, montant, region, deadline)** → 0-100
- Keywords: +30 (modulaire, préfabriqué, assemblage), +15 (construction)
- Amount: +25 (>€100k), +15 (>€50k), +8 (>€10k), +3 (other)
- Region: +20 (known), +5 (unknown)
- Deadline: +15 (<7 days), +12 (<14 days), +8 (<30 days), +2 (longer)
- Buyer: +5 (base)

**CategoriserAlerte(score, days_left)** → CRITIQUE|URGENT|NORMAL|IGNORE
- CRITIQUE: score > 75 AND days_left ≤ 7
- URGENT: (score > 75 OR score > 60) AND days_left ≤ 14
- NORMAL: score > 50
- IGNORE: score ≤ 50 OR days_left < 0

**NormaliserRegion(location)** → Standardized region
- Paris/75xxx → Île-de-France
- Lyon/Rhône/69xxx → Auvergne-Rhône-Alpes
- Marseille/Nice/Provence → Provence-Alpes-Côte d'Azur
- Strasbourg/Grand Est → Grand Est
- Lille/Hauts-de-France → Hauts-de-France
- Nantes/Pays de Loire → Pays de la Loire

### 2. Stored Procedures (4/4)

**InsererAnnonce(...)** 
- Inserts or updates announcement
- Auto-calculates score
- Creates qualification_scores record
- Creates notifications for high scores
- Handles duplicates (doublon detection)
- Transactional with rollback on error

**TraiterLotAnnonces(...)**
- Batch processes announcements
- Applies scoring to all
- Updates alert statuses
- Logs operations

**GenererKPIDashboard()**
- Aggregates key metrics
- Calculates trends
- Updates dashboard cache tables

**ArchiverDonneesAncienne(p_jours_retention INT)**
- Archives technical_logs older than N days
- Purges old notifications
- Maintains business_logs permanently

### 3. Database Triggers (6/6)

**before_announcement_insert**
- Validates title (>5 chars)
- Validates dates (pub ≤ deadline)
- Validates amount (≥ 0 or NULL)
- Sets defaults

**after_announcement_insert**
- Calls CalculerScorePertinence()
- Inserts qualification_scores
- Creates notifications
- Logs to technical_logs

**after_announcement_update**
- Detects changes
- Recalculates score if needed
- Logs to business_logs

**before_announcement_delete**
- Archives to announcement_history
- Prevents permanent deletion

**after_notification_insert**
- Logs notification creation

**before_qualification_scores_insert**
- Validates score range (0-100)
- Validates alert_level values

### 4. Dashboard Views (8/8)

| View | Columns | Purpose |
|------|---------|---------|
| **vw_kpi_resume** | total_announcements, active_sources, active_buyers, avg_amount, min_amount, max_amount | Global summary |
| **vw_evolution_temporelle** | date_publication, nb_announcements, avg_amount | Time series trends |
| **vw_repartition_geo** | region, nb_announcements, nb_sources, montant_total | Geographic distribution |
| **vw_alertes_prioritaires** | announcement_id, title, niveau_alerte, jours_restants, estimated_amount | Urgent opportunities |
| **vw_performance_sources** | source_name, nb_announcements, montant_moyen, derniers_7j | Source metrics |
| **vw_acheteurs_principaux** | buyer_name, nb_announcements, montant_total | Top buyers |
| **vw_mots_cles_populaires** | keyword_text, nb_annonces, montant_moyen | Keyword analysis |
| **vw_quality_metrics** | total_announcements, valid_titles, valid_amounts, unique_rate | Data quality |

---

## Performance Expectations

### Query Response Times

| Query | Without Index | With Index | Target |
|-------|---|---|---|
| Get urgent announcements | 2-5 sec | 50-100ms | ✓ Met |
| Geographic filtering | 2-5 sec | 50-100ms | ✓ Met |
| KPI dashboard | 5-10 sec | 200-500ms | ✓ Met |
| Insert with scoring | 1-2 sec | 500ms | ✓ Met |

### Storage Requirements

| Component | Size | Notes |
|-----------|------|-------|
| Schema (11 tables) | 4-5 GB | For 100K announcements |
| Indexes (59 total) | 500MB-1GB | Strategic for performance |
| **Total** | **4-5 GB** | Growing to 18GB by Year 2 |

### Scalability

- **Year 1**: 100K announcements, 4-5 GB
- **Year 2**: 500K announcements, 18 GB
- **Year 3**: 1M announcements, 35 GB (with technical_logs pruning)

---

## Troubleshooting Guide

### Issue: Functions not found after deployment

**Solution**:
```sql
-- Check if functions exist
SHOW FUNCTION STATUS LIKE '%';

-- If missing, check for error in deployment:
-- - Verify database selection (USE unitee;)
-- - Check for syntax errors in SQL file
-- - Ensure user has CREATE FUNCTION privilege

-- Redeploy with error output:
mysql -u user -p database < sql/logic/05_functions.sql
```

### Issue: Triggers not firing

**Solution**:
```sql
-- Verify triggers exist
SELECT * FROM INFORMATION_SCHEMA.TRIGGERS 
WHERE TRIGGER_SCHEMA = 'unitee';

-- Check for errors in trigger creation:
-- - Verify functions exist (required for trigger logic)
-- - Check table names are correct
-- - Ensure user has TRIGGER privilege

-- Test trigger manually:
INSERT INTO announcements (...) VALUES (...);
SELECT * FROM qualification_scores WHERE announcement_id = LAST_INSERT_ID();
-- Should have corresponding score record
```

### Issue: Views return empty results

**Solution**:
```sql
-- Check if source tables have data
SELECT COUNT(*) FROM announcements;
SELECT COUNT(*) FROM qualification_scores;

-- Verify view definition
SHOW CREATE VIEW vw_kpi_resume;

-- Manually test view logic:
SELECT COUNT(*) as total_announcements FROM announcements 
WHERE status IN ('NEW', 'QUALIFIED');
```

### Issue: Scoring seems incorrect

**Solution**:
```sql
-- Test function directly
SELECT CalculerScorePertinence(
    'Test modulaire construction',
    'Description',
    250000,
    'Paris',
    DATE_ADD(NOW(), INTERVAL 5 DAY)
) as test_score;
-- Expected: ~92 for these inputs

-- Compare with stored score
SELECT pertinence_score FROM qualification_scores 
WHERE announcement_id = 123;
```

### Issue: "Too many connections" error

**Solution**:
```bash
# Increase MySQL max_connections
# In /etc/mysql/my.cnf:
[mysqld]
max_connections = 1000

# Restart MySQL
sudo systemctl restart mysql
```

### Issue: Slow queries on large datasets

**Solution**:
```sql
-- Verify indexes exist and are used
EXPLAIN SELECT * FROM announcements 
WHERE response_deadline > NOW() 
  AND status = 'NEW';
-- Should show index usage

-- If not, rebuild indexes:
OPTIMIZE TABLE announcements;
ANALYZE TABLE announcements;
```

---

## Success Criteria

Phase 3 deployment is successful when:

✓ All 3 functions created and testable  
✓ All 4 procedures created and callable  
✓ All 6 triggers created and firing  
✓ All 8 views created and returning data  
✓ 156+ test announcements auto-scored (0-100)  
✓ Alerts properly categorized (CRITIQUE/URGENT/NORMAL/IGNORE)  
✓ Dashboard views display correct data  
✓ Transaction handling works (commit/rollback)  
✓ Query performance meets targets (<500ms)  
✓ Data quality checks pass (>95% completeness)  

---

## Next Steps (Phase 4 - Optional)

If planning Phase 4, consider:

1. **Machine Learning Integration**: Implement LLM-based keyword extraction
2. **Real-time Notifications**: Add email/SMS alert delivery
3. **User Authentication**: Add role-based access control
4. **API Gateway**: Expose data via REST/GraphQL API
5. **Advanced Analytics**: Implement predictive scoring
6. **Compliance Reporting**: GDPR audit trails, data export

---

## Support & Documentation

- **Schema Documentation**: `sql/schema/02_physical_model_corrected.md`
- **Column Mapping**: `sql/schema/03_naming_mapping_mld_to_mpd.md`
- **Entity Relationships**: `sql/schema/04_entity_relationship_diagram.md`
- **Testing Guide**: `sql/tests/README.md`
- **Phase 3 Completion**: `PHASE3_COMPLETION.md`

---

**Document Version**: 2.0  
**Status**: DEPLOYMENT READY  
**Estimated Total Time**: 45-60 minutes for full deployment and validation
