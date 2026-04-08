-- ============================================================================
-- UNITEE - TESTS DU SCHÉMA COMPLET
-- Fichier : 01_test_schema.sql
-- Objet   : Valider la création des 11 tables, les données initiales,
--            les contraintes et les relations
--
-- Noms de tables conformes à 02_create_tables.sql :
--   sources, acheteurs, mots_cles, annonces, annonce_mot_cle,
--   qualification_scores, notifications, log_technique,
--   log_metier, historique_annonces, log_sauvegardes
-- ============================================================================

USE unitee;

-- ============================================================================
-- TEST 1 : EXISTENCE DES 11 TABLES
-- ============================================================================

SELECT '=== TEST 1 : EXISTENCE DES TABLES ===' AS test_name;

SELECT
    CASE
        WHEN COUNT(*) = 11 THEN 'PASS — 11 tables présentes'
        ELSE CONCAT('FAIL — ', COUNT(*), '/11 tables trouvées')
    END AS resultat,
    COUNT(*) AS nb_tables
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN (
    'sources', 'acheteurs', 'mots_cles', 'annonces',
    'annonce_mot_cle', 'qualification_scores', 'notifications',
    'log_technique', 'log_metier', 'historique_annonces', 'log_sauvegardes'
  );

-- Liste toutes les tables avec taille
SELECT
    TABLE_NAME           AS table_name,
    TABLE_ROWS           AS lignes_approx,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 3) AS taille_mo
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_type = 'BASE TABLE'
ORDER BY TABLE_NAME;

-- ============================================================================
-- TEST 2 : DONNÉES INITIALES
-- ============================================================================

SELECT '' AS sep;
SELECT '=== TEST 2 : DONNÉES INITIALES ===' AS test_name;

-- Sources
SELECT
    'sources' AS table_name,
    COUNT(*) AS nb_lignes,
    CASE WHEN COUNT(*) = 3 THEN 'PASS — 3 sources chargées' ELSE 'FAIL' END AS resultat
FROM sources;

-- Mots-clés
SELECT
    'mots_cles' AS table_name,
    COUNT(*) AS nb_lignes,
    CASE WHEN COUNT(*) = 10 THEN 'PASS — 10 mots-clés chargés' ELSE 'FAIL' END AS resultat
FROM mots_cles;

-- Acheteurs
SELECT
    'acheteurs' AS table_name,
    COUNT(*) AS nb_lignes,
    CASE WHEN COUNT(*) >= 28 THEN 'PASS — 28+ acheteurs chargés' ELSE 'FAIL' END AS resultat
FROM acheteurs;

-- Détail sources
SELECT '' AS sep;
SELECT '--- Sources ---' AS detail;
SELECT id_source, nom_source, type_source, actif FROM sources;

-- Mots-clés PRIMARY
SELECT '' AS sep;
SELECT '--- Mots-clés PRIMARY ---' AS detail;
SELECT id_mot_cle, mot_cle, categorie, pertinence FROM mots_cles WHERE categorie = 'PRIMARY';

-- Mots-clés SECONDARY
SELECT '' AS sep;
SELECT '--- Mots-clés SECONDARY ---' AS detail;
SELECT id_mot_cle, mot_cle, categorie, pertinence FROM mots_cles WHERE categorie = 'SECONDARY';

-- Acheteurs par type
SELECT '' AS sep;
SELECT '--- Acheteurs par type ---' AS detail;
SELECT type_acheteur, COUNT(*) AS nb FROM acheteurs GROUP BY type_acheteur ORDER BY nb DESC;

-- ============================================================================
-- TEST 3 : CONTRAINTE UNIQUE (source_id, id_externe)
-- ============================================================================

SELECT '' AS sep;
SELECT '=== TEST 3 : CONTRAINTE UNIQUE DOUBLON ===' AS test_name;

-- Insertion valide
INSERT INTO annonces (
    source_id, acheteur_id, id_externe,
    titre, date_publication, date_limite_reponse
) VALUES (
    1, 1, 'TEST_CONTRAINTE_001',
    'Annonce test contrainte unicité',
    NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY)
);
SELECT 'Annonce #1 insérée avec succès' AS message;

-- Tentative de doublon (doit échouer)
SELECT '--- Tentative insertion doublon (DOIT ÉCHOUER) ---' AS detail;
INSERT INTO annonces (
    source_id, acheteur_id, id_externe,
    titre, date_publication, date_limite_reponse
) VALUES (
    1, 1, 'TEST_CONTRAINTE_001',
    'Doublon annonce test',
    NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY)
);
SELECT 'ERREUR : le doublon a été inséré — contrainte UNIQUE non respectée !' AS message;

-- ============================================================================
-- TEST 4 : CONTRAINTE CLEF ÉTRANGÈRE
-- ============================================================================

SELECT '' AS sep;
SELECT '=== TEST 4 : CLEF ÉTRANGÈRE acheteur_id ===' AS test_name;

