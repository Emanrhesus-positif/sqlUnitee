-- ============================================================================
-- UNITEE - COMPREHENSIVE SCHEMA TESTS (V2)
-- Date: 2026-04-08
-- Version: 2.0
-- 
-- This script validates the complete schema setup
-- ============================================================================

USE unitee;

-- ============================================================================
-- TEST 1: VERIFY ALL 11 TABLES EXIST
-- ============================================================================

SELECT '=== TEST 1: TABLE EXISTENCE ===' as test_name;

SELECT 
  CASE 
    WHEN COUNT(*) = 11 THEN 'PASS'
    ELSE 'FAIL'
  END as result,
  COUNT(*) as table_count
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN (
    'sources', 'buyers', 'keywords', 'announcements',
    'announcement_keywords', 'qualification_scores', 'notifications',
    'technical_logs', 'business_logs', 'announcement_history', 'backup_logs'
  );

-- List all tables with row counts
SELECT 
  TABLE_NAME,
  TABLE_ROWS,
  ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) as size_mb
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_type = 'BASE TABLE'
ORDER BY TABLE_NAME;

-- ============================================================================
-- TEST 2: VERIFY INITIAL DATA
-- ============================================================================

SELECT '' as blank;
SELECT '=== TEST 2: INITIAL DATA VERIFICATION ===' as test_name;

-- Sources check
SELECT 
  'sources' as table_name,
  COUNT(*) as rows_count,
  CASE 
    WHEN COUNT(*) = 3 THEN 'PASS - 3 sources loaded'
    ELSE 'FAIL'
  END as result
FROM sources;

-- Keywords check
SELECT 
  'keywords' as table_name,
  COUNT(*) as rows_count,
  CASE 
    WHEN COUNT(*) = 10 THEN 'PASS - 10 keywords loaded'
    ELSE 'FAIL'
  END as result
FROM keywords;

-- Buyers check
SELECT 
  'buyers' as table_name,
  COUNT(*) as rows_count,
  CASE 
    WHEN COUNT(*) >= 28 THEN 'PASS - 28+ buyers loaded'
    ELSE 'FAIL'
  END as result
FROM buyers;

-- Show sources
SELECT '' as blank;
SELECT '--- Sources ---' as detail;
SELECT source_id, source_name, source_type, active FROM sources;

-- Show keywords by category
SELECT '' as blank;
SELECT '--- Keywords (PRIMARY) ---' as detail;
SELECT keyword_id, keyword_text, category FROM keywords WHERE category = 'PRIMARY';

SELECT '' as blank;
SELECT '--- Keywords (SECONDARY) ---' as detail;
SELECT keyword_id, keyword_text, category FROM keywords WHERE category = 'SECONDARY';

-- Show buyers by type
SELECT '' as blank;
SELECT '--- Buyers by Type ---' as detail;
SELECT buyer_type, COUNT(*) as count FROM buyers GROUP BY buyer_type ORDER BY count DESC;

-- ============================================================================
-- TEST 3: VERIFY CONSTRAINTS
-- ============================================================================

SELECT '' as blank;
SELECT '=== TEST 3: CONSTRAINT VALIDATION ===' as test_name;

-- Test UNIQUE constraint (source_id, external_id)
SELECT '' as blank;
SELECT '--- Testing UNIQUE (source_id, external_id) constraint ---' as detail;

-- Insert test announcement
INSERT INTO announcements (
  source_id, buyer_id, external_id, title, 
  publication_date, response_deadline
) VALUES (
  1, 1, 'TEST_EXT_001', 'Test Announcement for Constraint Validation',
  NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY)
);

SELECT 'Announcement #1 inserted successfully' as message;

-- Try to insert duplicate (should fail)
SELECT '--- Attempting duplicate (should FAIL) ---' as detail;
INSERT INTO announcements (
  source_id, buyer_id, external_id, title, 
  publication_date, response_deadline
) VALUES (
  1, 1, 'TEST_EXT_001', 'Duplicate Announcement',
  NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY)
);

SELECT 'ERROR: Duplicate was inserted (constraint failed!)' as message;

-- ============================================================================
-- TEST 4: FOREIGN KEY CONSTRAINTS
-- ============================================================================

SELECT '' as blank;
SELECT '=== TEST 4: FOREIGN KEY VALIDATION ===' as test_name;

-- Test FK: buyer_id must exist
SELECT '--- Testing FK: buyer_id ---' as detail;
INSERT INTO announcements (
  source_id, buyer_id, external_id, title, 
  publication_date, response_deadline
) VALUES (
  1, 99999, 'TEST_FK_001', 'Test FK Constraint',
  NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY)
);

SELECT 'ERROR: Foreign key constraint was violated!' as message;

-- ============================================================================
-- TEST 5: CHECK CONSTRAINTS
-- ============================================================================

SELECT '' as blank;
SELECT '=== TEST 5: CHECK CONSTRAINT VALIDATION ===' as test_name;

-- Test CHECK: title length > 5
SELECT '--- Testing CHECK: title length > 5 ---' as detail;
INSERT INTO announcements (
  source_id, buyer_id, external_id, title, 
  publication_date, response_deadline
) VALUES (
  1, 1, 'TEST_CHK_001', 'Bad',
  NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY)
);

SELECT 'ERROR: Title length constraint was violated!' as message;

-- ============================================================================
-- TEST 6: QUERY PERFORMANCE
-- ============================================================================

SELECT '' as blank;
SELECT '=== TEST 6: SAMPLE QUERIES ===' as test_name;

-- Count indexes
SELECT 
  'Total indexes created: ' as metric,
  COUNT(*) as count
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND index_name != 'PRIMARY';

-- Sample: Find announcements by deadline
SELECT '' as blank;
SELECT '--- Find announcements with deadline in next 30 days ---' as detail;
SELECT 
  announcement_id, 
  title, 
  response_deadline,
  DATEDIFF(response_deadline, NOW()) as days_until_deadline
FROM announcements
WHERE response_deadline BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL 30 DAY)
ORDER BY response_deadline ASC;

-- Sample: Find announcements by region
SELECT '' as blank;
SELECT '--- Announcements by region (if any) ---' as detail;
SELECT 
  region,
  COUNT(*) as count
FROM announcements
WHERE region IS NOT NULL
GROUP BY region
ORDER BY count DESC;

-- ============================================================================
-- TEST 7: SCHEMA RELATIONSHIPS
-- ============================================================================

SELECT '' as blank;
SELECT '=== TEST 7: RELATIONSHIP VALIDATION ===' as test_name;

-- Check if test announcement exists
SELECT '' as blank;
SELECT '--- Verification: Test announcement details ---' as detail;
SELECT 
  a.announcement_id,
  a.title,
  s.source_name,
  b.buyer_name,
  a.status,
  a.imported_at
FROM announcements a
JOIN sources s ON a.source_id = s.source_id
JOIN buyers b ON a.buyer_id = b.buyer_id
WHERE a.external_id = 'TEST_EXT_001'
LIMIT 1;

-- ============================================================================
-- FINAL SUMMARY
-- ============================================================================

SELECT '' as blank;
SELECT '=== FINAL SUMMARY ===' as test_name;
SELECT 'All critical tests completed' as message;
SELECT 'Check ERROR messages above for any constraint violations' as warning;

-- ============================================================================
-- END OF SCRIPT
-- ============================================================================
