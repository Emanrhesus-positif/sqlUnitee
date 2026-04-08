-- ============================================================================
-- UNITEE - INITIAL DATA LOADING (V2 - Based on UML)
-- Date: 2026-04-08
-- Version: 2.0
-- 
-- This script loads initial reference data:
-- - 3 sources
-- - 10 keywords (5 PRIMARY + 5 SECONDARY)
-- - 28+ buyers across France
-- ============================================================================

USE unitee;

-- ============================================================================
-- 1. SOURCES - 3 data sources
-- ============================================================================

INSERT INTO sources (source_name, description, api_base_url, source_type, active) VALUES
('data.gouv.fr', 'French government open data platform', 'https://www.data.gouv.fr/api/1/', 'API', true),
('BOAMP', 'Official bulletin of public procurement', 'https://www.boamp.fr/', 'SCRAPING', true),
('synthetic', 'Test data for development and validation', NULL, 'FLUX_RSS', true);

SELECT CONCAT('Sources inserted: ', COUNT(*)) as message FROM sources;

-- ============================================================================
-- 2. KEYWORDS - 10 keywords (5 PRIMARY + 5 SECONDARY)
-- ============================================================================

INSERT INTO keywords (keyword_text, category) VALUES
-- PRIMARY keywords (high priority, from config.yaml)
('modulaire', 'PRIMARY'),
('préfabriqué', 'PRIMARY'),
('assemblage rapide', 'PRIMARY'),
('bâtiment en kit', 'PRIMARY'),
('base vie', 'PRIMARY'),
-- SECONDARY keywords (medium priority, from config.yaml)
('extension', 'SECONDARY'),
('classe temporaire', 'SECONDARY'),
('structure préfabriquée', 'SECONDARY'),
('construction modulaire', 'SECONDARY'),
('bâtiment rapide', 'SECONDARY');

SELECT CONCAT('Keywords inserted: ', COUNT(*)) as message FROM keywords;

-- Breakdown by category
SELECT 
  category,
  COUNT(*) as count
FROM keywords
GROUP BY category;

-- ============================================================================
-- 3. BUYERS - 28+ public buyers across France
-- ============================================================================

INSERT INTO buyers (buyer_name, buyer_type, region, contact_email, contact_phone) VALUES
-- Île-de-France (8)
('Ville de Paris', 'COLLECTIVITE', 'Île-de-France', 'contact@paris.fr', '+33 1 42 76 49 49'),
('Région Île-de-France', 'COLLECTIVITE', 'Île-de-France', 'contact@iledefrance.fr', '+33 1 53 85 53 85'),
('Département 75 (Paris)', 'COLLECTIVITE', 'Île-de-France', 'contact@75.fr', '+33 1 53 36 53 36'),
('Communauté de communes Val de Seine', 'COLLECTIVITE', 'Île-de-France', 'contact@valseine.fr', NULL),
('Ville de Boulogne-Billancourt', 'COLLECTIVITE', 'Île-de-France', 'contact@boulogne92.fr', NULL),
('Ville de Nanterre', 'COLLECTIVITE', 'Île-de-France', 'contact@nanterre.fr', NULL),
('Ministère de la Transition Écologique', 'ETAT', 'Île-de-France', 'contact@mte.gouv.fr', '+33 1 40 81 80 00'),
('SNCF Réseau', 'ENTREPRISE_PUBLIQUE', 'Île-de-France', 'contact@sncf.fr', '+33 1 53 25 25 25'),

-- Auvergne-Rhône-Alpes (3)
('Métropole de Lyon', 'COLLECTIVITE', 'Auvergne-Rhône-Alpes', 'contact@metropole-lyon.fr', '+33 4 72 10 30 30'),
('Ville de Grenoble', 'COLLECTIVITE', 'Auvergne-Rhône-Alpes', 'contact@grenoble.fr', '+33 4 76 76 76 76'),
('Région Auvergne-Rhône-Alpes', 'COLLECTIVITE', 'Auvergne-Rhône-Alpes', 'contact@aura.fr', '+33 4 26 73 40 40'),

