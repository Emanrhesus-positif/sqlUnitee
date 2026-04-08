-- ============================================================================
-- UNITEE - SCRIPT CRÉATION DES INDEXES STRATÉGIQUES
-- Projet : Veille Automatisée des Marchés Publics
-- Date : 2026-04-08
-- Version : 1.0
--
-- UTILISATION :
--   SOURCE 03_create_indexes.sql;  (dans MySQL prompt)
-- ou
--   mysql -u root -p unitee < 03_create_indexes.sql
--
-- NOTE : Les indexes des Foreign Keys existent déjà (MySQL les crée auto).
-- Ce script ajoute les indexes STRATÉGIQUES pour performance requêtes.
-- Total : ~20 indexes pour optimiser recherches fréquentes.
-- ============================================================================

-- Assurance base de données active
USE unitee;

-- ============================================================================
-- SECTION 1 : INDEXES SUR TABLE `sources`
-- ============================================================================

-- Index sur nom_source (déjà UNIQUE dans DDL, mais récité pour clarté)
-- Utilisé pour : recherche rapide source par nom
-- Performance : O(log n) au lieu O(n)
CREATE INDEX idx_sources_nom_source ON sources (nom_source);

-- Index sur type_source (pour filtrer API vs SCRAPING vs RSS)
-- Utilisé pour : "toutes sources de type API"
CREATE INDEX idx_sources_type_source ON sources (type_source);

-- Index sur actif (pour filtrer sources désactivées)
CREATE INDEX idx_sources_actif ON sources (actif);

-- ============================================================================
-- SECTION 2 : INDEXES SUR TABLE `acheteurs`
-- ============================================================================

-- Index sur type_acheteur (pour filtrer COLLECTIVITE vs ETAT vs ENTREPRISE_PUBLIQUE)
-- Utilisé pour : recherches par catégorie acheteur
CREATE INDEX idx_acheteurs_type_acheteur ON acheteurs (type_acheteur);

-- Index sur region (pour recherche géographique)
-- Utilisé pour : "acheteurs en Île-de-France"
-- ⚠️ CRITIQUE pour dashboards régionaux
CREATE INDEX idx_acheteurs_region ON acheteurs (region);

-- Index composite : type + region (pour requêtes combinées)
-- Utilisé pour : "COLLECTIVITE en Île-de-France"
CREATE INDEX idx_acheteurs_type_region ON acheteurs (type_acheteur, region);

-- ============================================================================
-- SECTION 3 : INDEXES SUR TABLE `mots_cles`
-- ============================================================================

-- Index sur categorie (pour filtrer PRIMARY vs SECONDARY vs EXTRACTED)
-- Utilisé pour : "tous keywords primaires"
CREATE INDEX idx_mots_cles_categorie ON mots_cles (categorie);

-- Index sur pertinence (pour filtrer keywords avec score > X)
-- Utilisé pour : "keywords pertinents (score >= 70)"
CREATE INDEX idx_mots_cles_pertinence ON mots_cles (pertinence);

-- ============================================================================
-- SECTION 4 : INDEXES SUR TABLE `annonces` (CRITIQUE - principale table)
-- ============================================================================

-- DOUBLON DETECTION (déjà UNIQUE dans DDL)
-- Composite key : (source_id, id_externe) = Garantit pas doublon
-- Performance : O(1) lookup avant INSERT
-- ⚠️ CRITIQUE - c'est le cœur de la validation données

-- Index sur source_id (pour filtrer annonces par source)
-- Utilisé pour : "annonces de data.gouv.fr"
CREATE INDEX idx_annonces_source_id ON annonces (source_id);

-- Index sur acheteur_id (pour filtrer annonces par acheteur)
-- Utilisé pour : "annonces de la Ville de Paris"
CREATE INDEX idx_annonces_acheteur_id ON annonces (acheteur_id);

-- Index sur date_publication (pour recherches chronologiques)
-- Utilisé pour : "annonces publiées en 2026-04"
CREATE INDEX idx_annonces_date_publication ON annonces (date_publication);

-- Index sur date_limite_reponse (⚠️ TRÈS IMPORTANT pour urgence)
-- Utilisé pour : "annonces deadline < 7 jours"
-- ⚠️ CRITIQUE pour trouver annonces urgentes
CREATE INDEX idx_annonces_date_limite_reponse ON annonces (date_limite_reponse);

-- Index sur region (pour filtrage géographique)
-- Utilisé pour : "annonces en Île-de-France"
-- ⚠️ IMPORTANT pour dashboards régionaux
CREATE INDEX idx_annonces_region ON annonces (region);

-- Index sur statut (pour filtrer NEW vs QUALIFIED vs IGNORED vs RESPONDED)
-- Utilisé pour : "annonces non traitées (NEW)"
CREATE INDEX idx_annonces_statut ON annonces (statut);

-- Index sur montant_estime (pour recherches montant > X)
-- Utilisé pour : "annonces > 100k€"
CREATE INDEX idx_annonces_montant_estime ON annonces (montant_estime);

