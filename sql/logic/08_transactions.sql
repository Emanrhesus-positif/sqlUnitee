-- =====================================================================
-- UNITEE - Gestion des Transactions
-- Fichier : 08_transactions.sql
-- Objet : Démonstration COMMIT / ROLLBACK / SAVEPOINT sur le schéma
--         de veille marchés publics
--
-- Noms de tables conformes à 02_create_tables.sql :
--   sources, acheteurs, mots_cles, annonces, annonce_mot_cle,
--   qualification_scores, notifications, log_technique,
--   log_metier, historique_annonces, log_sauvegardes
-- =====================================================================

USE unitee;

-- =====================================================================
-- SCÉNARIO 1 : Transaction complète — insertion d'une annonce valide
-- Attendu : COMMIT — les deux annonces sont persistées
-- =====================================================================

SELECT '[SCÉNARIO 1] Démarrage transaction avec COMMIT...' AS etape;

START TRANSACTION;

-- Insertion annonce 1
INSERT INTO annonces (
    source_id, acheteur_id, id_externe,
    titre, description,
    montant_estime, devise,
    date_publication, date_limite_reponse,
    localisation, region, lien_source,
    statut
) VALUES (
    1, 1, 'TRANS_TEST_001',
    'Construction modulaire école primaire Rennes',
    'Fourniture et installation d''un bâtiment préfabriqué de 6 classes',
    280000.00, 'EUR',
    NOW(), DATE_ADD(NOW(), INTERVAL 21 DAY),
    '35000 Rennes', 'Bretagne',
    'http://boamp.fr/trans-test-001',
    'NEW'
);
SET @id_annonce_1 = LAST_INSERT_ID();

-- Insertion annonce 2
INSERT INTO annonces (
    source_id, acheteur_id, id_externe,
    titre, description,
    montant_estime, devise,
    date_publication, date_limite_reponse,
    localisation, region, lien_source,
    statut
) VALUES (
    2, 2, 'TRANS_TEST_002',
    'Base vie modulaire chantier A89 Clermont',
    'Location longue durée d''une base vie assemblage rapide 120 personnes',
    95000.00, 'EUR',
    NOW(), DATE_ADD(NOW(), INTERVAL 14 DAY),
    '63000 Clermont-Ferrand', 'Auvergne-Rhône-Alpes',
    'http://boamp.fr/trans-test-002',
    'NEW'
);
SET @id_annonce_2 = LAST_INSERT_ID();

COMMIT;

SELECT CONCAT('[SCÉNARIO 1] COMMIT OK — annonces insérées : ', @id_annonce_1, ', ', @id_annonce_2) AS resultat;

-- =====================================================================
-- SCÉNARIO 2 : Rollback sur erreur — titre NULL rejeté par trigger
-- Attendu : ROLLBACK — aucune ligne insérée
-- =====================================================================

SELECT '[SCÉNARIO 2] Démarrage transaction avec ROLLBACK attendu...' AS etape;

START TRANSACTION;

-- Cette insertion doit être rejetée par le trigger avant_insert_annonce
-- (titre NULL = violation contrainte métier)
INSERT INTO annonces (
    source_id, acheteur_id, id_externe,
    titre, description,
    montant_estime, devise,
    date_publication, date_limite_reponse,
    localisation, region, lien_source,
    statut
) VALUES (
    1, 1, 'TRANS_TEST_ERREUR',
    NULL,  -- ← titre NULL : rejeté par trigger BEFORE INSERT
    'Description sans titre',
    50000.00, 'EUR',
    NOW(), DATE_ADD(NOW(), INTERVAL 10 DAY),
    '75001 Paris', 'Île-de-France',
    'http://test-erreur.com',
    'NEW'
);

-- Si on arrive ici (MySQL sans mode strict) : rollback manuel
ROLLBACK;

SELECT '[SCÉNARIO 2] ROLLBACK exécuté — aucune donnée invalide persistée' AS resultat;

-- =====================================================================
-- SCÉNARIO 3 : Vérification intégrité après rollback
-- Attendu : 0 ligne avec id_externe = 'TRANS_TEST_ERREUR'
-- =====================================================================

SELECT '[SCÉNARIO 3] Vérification intégrité post-rollback...' AS etape;

