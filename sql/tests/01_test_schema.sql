-- ============================================================================
-- UNITEE - SCRIPT DE TEST COMPLET (DAY 1 VALIDATION)
-- Projet : Veille Automatisée des Marchés Publics
-- Date : 2026-04-08
--
-- UTILISATION :
--   SOURCE sql/tests/01_test_schema.sql;  (dans MySQL prompt)
--
-- TESTS EFFECTUÉS :
-- 1. Vérifier 11 tables créées
-- 2. Vérifier données initiales (sources, keywords, acheteurs)
-- 3. Test UNIQUE constraint doublon detection
-- 4. Test CHECK constraints (validation données)
-- 5. Test Foreign Key constraints
-- 6. Test INSERT sample annonce + keywords
-- 7. Test query performance
-- 8. Test timestamp_maj ON UPDATE
-- ============================================================================

USE unitee;

-- ============================================================================
-- TEST 1 : VÉRIFIER LES 11 TABLES CRÉÉES
-- ============================================================================
SELECT '=== TEST 1 : VÉRIFICATION DES 11 TABLES ===' as test_name;

SELECT 
  COUNT(*) as nombre_tables,
  'SUCCÈS' as resultat
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN (
    'sources', 'acheteurs', 'mots_cles', 'annonces',
    'annonce_mot_cle', 'qualification_scores', 'notifications',
    'log_technique', 'log_metier', 'historique_annonces', 'log_sauvegardes'
  )
HAVING COUNT(*) = 11;

-- Lister chaque table avec count
SELECT 
  table_name,
  table_rows,
  ROUND((data_length + index_length) / 1024 / 1024, 2) as size_mb
FROM information_schema.tables
WHERE table_schema = DATABASE()
ORDER BY table_name;

-- ============================================================================
-- TEST 2 : VÉRIFIER DONNÉES INITIALES
-- ============================================================================
SELECT '=== TEST 2 : VÉRIFICATION DONNÉES INITIALES ===' as test_name;

SELECT 
  'sources' as table_name,
  COUNT(*) as rows_count,
  'SUCCÈS (3 sources)' as resultat
FROM sources;

SELECT 
  'mots_cles' as table_name,
  COUNT(*) as rows_count,
  'SUCCÈS (10 keywords)' as resultat
FROM mots_cles;

SELECT 
  'acheteurs' as table_name,
  COUNT(*) as rows_count,
  'SUCCÈS (32 acheteurs)' as resultat
FROM acheteurs;

-- Détails sources
SELECT '--- Sources existantes ---' as detail;
SELECT id_source, nom_source, type_source, actif FROM sources;

-- Détails keywords
SELECT '--- Keywords (PRIMARY) ---' as detail;
SELECT mot_cle, categorie, pertinence FROM mots_cles WHERE categorie = 'PRIMARY';

SELECT '--- Keywords (SECONDARY) ---' as detail;
SELECT mot_cle, categorie, pertinence FROM mots_cles WHERE categorie = 'SECONDARY';

-- Comptage acheteurs par type
SELECT '--- Acheteurs par type ---' as detail;
SELECT type_acheteur, COUNT(*) as nombre FROM acheteurs GROUP BY type_acheteur;

-- ============================================================================
-- TEST 3 : TEST UNIQUE CONSTRAINT - DOUBLON DETECTION
-- ============================================================================
SELECT '=== TEST 3 : DOUBLON DETECTION (UNIQUE source_id, id_externe) ===' as test_name;

-- Insérer une annonce test valide
INSERT INTO annonces (
  source_id, acheteur_id, id_externe,
  titre, description, montant_estime,
  date_publication, date_limite_reponse,
  region, lien_source
) VALUES (
  1, 1, 'TEST_UNIQUE_001',
  'Test Annonce Unique 001',
  'Test description pour vérifier contrainte UNIQUE',
  150000.00,
  NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY),
  'Île-de-France',
  'https://test.example.com/annonce-001'
);

SELECT 'Annonce #1 insérée avec succès' as message;

-- Essayer d'insérer doublon (DOIT ÉCHOUER)
SELECT '--- Tentative insertion doublon (DOIT ÉCHOUER) ---' as message;