-- Référence vers acheteur_id inexistant (doit échouer)
SELECT '--- Tentative FK invalide acheteur_id=99999 (DOIT ÉCHOUER) ---' AS detail;
INSERT INTO annonces (
    source_id, acheteur_id, id_externe,
    titre, date_publication, date_limite_reponse
) VALUES (
    1, 99999, 'TEST_FK_001',
    'Test contrainte FK acheteur',
    NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY)
);
SELECT 'ERREUR : la FK acheteur_id=99999 a été acceptée — contrainte non respectée !' AS message;

-- ============================================================================
-- TEST 5 : CONTRAINTE CHECK (titre minimum 6 caractères)
-- ============================================================================

SELECT '' AS sep;
SELECT '=== TEST 5 : CHECK titre >= 6 caractères ===' AS test_name;

SELECT '--- Tentative titre trop court (DOIT ÉCHOUER) ---' AS detail;
INSERT INTO annonces (
    source_id, acheteur_id, id_externe,
    titre, date_publication, date_limite_reponse
) VALUES (
    1, 1, 'TEST_CHK_001',
    'Bad',  -- ← 3 caractères, CHECK doit rejeter
    NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY)
);
SELECT 'ERREUR : le titre court a été accepté — contrainte CHECK non respectée !' AS message;

-- ============================================================================
-- TEST 6 : INDEXES ET REQUÊTES DE PERFORMANCE
-- ============================================================================

SELECT '' AS sep;
SELECT '=== TEST 6 : INDEXES ET REQUÊTES ===' AS test_name;

SELECT
    'Nombre d''indexes (hors PRIMARY) :' AS metrique,
    COUNT(*) AS valeur
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND index_name != 'PRIMARY';

-- Annonces avec deadline dans les 30 prochains jours
SELECT '' AS sep;
SELECT '--- Annonces deadline < 30 jours ---' AS detail;
SELECT
    id_annonce,
    titre,
    date_limite_reponse,
    DATEDIFF(date_limite_reponse, NOW()) AS jours_restants
FROM annonces
WHERE date_limite_reponse BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL 30 DAY)
ORDER BY date_limite_reponse ASC;

-- Répartition par région
SELECT '' AS sep;
SELECT '--- Annonces par région ---' AS detail;
SELECT
    region,
    COUNT(*) AS nb_annonces
FROM annonces
WHERE region IS NOT NULL
GROUP BY region
ORDER BY nb_annonces DESC;

-- ============================================================================
-- TEST 7 : RELATIONS (JOIN annonces → sources → acheteurs)
-- ============================================================================

SELECT '' AS sep;
SELECT '=== TEST 7 : JOINTURES INTER-TABLES ===' AS test_name;

SELECT '' AS sep;
SELECT '--- Détail annonce de test avec source et acheteur ---' AS detail;
SELECT
    a.id_annonce,
    a.titre,
    s.nom_source,
    ac.nom_acheteur,
    a.statut,
    a.timestamp_import
FROM annonces a
JOIN sources  s  ON a.source_id   = s.id_source
JOIN acheteurs ac ON a.acheteur_id = ac.id_acheteur
WHERE a.id_externe = 'TEST_CONTRAINTE_001'
LIMIT 1;

-- ============================================================================
-- TEST 8 : VALEURS ENUM FRANÇAISES
-- ============================================================================

SELECT '' AS sep;
SELECT '=== TEST 8 : ENUM FRANÇAIS ===' AS test_name;

-- Vérification que les ENUM acceptent les valeurs françaises
UPDATE annonces SET statut = 'QUALIFIE'  WHERE id_externe = 'TEST_CONTRAINTE_001';
UPDATE annonces SET statut = 'IGNORE'    WHERE id_externe = 'TEST_CONTRAINTE_001';
UPDATE annonces SET statut = 'REPONDU'   WHERE id_externe = 'TEST_CONTRAINTE_001';
UPDATE annonces SET statut = 'NOUVEAU'   WHERE id_externe = 'TEST_CONTRAINTE_001';

SELECT
    id_externe,
    statut,
    CASE
        WHEN statut = 'NOUVEAU' THEN 'PASS — ENUM français OK'
        ELSE 'FAIL'
    END AS resultat
FROM annonces
WHERE id_externe = 'TEST_CONTRAINTE_001';

-- ============================================================================
-- NETTOYAGE DES DONNÉES DE TEST
-- ============================================================================

SELECT '' AS sep;
SELECT '--- Nettoyage données de test ---' AS detail;
DELETE FROM annonces WHERE id_externe LIKE 'TEST_%';
SELECT CONCAT('Lignes supprimées : ', ROW_COUNT()) AS message;

-- ============================================================================
-- BILAN FINAL
-- ============================================================================

SELECT '' AS sep;
SELECT '=== BILAN FINAL ===' AS test_name;
SELECT 'Tests du schéma terminés' AS message;
SELECT 'Vérifier les messages FAIL/ERREUR ci-dessus pour toute anomalie' AS avertissement;

-- ============================================================================
-- FIN FICHIER : 01_test_schema.sql
-- ============================================================================
