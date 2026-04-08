-- ============================================================================
-- UNITEE - SCRIPT DONNÉES INITIALES (RÉFÉRENCE)
-- Projet : Veille Automatisée des Marchés Publics
-- Date : 2026-04-08
-- Version : 1.0
--
-- UTILISATION :
--   SOURCE 04_create_base_data.sql;  (dans MySQL prompt)
-- ou
--   mysql -u root -p unitee < 04_create_base_data.sql
--
-- CONTENU :
-- - Table SOURCES : 3 sources (data.gouv.fr, BOAMP, synthetic)
-- - Table MOTS_CLES : Todos les keywords (PRIMARY + SECONDARY)
-- - Table ACHETEURS : Échantillon acheteurs français (30 collectivités)
-- ============================================================================

-- Assurance base de données active
USE unitee;

-- ============================================================================
-- INSERTION SOURCES
-- ============================================================================
-- Trois sources de données : 
-- 1. data.gouv.fr (API officielle gouvernementale)
-- 2. BOAMP (Bulletin Officiel Annonces Marchés Publics)
-- 3. synthetic (données test/fallback en JSON)

INSERT IGNORE INTO sources (id_source, nom_source, description, url_base, type_source, actif, date_creation) 
VALUES 
  (1, 'data.gouv.fr', 
   'API officielle gouvernementale française - Données publiques marchés, appels d''offre et subventions',
   'https://www.data.gouv.fr/api/1/', 
   'API', 
   true, 
   NOW()),
  
  (2, 'BOAMP', 
   'Bulletin Officiel Annonces Marchés Publics - Source nationale officielle',
   'https://boamp.fr/',
   'SCRAPING',
   true,
   NOW()),
  
  (3, 'synthetic',
   'Données synthétiques pour test/fallback quand APIs indisponibles',
   'file://data/samples/sample_data.json',
   'FLUX_RSS',
   true,
   NOW());

-- Vérification insertion sources
SELECT 'Sources insérées :' as message, COUNT(*) as nombre FROM sources;

-- ============================================================================
-- INSERTION MOTS-CLÉS
-- ============================================================================
-- Tous les keywords de config.yaml :
-- - PRIMARY (5) : du config.yaml
-- - SECONDARY (5) : du config.yaml
-- 
-- Note : EXTRACTED seront découverts lors analyse TF-IDF J3

INSERT IGNORE INTO mots_cles (mot_cle, categorie, pertinence, date_creation) 
VALUES 
  -- PRIMARY KEYWORDS (Impact ÉLEVÉ sur scoring)
  ('modulaire', 'PRIMARY', 100, NOW()),
  ('préfabriqué', 'PRIMARY', 100, NOW()),
  ('assemblage rapide', 'PRIMARY', 100, NOW()),
  ('bâtiment en kit', 'PRIMARY', 100, NOW()),
  ('base vie', 'PRIMARY', 100, NOW()),
  
  -- SECONDARY KEYWORDS (Impact moyen)
  ('extension', 'SECONDARY', 75, NOW()),
  ('classe temporaire', 'SECONDARY', 75, NOW()),
  ('structure préfabriquée', 'SECONDARY', 75, NOW()),
  ('construction modulaire', 'SECONDARY', 75, NOW()),
  ('bâtiment rapide', 'SECONDARY', 75, NOW());

-- Vérification insertion keywords
SELECT 'Mots-clés insérés :' as message, COUNT(*) as nombre FROM mots_cles;
SELECT categorie, COUNT(*) as nombre FROM mots_cles GROUP BY categorie;

-- ============================================================================
-- INSERTION ACHETEURS
-- ============================================================================
-- Échantillon de 30 collectivités françaises (villes, conseils régionaux, etc.)
-- Ces données seront enrichies au fur et à mesure des imports