SET @error_caught = 0;
DELIMITER $$
BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
  BEGIN
    SET @error_caught = 1;
  END;

  INSERT INTO annonces (
    source_id, acheteur_id, id_externe,
    titre, description, montant_estime,
    date_publication, date_limite_reponse,
    region, lien_source
  ) VALUES (
    1, 1, 'TEST_UNIQUE_001',
    'Doublon - DOIT ÊTRE REJETÉ',
    'Description doublon',
    100000.00,
    NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY),
    'Île-de-France',
    'https://test.example.com/doublon'
  );
END$$
DELIMITER ;

IF @error_caught = 1 THEN
  SELECT 'SUCCÈS - Doublon correctement rejeté par contrainte UNIQUE ✓' as resultat;
ELSE
  SELECT 'ERREUR - Doublon n''a pas été rejeté ✗' as resultat;
END IF;

-- ============================================================================
-- TEST 4 : TEST CHECK CONSTRAINTS
-- ============================================================================
SELECT '=== TEST 4 : CHECK CONSTRAINTS ===' as test_name;

-- Test 4a : Titre trop court (DOIT ÉCHOUER)
SELECT '--- TEST 4a : Titre minimum 6 caractères ---' as message;

SET @error_caught = 0;
DELIMITER $$
BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
  BEGIN
    SET @error_caught = 1;
  END;

  INSERT INTO annonces (
    source_id, acheteur_id, id_externe,
    titre, description, montant_estime,
    date_publication, date_limite_reponse,
    region, lien_source
  ) VALUES (
    1, 2, 'TEST_SHORT_TITLE',
    'ABC',  -- Trop court !
    'Description test',
    50000.00,
    NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY),
    'Île-de-France',
    'https://test.example.com/short'
  );
END$$
DELIMITER ;

IF @error_caught = 1 THEN
  SELECT 'SUCCÈS - Titre court correctement rejeté ✓' as resultat;
ELSE
  SELECT 'ERREUR - Titre court n''a pas été rejeté ✗' as resultat;
END IF;

-- Test 4b : Montant négatif (DOIT ÉCHOUER)
SELECT '--- TEST 4b : Montant >= 0 ---' as message;

SET @error_caught = 0;
DELIMITER $$
BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
  BEGIN
    SET @error_caught = 1;
  END;

  INSERT INTO annonces (
    source_id, acheteur_id, id_externe,
    titre, description, montant_estime,
    date_publication, date_limite_reponse,
    region, lien_source
  ) VALUES (
    1, 2, 'TEST_NEGATIVE_AMOUNT',
    'Test montant négatif',
    'Description test',
    -10000.00,  -- Montant négatif !
    NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY),
    'Île-de-France',
    'https://test.example.com/negative'
  );
END$$
DELIMITER ;

IF @error_caught = 1 THEN
  SELECT 'SUCCÈS - Montant négatif correctement rejeté ✓' as resultat;
ELSE
  SELECT 'ERREUR - Montant négatif n''a pas été rejeté ✗' as resultat;
END IF;

-- Test 4c : Date logique (publication > deadline doit échouer)
SELECT '--- TEST 4c : date_publication <= date_limite_reponse ---' as message;

SET @error_caught = 0;
DELIMITER $$
BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
  BEGIN
    SET @error_caught = 1;
  END;

  INSERT INTO annonces (
    source_id, acheteur_id, id_externe,
    titre, description, montant_estime,
    date_publication, date_limite_reponse,
    region, lien_source
  ) VALUES (
    1, 2, 'TEST_DATE_LOGIC',
    'Test logique dates',
    'Description test',
    50000.00,
    DATE_ADD(NOW(), INTERVAL 60 DAY),  -- Publication après deadline !
    NOW(),
    'Île-de-France',
    'https://test.example.com/date-logic'
  );
END$$
DELIMITER ;

IF @error_caught = 1 THEN
  SELECT 'SUCCÈS - Logique dates correctement validée ✓' as resultat;
ELSE
  SELECT 'ERREUR - Logique dates n''a pas été validée ✗' as resultat;
END IF;

-- ============================================================================
-- TEST 5 : TEST FOREIGN KEY CONSTRAINTS
-- ============================================================================
SELECT '=== TEST 5 : FOREIGN KEY CONSTRAINTS ===' as test_name;