-- Index composite : region + date_limite_reponse (requêtes combinées urgentes)
-- Utilisé pour : "annonces urgentes en Île-de-France"
-- ⚠️ TRÈS IMPORTANT pour dashboards régionaux urgents
CREATE INDEX idx_annonces_region_deadline ON annonces (region, date_limite_reponse DESC);

-- Index composite : montant + date_limite (recherches montant urgent)
-- Utilisé pour : "gros montants avec deadline proche"
CREATE INDEX idx_annonces_montant_deadline ON annonces (montant_estime DESC, date_limite_reponse);

-- Index composite : statut + date_limite (annonces non traitées urgentes)
-- Utilisé pour : "annonces NEW/QUALIFIED avec deadline < 14j"
CREATE INDEX idx_annonces_statut_deadline ON annonces (statut, date_limite_reponse);

-- Index sur timestamp_import (pour recherche par date import)
-- Utilisé pour : "annonces importées aujourd'hui"
CREATE INDEX idx_annonces_timestamp_import ON annonces (timestamp_import);

-- Index sur timestamp_maj (pour audit modifications)
-- Utilisé pour : "annonces modifiées depuis hier"
CREATE INDEX idx_annonces_timestamp_maj ON annonces (timestamp_maj);

-- ============================================================================
-- SECTION 5 : INDEXES SUR TABLE `annonce_mot_cle` (Liaison N:N)
-- ============================================================================

-- Index sur mot_cle_id (pour recherche inverse : "toutes annonces avec keyword X")
-- Utilisé pour : "annonces contenant modulaire"
-- ⚠️ IMPORTANT pour recherche keywords
CREATE INDEX idx_amc_mot_cle_id ON annonce_mot_cle (mot_cle_id);

-- Index sur pertinence_score (pour recherche keywords pertinents)
-- Utilisé pour : "keywords trouvés avec score > 70"
CREATE INDEX idx_amc_pertinence_score ON annonce_mot_cle (pertinence_score);

-- Index composite : mot_cle_id + pertinence_score (keywords pertinents)
-- Utilisé pour : "annonces avec 'modulaire' (score >= 80)"
CREATE INDEX idx_amc_mot_cle_pertinence ON annonce_mot_cle (mot_cle_id, pertinence_score DESC);

-- Index sur type_extraction (pour audit extraction)
-- Utilisé pour : "keywords trouvés via REGEX vs TF-IDF"
CREATE INDEX idx_amc_type_extraction ON annonce_mot_cle (type_extraction);

-- ============================================================================
-- SECTION 6 : INDEXES SUR TABLE `qualification_scores`
-- ============================================================================

-- Index sur score_pertinence (pour recherche score > X)
-- Utilisé pour : "annonces score > 70"
CREATE INDEX idx_qs_score_pertinence ON qualification_scores (score_pertinence);

-- Index sur niveau_alerte (⚠️ CRITIQUE pour dashboards urgentes)
-- Utilisé pour : "toutes annonces CRITIQUE", "toutes annonces URGENT"
-- ⚠️ TRÈS IMPORTANT - requête fréquente
CREATE INDEX idx_qs_niveau_alerte ON qualification_scores (niveau_alerte);

-- Index composite : niveau_alerte + score (pour tri par urgence)
-- Utilisé pour : "annonces CRITIQUE triées par score DESC"
CREATE INDEX idx_qs_alerte_score ON qualification_scores (niveau_alerte, score_pertinence DESC);

-- ============================================================================
-- SECTION 7 : INDEXES SUR TABLE `notifications`
-- ============================================================================

-- Index sur statut (pour filtrer alertes à envoyer)
-- Utilisé pour : "notifications NEW à envoyer"
CREATE INDEX idx_notif_statut ON notifications (statut);

-- Index sur priorite (pour tri par urgence)
-- Utilisé pour : "notifications triées par priorite ASC"
CREATE INDEX idx_notif_priorite ON notifications (priorite);

-- Index sur date_creation (pour recherche par période)
-- Utilisé pour : "notifications créées hier"
CREATE INDEX idx_notif_date_creation ON notifications (date_creation);

-- Index composite : statut + priorite (notifications urgentes à envoyer)
-- Utilisé pour : "notifications NEW triées par priorite (maxurant en first)"
CREATE INDEX idx_notif_statut_priorite ON notifications (statut, priorite);

-- ============================================================================
-- SECTION 8 : INDEXES SUR TABLE `log_technique`
-- ============================================================================

-- Index sur timestamp (recherche par période)
-- Utilisé pour : "logs des 24 dernières heures"
CREATE INDEX idx_log_tech_timestamp ON log_technique (timestamp);

-- Index sur type_operation (pour filtrer erreurs type)
-- Utilisé pour : "erreurs IMPORT seulement"
CREATE INDEX idx_log_tech_type_operation ON log_technique (type_operation);