-- Provence-Alpes-Côte d'Azur (3)
('Ville de Marseille', 'COLLECTIVITE', 'Provence-Alpes-Côte d''Azur', 'contact@marseille.fr', '+33 4 91 55 55 55'),
('Métropole Aix-Provence', 'COLLECTIVITE', 'Provence-Alpes-Côte d''Azur', 'contact@aixmetropole.fr', NULL),
('Région PACA', 'COLLECTIVITE', 'Provence-Alpes-Côte d''Azur', 'contact@paca.fr', '+33 4 91 57 57 57'),

-- Grand Est (2)
('Ville de Strasbourg', 'COLLECTIVITE', 'Grand Est', 'contact@strasbourg.fr', '+33 3 68 98 51 51'),
('Région Grand Est', 'COLLECTIVITE', 'Grand Est', 'contact@grandest.fr', '+33 3 87 33 60 60'),

-- Hauts-de-France (2)
('Ville de Lille', 'COLLECTIVITE', 'Hauts-de-France', 'contact@lille.fr', '+33 3 20 49 50 00'),
('Région Hauts-de-France', 'COLLECTIVITE', 'Hauts-de-France', 'contact@hautsdefrance.fr', '+33 3 20 13 40 40'),

-- Normandie (2)
('Ville de Rouen', 'COLLECTIVITE', 'Normandie', 'contact@rouen.fr', '+33 2 32 08 32 08'),
('Région Normandie', 'COLLECTIVITE', 'Normandie', 'contact@normandie.fr', '+33 2 31 06 98 00'),

-- Nouvelle-Aquitaine (2)
('Ville de Bordeaux', 'COLLECTIVITE', 'Nouvelle-Aquitaine', 'contact@bordeaux.fr', '+33 5 56 10 20 30'),
('Région Nouvelle-Aquitaine', 'COLLECTIVITE', 'Nouvelle-Aquitaine', 'contact@nouvelle-aquitaine.fr', NULL),

-- Occitanie (2)
('Ville de Toulouse', 'COLLECTIVITE', 'Occitanie', 'contact@toulouse.fr', '+33 5 61 23 13 13'),
('Région Occitanie', 'COLLECTIVITE', 'Occitanie', 'contact@occitanie.fr', '+33 5 67 76 76 76'),

-- Pays de la Loire (2)
('Ville de Nantes', 'COLLECTIVITE', 'Pays de la Loire', 'contact@nantes.fr', '+33 2 40 41 41 41'),
('Région Pays de la Loire', 'COLLECTIVITE', 'Pays de la Loire', 'contact@pdl.fr', '+33 2 41 81 81 81'),

-- Bretagne (1)
('Ville de Rennes', 'COLLECTIVITE', 'Bretagne', 'contact@rennes.fr', '+33 2 23 62 62 62'),

-- Centre-Val de Loire (1)
('Ville d''Orléans', 'COLLECTIVITE', 'Centre-Val de Loire', 'contact@orleans.fr', '+33 2 38 79 22 22'),

-- Additional enterprise (1)
('La Poste', 'ENTREPRISE_PUBLIQUE', 'Île-de-France', 'contact@laposte.fr', '+33 1 55 44 55 44');

SELECT CONCAT('Buyers inserted: ', COUNT(*)) as message FROM buyers;

-- Breakdown by type
SELECT 
  buyer_type,
  COUNT(*) as count
FROM buyers
GROUP BY buyer_type
ORDER BY count DESC;

-- Breakdown by region
SELECT 
  region,
  COUNT(*) as count
FROM buyers
WHERE region IS NOT NULL
GROUP BY region
ORDER BY count DESC;

-- ============================================================================
-- SUMMARY
-- ============================================================================

SELECT '=== INITIAL DATA SUMMARY ===' as title;
SELECT CONCAT('Sources: ', COUNT(*)) as message FROM sources
UNION ALL
SELECT CONCAT('Keywords: ', COUNT(*)) FROM keywords
UNION ALL
SELECT CONCAT('Buyers: ', COUNT(*)) FROM buyers
UNION ALL
SELECT CONCAT('Announcements: ', COUNT(*)) FROM announcements;

-- ============================================================================
-- END OF SCRIPT
-- ============================================================================