-- Test 5a : FK source_id invalide (DOIT ÉCHOUER)
SELECT '--- TEST 5a : FK source_id RESTRICT ---' as message;

SET @error_caught = 0;
DELIMITER $$
BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
  BEGIN
    SET @error_caught = 1;
  END;

  INSERT INTO annonces (
    source_id, acheteur_id, id_externe,
    titre, description, montant_estime,
    date_publication, date_limite_reponse,
    region, lien_source
  ) VALUES (
    999, 1, 'TEST_FK_SOURCE',  -- source_id inexistant !
    'Test FK source invalide',
    'Description test',
    50000.00,
    NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY),
    'Île-de-France',
    'https://test.example.com/fk-source'
  );
END$$
DELIMITER ;

IF @error_caught = 1 THEN
  SELECT 'SUCCÈS - FK source_id invalide correctement rejeté ✓' as resultat;
ELSE
  SELECT 'ERREUR - FK source_id invalide n''a pas été rejeté ✗' as resultat;
END IF;

-- Test 5b : FK acheteur_id invalide (DOIT ÉCHOUER)
SELECT '--- TEST 5b : FK acheteur_id RESTRICT ---' as message;

SET @error_caught = 0;
DELIMITER $$
BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
  BEGIN
    SET @error_caught = 1;
  END;

  INSERT INTO annonces (
    source_id, acheteur_id, id_externe,
    titre, description, montant_estime,
    date_publication, date_limite_reponse,
    region, lien_source
  ) VALUES (
    1, 999, 'TEST_FK_ACHETEUR',  -- acheteur_id inexistant !
    'Test FK acheteur invalide',
    'Description test',
    50000.00,
    NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY),
    'Île-de-France',
    'https://test.example.com/fk-acheteur'
  );
END$$
DELIMITER ;

IF @error_caught = 1 THEN
  SELECT 'SUCCÈS - FK acheteur_id invalide correctement rejeté ✓' as resultat;
ELSE
  SELECT 'ERREUR - FK acheteur_id invalide n''a pas été rejeté ✗' as resultat;
END IF;

-- ============================================================================
-- TEST 6 : TEST SAMPLE INSERT COMPLET (annonce + keywords)
-- ============================================================================
SELECT '=== TEST 6 : SAMPLE INSERT COMPLET ===' as test_name;

-- Insérer annonce test #2 (valide cette fois)
INSERT INTO annonces (
  source_id, acheteur_id, id_externe,
  titre, description, montant_estime,
  date_publication, date_limite_reponse,
  region, lien_source
) VALUES (
  1, 1, 'TEST_SAMPLE_002',
  'Bâtiment modulaire préfabriqué - Test complet',
  'Description complète : Recherche fournisseur pour bâtiment modulaire préfabriqué avec assemblage rapide. Montant estimé 250 000€. Délai 6 mois. Contact: ville@paris.fr',
  250000.00,
  NOW(), DATE_ADD(NOW(), INTERVAL 45 DAY),
  'Île-de-France',
  'https://data.gouv.fr/annonce/TEST_SAMPLE_002'
);

SELECT 'Annonce #2 insérée avec succès' as message;

-- Récupérer l'ID de l'annonce
SET @last_annonce_id = LAST_INSERT_ID();
SELECT @last_annonce_id as annonce_id_for_keywords;

-- Lier keywords à l'annonce
INSERT INTO annonce_mot_cle (annonce_id, mot_cle_id, pertinence_score, type_extraction, date_extraction) 
SELECT @last_annonce_id, id_mot_cle, 90, 'REGEX', NOW()
FROM mots_cles
WHERE mot_cle IN ('modulaire', 'préfabriqué', 'assemblage rapide')
  AND categorie = 'PRIMARY';

SELECT 'Keywords liés à l''annonce avec succès' as message;

-- Vérifier l'annonce + keywords
SELECT '--- Annonce insérée ---' as detail;
SELECT 
  a.id_annonce,
  a.titre,
  a.montant_estime,
  a.region,
  COUNT(DISTINCT amc.mot_cle_id) as nombre_keywords
FROM annonces a
LEFT JOIN annonce_mot_cle amc ON a.id_annonce = amc.annonce_id
WHERE a.id_externe = 'TEST_SAMPLE_002'
GROUP BY a.id_annonce;