SELECT
    COUNT(*) AS insertions_invalides_detectees,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS — rollback efficace'
        ELSE 'FAIL — données invalides présentes'
    END AS resultat
FROM annonces
WHERE id_externe = 'TRANS_TEST_ERREUR';

-- =====================================================================
-- SCÉNARIO 4 : SAVEPOINT — insertion partielle avec récupération
-- Attendu : sp1 conservé, sp2 remplacé par insertion valide, COMMIT final
-- =====================================================================

SELECT '[SCÉNARIO 4] Démarrage transaction avec SAVEPOINT...' AS etape;

START TRANSACTION;

-- SAVEPOINT 1 : données valides
SAVEPOINT sp1;
INSERT INTO annonces (
    source_id, acheteur_id, id_externe,
    titre, montant_estime, devise,
    date_publication, date_limite_reponse,
    region, statut
) VALUES (
    1, 3, 'TRANS_SP_001',
    'Bâtiment en kit gymnase municipal Bordeaux',
    195000.00, 'EUR',
    NOW(), DATE_ADD(NOW(), INTERVAL 18 DAY),
    'Nouvelle-Aquitaine', 'NEW'
);
SET @id_sp1 = LAST_INSERT_ID();

-- SAVEPOINT 2 : tentative montant négatif (invalide)
SAVEPOINT sp2;
INSERT INTO annonces (
    source_id, acheteur_id, id_externe,
    titre, montant_estime, devise,
    date_publication, date_limite_reponse,
    region, statut
) VALUES (
    1, 3, 'TRANS_SP_002',
    'Classe temporaire préfabriquée Strasbourg',
    -50000.00, 'EUR',  -- ← montant négatif : rejeté par contrainte ck_montant_positif
    NOW(), DATE_ADD(NOW(), INTERVAL 12 DAY),
    'Grand Est', 'NEW'
);

-- Retour au savepoint 2 pour annuler l'insertion invalide
ROLLBACK TO SAVEPOINT sp2;

-- Remplacement par données valides
INSERT INTO annonces (
    source_id, acheteur_id, id_externe,
    titre, montant_estime, devise,
    date_publication, date_limite_reponse,
    region, statut
) VALUES (
    1, 3, 'TRANS_SP_002_CORR',
    'Classe temporaire préfabriquée Strasbourg (corrigé)',
    78000.00, 'EUR',
    NOW(), DATE_ADD(NOW(), INTERVAL 12 DAY),
    'Grand Est', 'NEW'
);
SET @id_sp2_corr = LAST_INSERT_ID();

COMMIT;

SELECT CONCAT('[SCÉNARIO 4] COMMIT OK — sp1=', @id_sp1, ', sp2_corr=', @id_sp2_corr) AS resultat;

-- =====================================================================
-- SCÉNARIO 5 : Transaction sur log_technique (table indépendante)
-- Illustre l'utilisation de START TRANSACTION sur une table sans FK
-- =====================================================================

SELECT '[SCÉNARIO 5] Transaction sur log_technique...' AS etape;

START TRANSACTION;

INSERT INTO log_technique (type_operation, source_operation, status, message, duree_ms)
VALUES ('IMPORT_API_DATA_GOUV', 'transaction_test', 'OK', 'Import test scénario 5 réussi', 42);

INSERT INTO log_technique (type_operation, source_operation, status, message, duree_ms)
VALUES ('SCORE_CALCULATION', 'transaction_test', 'OK', 'Scoring lot test scénario 5', 18);

COMMIT;

SELECT '[SCÉNARIO 5] COMMIT OK — 2 logs techniques persistés' AS resultat;

-- =====================================================================
-- RÉSUMÉ
-- =====================================================================

SELECT
    'BILAN TRANSACTIONS' AS titre,
    'Scénario 1 : COMMIT multiple annonces valides'   AS s1,
    'Scénario 2 : ROLLBACK annonce invalide (NULL)'   AS s2,
    'Scénario 3 : Vérification intégrité post-ROLLBACK' AS s3,
    'Scénario 4 : SAVEPOINT + correction partielle'   AS s4,
    'Scénario 5 : Transaction table indépendante'     AS s5;

-- =====================================================================
-- FIN FICHIER : 08_transactions.sql
-- =====================================================================