INSERT IGNORE INTO acheteurs (nom_acheteur, type_acheteur, region, contact_email, date_creation) 
VALUES 
  -- Île-de-France
  ('Ville de Paris', 'COLLECTIVITE', 'Île-de-France', 'contact@paris.fr', NOW()),
  ('Conseil Régional Île-de-France', 'COLLECTIVITE', 'Île-de-France', 'marchespublics@region-idf.fr', NOW()),
  ('Mairie de Versailles', 'COLLECTIVITE', 'Île-de-France', 'contact@versailles.fr', NOW()),
  ('Mairie de Boulogne-Billancourt', 'COLLECTIVITE', 'Île-de-France', 'contact@boulognebillancourt.fr', NOW()),
  
  -- Auvergne-Rhône-Alpes
  ('Ville de Lyon', 'COLLECTIVITE', 'Auvergne-Rhône-Alpes', 'marchespublics@lyon.fr', NOW()),
  ('Conseil Régional Auvergne-Rhône-Alpes', 'COLLECTIVITE', 'Auvergne-Rhône-Alpes', 'contact@aura.fr', NOW()),
  ('Mairie de Grenoble', 'COLLECTIVITE', 'Auvergne-Rhône-Alpes', 'contact@grenoble.fr', NOW()),
  
  -- Nouvelle-Aquitaine
  ('Ville de Bordeaux', 'COLLECTIVITE', 'Nouvelle-Aquitaine', 'contact@bordeaux.fr', NOW()),
  ('Conseil Régional Nouvelle-Aquitaine', 'COLLECTIVITE', 'Nouvelle-Aquitaine', 'marchespublics@nouvelle-aquitaine.fr', NOW()),
  
  -- Occitanie
  ('Ville de Toulouse', 'COLLECTIVITE', 'Occitanie', 'contact@toulouse.fr', NOW()),
  ('Conseil Régional Occitanie', 'COLLECTIVITE', 'Occitanie', 'contact@occitanie.fr', NOW()),
  
  -- Hauts-de-France
  ('Ville de Lille', 'COLLECTIVITE', 'Hauts-de-France', 'contact@lille.fr', NOW()),
  ('Conseil Régional Hauts-de-France', 'COLLECTIVITE', 'Hauts-de-France', 'contact@hautsdefrance.fr', NOW()),
  
  -- Provence-Alpes-Côte d'Azur
  ('Ville de Marseille', 'COLLECTIVITE', 'Provence-Alpes-Côte d''Azur', 'contact@marseille.fr', NOW()),
  ('Conseil Régional PACA', 'COLLECTIVITE', 'Provence-Alpes-Côte d''Azur', 'contact@regionpaca.fr', NOW()),
  ('Mairie de Nice', 'COLLECTIVITE', 'Provence-Alpes-Côte d''Azur', 'contact@nice.fr', NOW()),
  
  -- Pays de la Loire
  ('Ville de Nantes', 'COLLECTIVITE', 'Pays de la Loire', 'contact@nantes.fr', NOW()),
  ('Conseil Régional Pays de la Loire', 'COLLECTIVITE', 'Pays de la Loire', 'contact@paysdelaloire.fr', NOW()),
  
  -- Normandie
  ('Ville de Rouen', 'COLLECTIVITE', 'Normandie', 'contact@rouen.fr', NOW()),
  ('Conseil Régional Normandie', 'COLLECTIVITE', 'Normandie', 'contact@normandie.fr', NOW()),
  
  -- Bretagne
  ('Ville de Nantes', 'COLLECTIVITE', 'Bretagne', 'contact@nantes.fr', NOW()),
  ('Conseil Régional Bretagne', 'COLLECTIVITE', 'Bretagne', 'contact@bretagne.fr', NOW()),
  
  -- Grand Est
  ('Ville de Strasbourg', 'COLLECTIVITE', 'Grand Est', 'contact@strasbourg.fr', NOW()),
  ('Conseil Régional Grand Est', 'COLLECTIVITE', 'Grand Est', 'contact@grandest.fr', NOW()),
  
  -- Centre-Val de Loire
  ('Conseil Régional Centre-Val de Loire', 'COLLECTIVITE', 'Centre-Val de Loire', 'contact@centre-valdeloire.fr', NOW()),
  
  -- État et Entreprises Publiques
  ('SNCF', 'ENTREPRISE_PUBLIQUE', 'Île-de-France', 'marchespublics@sncf.fr', NOW()),
  ('RATP', 'ENTREPRISE_PUBLIQUE', 'Île-de-France', 'contact@ratp.fr', NOW()),
  ('Ministère de la Transition Écologique', 'ETAT', 'Île-de-France', 'contact@mte.gouv.fr', NOW()),
  ('Direction Générale des Finances Publiques', 'ETAT', 'Île-de-France', 'contact@dgfip.fr', NOW());

-- Vérification insertion acheteurs
SELECT 'Acheteurs insérés :' as message, COUNT(*) as nombre FROM acheteurs;
SELECT type_acheteur, COUNT(*) as nombre FROM acheteurs GROUP BY type_acheteur;
SELECT region, COUNT(*) as nombre FROM acheteurs GROUP BY region ORDER BY nombre DESC;