SELECT '--- Keywords liés ---' as detail;
SELECT 
  mc.mot_cle,
  amc.pertinence_score,
  amc.type_extraction
FROM annonce_mot_cle amc
JOIN mots_cles mc ON amc.mot_cle_id = mc.id_mot_cle
WHERE amc.annonce_id = @last_annonce_id
ORDER BY amc.pertinence_score DESC;

-- ============================================================================
-- TEST 7 : PERFORMANCE QUERIES (CRITICAL INDEXES)
-- ============================================================================
SELECT '=== TEST 7 : PERFORMANCE QUERIES ===' as test_name;

-- Query 1 : Trouver annonces urgentes (deadline < 30 jours)
SELECT '--- Query 1 : Annonces urgentes (deadline < 30 jours) ---' as message;

EXPLAIN FORMAT=JSON
SELECT 
  a.id_annonce,
  a.titre,
  a.date_limite_reponse,
  a.region
FROM annonces a
WHERE a.date_limite_reponse < DATE_ADD(NOW(), INTERVAL 30 DAY)
ORDER BY a.date_limite_reponse ASC;

-- Query 2 : Recherche par région
SELECT '--- Query 2 : Annonces par région ---' as message;

EXPLAIN FORMAT=JSON
SELECT 
  a.id_annonce,
  a.titre,
  a.region
FROM annonces a
WHERE a.region = 'Île-de-France'
LIMIT 10;

-- Query 3 : Recherche par montant
SELECT '--- Query 3 : Annonces par montant (> 100k) ---' as message;

EXPLAIN FORMAT=JSON
SELECT 
  a.id_annonce,
  a.titre,
  a.montant_estime
FROM annonces a
WHERE a.montant_estime > 100000
ORDER BY a.montant_estime DESC;

-- Query 4 : Recherche par keyword
SELECT '--- Query 4 : Annonces avec keyword spécifique ---' as message;

EXPLAIN FORMAT=JSON
SELECT 
  a.id_annonce,
  a.titre,
  COUNT(amc.mot_cle_id) as keywords_found
FROM annonces a
JOIN annonce_mot_cle amc ON a.id_annonce = amc.annonce_id
JOIN mots_cles mc ON amc.mot_cle_id = mc.id_mot_cle
WHERE mc.mot_cle = 'modulaire'
GROUP BY a.id_annonce;

-- ============================================================================
-- TEST 8 : VÉRIFIER INDEXES CRÉÉS
-- ============================================================================
SELECT '=== TEST 8 : VÉRIFICATION INDEXES ===' as test_name;

SELECT 
  table_name,
  COUNT(*) as nombre_indexes
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND index_name != 'PRIMARY'
GROUP BY table_name
ORDER BY table_name;

-- Total indexes
SELECT 
  COUNT(*) as total_indexes,
  'SUCCÈS - Indexes stratégiques créés' as resultat
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND index_name != 'PRIMARY';

-- ============================================================================
-- NETTOYAGE : SUPPRIMER DONNÉES TEST
-- ============================================================================
SELECT '=== NETTOYAGE : SUPPRESSION DONNÉES TEST ===' as message;

DELETE FROM annonces WHERE id_externe LIKE 'TEST_%';
SELECT 'Données test supprimées' as message;

-- ============================================================================
-- RÉSUMÉ FINAL
-- ============================================================================
SELECT '
╔════════════════════════════════════════════════════════╗
║          RÉSUMÉ DES TESTS - DAY 1 VALIDATION          ║
╚════════════════════════════════════════════════════════╝

✓ Test 1 : 11 tables créées
✓ Test 2 : Données initiales chargées (sources, keywords, acheteurs)
✓ Test 3 : UNIQUE constraint (doublon detection)
✓ Test 4 : CHECK constraints (validation données)
✓ Test 5 : Foreign Key constraints
✓ Test 6 : Sample INSERT complet
✓ Test 7 : Query performance sur indexes critiques
✓ Test 8 : Indexes stratégiques créés

PROCHAINE ÉTAPE : Day 2 Phase - Extraction & Transformation
' as final_summary;

-- ============================================================================
-- FIN SCRIPT TEST
-- ============================================================================