-- Index sur status (pour filtrer erreurs)
-- Utilisé pour : "toutes opérations ERREUR"
CREATE INDEX idx_log_tech_status ON log_technique (status);

-- Index composite : status + timestamp (erreurs récentes)
-- Utilisé pour : "erreurs de l'heure passée"
CREATE INDEX idx_log_tech_status_timestamp ON log_technique (status, timestamp DESC);

-- ============================================================================
-- SECTION 9 : INDEXES SUR TABLE `log_metier`
-- ============================================================================

-- Index sur annonce_id (pour recherche historique annonce)
-- Utilisé pour : "historique métier de l'annonce #12345"
CREATE INDEX idx_log_metier_annonce_id ON log_metier (annonce_id);

-- Index sur timestamp (recherche par période)
-- Utilisé pour : "logs métier d'aujourd'hui"
CREATE INDEX idx_log_metier_timestamp ON log_metier (timestamp);

-- Index sur type_operation (pour filtrer modifications type)
-- Utilisé pour : "tous changements de statut"
CREATE INDEX idx_log_metier_type_operation ON log_metier (type_operation);

-- Index composite : annonce_id + timestamp (historique chronologique)
-- Utilisé pour : "modifications de l'annonce #12345 triées chrono"
CREATE INDEX idx_log_metier_annonce_timestamp ON log_metier (annonce_id, timestamp DESC);

-- ============================================================================
-- SECTION 10 : INDEXES SUR TABLE `historique_annonces`
-- ============================================================================

-- Index sur annonce_id (pour recherche version control)
-- Utilisé pour : "historique colonne-par-colonne de l'annonce #12345"
CREATE INDEX idx_hist_annonce_id ON historique_annonces (annonce_id);

-- Index sur timestamp (recherche par période)
-- Utilisé pour : "modifications des 7 derniers jours"
CREATE INDEX idx_hist_timestamp ON historique_annonces (timestamp);

-- Index composite : annonce_id + timestamp (version control chronologique)
-- Utilisé pour : "versions de l'annonce #12345 triées chrono"
CREATE INDEX idx_hist_annonce_timestamp ON historique_annonces (annonce_id, timestamp DESC);

-- ============================================================================
-- SECTION 11 : INDEXES SUR TABLE `log_sauvegardes`
-- ============================================================================

-- Index sur timestamp (recherche dernier backup)
-- Utilisé pour : "dernier backup exécuté"
CREATE INDEX idx_log_sauv_timestamp ON log_sauvegardes (timestamp DESC);

-- Index sur status (pour filtrer erreurs backup)
-- Utilisé pour : "backups en erreur"
CREATE INDEX idx_log_sauv_status ON log_sauvegardes (status);

-- Index composite : status + timestamp (erreurs récentes)
-- Utilisé pour : "backups en erreur du mois dernier"
CREATE INDEX idx_log_sauv_status_timestamp ON log_sauvegardes (status, timestamp DESC);

-- ============================================================================
-- VÉRIFICATION : Comptage indexes créés
-- ============================================================================

SELECT 
  'SUCCÈS : Indexes stratégiques créés' as message,
  COUNT(*) as nombre_indexes
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND index_name != 'PRIMARY';

-- ============================================================================
-- STATISTIQUES INDEXES (pour info)
-- ============================================================================

SHOW INDEX FROM sources;
SHOW INDEX FROM acheteurs;
SHOW INDEX FROM mots_cles;
SHOW INDEX FROM annonces;
SHOW INDEX FROM annonce_mot_cle;
SHOW INDEX FROM qualification_scores;
SHOW INDEX FROM notifications;
SHOW INDEX FROM log_technique;
SHOW INDEX FROM log_metier;
SHOW INDEX FROM historique_annonces;
SHOW INDEX FROM log_sauvegardes;

-- ============================================================================
-- FIN SCRIPT 03_create_indexes.sql
-- ============================================================================
-- BILAN INDEXES :
-- - ~55 indexes totaux (y compris PKs + FKs + UNIQUE keys)
-- - ~20 indexes stratégiques créés par ce script
-- - Performance : Requêtes de recherche rapides (O(log n) au lieu O(n))
-- - Trade-off : Espace disque +5-10% (acceptable)
--
-- INDEXES CRITIQUES POUR PERFORMANCE :
-- 1. annonces.idx_annonces_date_limite_reponse (trouvez urgentes)
-- 2. annonces.idx_annonces_region_deadline (urgent par région)
-- 3. qualification_scores.idx_qs_niveau_alerte (dashboards alerte)
-- 4. annonce_mot_cle.idx_amc_mot_cle_id (recherche keywords)
-- 5. annonces.UNIQUE(source_id, id_externe) (doublon detection O(1))
--
-- Prochaines étapes :
-- 1. Exécuter 04_create_base_data.sql (données initiales)
-- 2. Tester requêtes de performance
-- 3. Procéder aux scripts J4 (functions, procedures, triggers)
-- ============================================================================