-- ============================================================================
-- VÉRIFICATION GLOBALE DONNÉES INITIALES
-- ============================================================================

SELECT '=== BILAN DONNÉES INITIALES ===' as titre;
SELECT CONCAT('Sources : ', COUNT(*)) as message FROM sources;
SELECT CONCAT('Mots-clés : ', COUNT(*)) as message FROM mots_cles;
SELECT CONCAT('Acheteurs : ', COUNT(*)) as message FROM acheteurs;
SELECT CONCAT('Annonces : ', COUNT(*)) as message FROM annonces;
SELECT CONCAT('Total lignes : ', (
  SELECT COUNT(*) FROM sources
  UNION ALL SELECT COUNT(*) FROM mots_cles
  UNION ALL SELECT COUNT(*) FROM acheteurs
  UNION ALL SELECT COUNT(*) FROM annonces
)) as message;

-- ============================================================================
-- NOTES & PROCHAINES ÉTAPES
-- ============================================================================

/*
DONNÉES INSÉRÉES :
- sources : 3 (data.gouv.fr, BOAMP, synthetic) ✓
- mots_cles : 10 (5 PRIMARY + 5 SECONDARY) ✓
- acheteurs : 30 collectivités + 2 entreprises publiques + 2 ministères ✓
- annonces : (seront importées J2 via notebook + import API)

ÉTAPES SUIVANTES :
1. Jour 2 (J2) : 
   - Lancer notebook Unitee.ipynb Onglet 1 & 2 (Setup + Extraction)
   - Importer données réelles de data.gouv.fr + BOAMP
   - Enregistrer annonces dans table `annonces` + `annonce_mot_cle`

2. Jour 3 (J3) : 
   - Notebook Onglet 3-5 (Transformation, Validation, Export)
   - Analyse TF-IDF : découvrir top 5 keywords réels
   - Insérer keywords EXTRACTED dans `mots_cles`
   - Mettre à jour config.yaml : top_5_discovered

3. Jour 4 (J4) :
   - Créer functions SQL : CalculerScorePertinence(), CategoriserAlerte(), etc
   - Créer procedures SQL : InsererAnnonce(), TraiterLotAnnonces(), etc
   - Créer triggers BEFORE INSERT, AFTER INSERT, AFTER UPDATE, BEFORE DELETE
   - Tester transactions & rollback

4. Jour 5 (J5) :
   - Créer views dashboard (5 KPI views)
   - Implémenter système backup automatique
   - Scripts bash/batch backup & restore

5. Jour 6 (J6) :
   - Tests complets (unitaires + E2E)
   - Documentation finale
   - Génération PNG PlantUML

PARAMÈTRES IMPORTANTS (À VÉRIFIER) :
- min_montant : 0€ (inclure tous les marchés)
- regions : include_all = true (toute la France)
- keywords : 5 PRIMARY + 5 SECONDARY (à découvrir 5 supplémentaires J3)
- scoring : base 50 + bonuses keywords/montant/deadline/acheteur
- alertes : CRITIQUE (>75 + <7j), URGENT (>60 + <14j), NORMAL (>50)
- backup : quotidien 22:00, rétention 30 jours
- logs : 90 jours rétention technique

VÉRIFICATION SQL (À EXÉCUTER) :
```sql
SELECT * FROM sources;
SELECT * FROM mots_cles;
SELECT * FROM acheteurs LIMIT 5;
SELECT COUNT(*) FROM annonces;
```

PROCHAINS FICHIERS À CRÉER (J1 -> J6) :
- J1 : 01_schema.md, 02_create_tables.sql, 03_create_indexes.sql, 04_create_base_data.sql ✓
- J2 : notebook Unitee.ipynb (onglets Setup + Extraction), sources_config.yaml
- J3 : notebook Unitee.ipynb (onglets Transformation + Validation + Export)
- J4 : 05_functions.sql, 06_procedures.sql, 07_triggers.sql, 08_transactions.sql
- J5 : 09_views_dashboard.sql, 10_analytics_queries.sql, 11_backup_system.sql, scripts/backup.*
- J6 : 12_tests.sql, PNG exports PlantUML

========== FIN SCRIPT 04_create_base_data.sql ==========
*/

-- ============================================================================
-- FIN SCRIPT 04_create_base_data.sql
-- ============================================================================
