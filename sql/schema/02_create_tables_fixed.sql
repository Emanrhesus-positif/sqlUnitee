-- ============================================================================
-- UNITEE - SCRIPT DE CRÉATION COMPLÈTE DE SCHÉMA
-- Projet : Veille Automatisée des Marchés Publics (Bâtiment Modulaire)
-- Date : 2026-04-08
-- Version : 1.0
-- 
-- UTILISATION :
--   mysql -u root -p < 02_create_tables.sql
-- ou
--   SOURCE /path/to/02_create_tables.sql;  (dans MySQL prompt)
--
-- NOTE : Ce script crée TOUTES les tables avec contraintes complètes.
-- Indexes stratégiques sont dans 03_create_indexes.sql
-- Données initiales sont dans 04_create_base_data.sql
-- ============================================================================

-- ============================================================================
-- 1. TABLE : SOURCES (Référence des sources de données)
-- ============================================================================
CREATE TABLE IF NOT EXISTS sources (
  id_source INT PRIMARY KEY AUTO_INCREMENT COMMENT 'Identifiant unique source',
  nom_source VARCHAR(100) UNIQUE NOT NULL COMMENT 'Nom unique (data.gouv.fr, BOAMP, synthetic)',
  description TEXT COMMENT 'Description source, usage, limitations',
  url_base VARCHAR(500) COMMENT 'URL base API (https://www.data.gouv.fr/api/1/)',
  type_source ENUM('API','SCRAPING','FLUX_RSS') DEFAULT 'API' COMMENT 'Type : REST API, web scraping, ou RSS feed',
  actif BOOLEAN DEFAULT true COMMENT 'Flag : source active ou désactivée',
  date_creation DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Audit : date création source'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Table SOURCES - Enregistre les 3-5 sources de données';

-- ============================================================================
-- 2. TABLE : ACHETEURS (Référence des acheteurs publics)
-- ============================================================================
CREATE TABLE IF NOT EXISTS acheteurs (
  id_acheteur INT PRIMARY KEY AUTO_INCREMENT COMMENT 'Identifiant unique acheteur',
  nom_acheteur VARCHAR(255) UNIQUE NOT NULL COMMENT 'Nom officiel (ex: Ville de Paris, SNCF)',
  type_acheteur ENUM('COLLECTIVITE','ETAT','ENTREPRISE_PUBLIQUE') COMMENT 'Catégorisation',
  region VARCHAR(100) COMMENT 'Région siège social (pour stats géographiques)',
  contact_email VARCHAR(255) COMMENT 'Email contact (optionnel)',
  contact_phone VARCHAR(20) COMMENT 'Téléphone contact (optionnel)',
  date_creation DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Audit : date création'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Table ACHETEURS - Référence des acheteurs publics français';

-- ============================================================================
-- 3. TABLE : MOTS_CLES (Catalogue de keywords pertinents)
-- ============================================================================
CREATE TABLE IF NOT EXISTS mots_cles (
  id_mot_cle INT PRIMARY KEY AUTO_INCREMENT COMMENT 'Identifiant unique keyword',
  mot_cle VARCHAR(100) UNIQUE NOT NULL COMMENT 'Keyword exact (modulaire, préfabriqué, etc)',
  categorie ENUM('PRIMARY','SECONDARY','EXTRACTED') DEFAULT 'EXTRACTED' COMMENT 'Type : PRIMARY/SECONDARY (config.yaml) ou EXTRACTED (TF-IDF J3)',
  pertinence INT CHECK (pertinence >= 0 AND pertinence <= 100) DEFAULT 50 COMMENT 'Score pertinence défaut 0-100',
  date_creation DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Audit : date découverte keyword'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Table MOTS_CLES - Catalogue keywords pertinents';

-- ============================================================================
-- 4. TABLE : ANNONCES (PRINCIPALE - Cœur métier)
-- ============================================================================
CREATE TABLE IF NOT EXISTS annonces (
  id_annonce BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT 'Identifiant unique annonce (support 8+ milliards)',
  source_id INT NOT NULL COMMENT 'Référence source (data.gouv.fr, BOAMP, synthetic)',
  acheteur_id INT NOT NULL COMMENT 'Référence acheteur public',
  id_externe VARCHAR(100) NOT NULL COMMENT 'ID fourni par source (ex: GOV_12345)',
  titre VARCHAR(500) NOT NULL COMMENT 'Titre annonce (min 6 caractères)',
  resume TEXT COMMENT 'Résumé court',
  description LONGTEXT COMMENT 'Description complète (peut être très longue)',
  montant_estime DECIMAL(15,2) COMMENT 'Montant estimé EUR (0 = non communiqué)',
  devise VARCHAR(3) DEFAULT 'EUR' COMMENT 'Devise (EUR défaut, extensible)',
  date_publication DATETIME NOT NULL COMMENT 'Date publication officielle',
  date_limite_reponse DATETIME NOT NULL COMMENT 'Deadline réponse (CRUCIAL pour urgence)',
  localisation VARCHAR(255) COMMENT 'Lieu exécution travaux',
  region VARCHAR(100) COMMENT 'Région France (pour filtrage/stats)',
  lien_source VARCHAR(500) UNIQUE COMMENT 'URL source (1 lien = 1 annonce max)',
  statut ENUM('NEW','QUALIFIED','IGNORED','RESPONDED') DEFAULT 'NEW' COMMENT 'Statut traitement',
  timestamp_import DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Audit : date import',
  timestamp_maj DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Audit : dernière modification',
  
  CONSTRAINT fk_annonces_source 
    FOREIGN KEY (source_id) REFERENCES sources(id_source)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_annonces_acheteur 
    FOREIGN KEY (acheteur_id) REFERENCES acheteurs(id_acheteur)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT uk_annonce_doublon 
    UNIQUE (source_id, id_externe),
  
  CONSTRAINT ck_titre_length
    CHECK (CHAR_LENGTH(titre) > 5),
  
  CONSTRAINT ck_montant_positif
    CHECK (montant_estime IS NULL OR montant_estime >= 0),
  
  CONSTRAINT ck_dates_annonce 
    CHECK (date_publication <= date_limite_reponse)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Table ANNONCES - PRINCIPALE table métier';

-- ============================================================================
-- 5. TABLE : ANNONCE_MOT_CLE (Liaison N:N)
-- ============================================================================
CREATE TABLE IF NOT EXISTS annonce_mot_cle (
  annonce_id BIGINT NOT NULL COMMENT 'Référence annonce',
  mot_cle_id INT NOT NULL COMMENT 'Référence mot-clé',
  pertinence_score INT CHECK (pertinence_score >= 0 AND pertinence_score <= 100) DEFAULT 50 COMMENT 'Score contextuel (90=titre, 40=description)',
  type_extraction ENUM('TF-IDF','REGEX','MANUAL','LLM') DEFAULT 'REGEX' COMMENT 'Audit : REGEX/TF-IDF/MANUAL/LLM',
  date_extraction DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Audit : date extraction',
  
  PRIMARY KEY (annonce_id, mot_cle_id),
  
  CONSTRAINT fk_amc_annonce 
    FOREIGN KEY (annonce_id) REFERENCES annonces(id_annonce)
    ON DELETE CASCADE ON UPDATE CASCADE,
  
  CONSTRAINT fk_amc_mot_cle 
    FOREIGN KEY (mot_cle_id) REFERENCES mots_cles(id_mot_cle)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Table ANNONCE_MOT_CLE - Liaison N:N';

-- ============================================================================
-- 6. TABLE : QUALIFICATION_SCORES (Scoring pertinence 1:1)
-- ============================================================================
CREATE TABLE IF NOT EXISTS qualification_scores (
  id_score INT PRIMARY KEY AUTO_INCREMENT COMMENT 'Identifiant unique score',
  annonce_id BIGINT UNIQUE NOT NULL COMMENT 'FK annonce (1:1 relation)',
  score_pertinence INT NOT NULL CHECK (score_pertinence >= 0 AND score_pertinence <= 100) COMMENT 'Score final 0-100',
  niveau_alerte ENUM('CRITIQUE','URGENT','NORMAL','IGNORE') DEFAULT 'NORMAL' COMMENT 'Dérivé : CRITIQUE (>75+<7j), URGENT (>60+<14j), NORMAL (>50), IGNORE (<=50)',
  raison_scoring TEXT COMMENT 'Description raisons du score',
  bonus_keywords INT DEFAULT 0 COMMENT 'Points bonus keywords trouvés',
  bonus_montant INT DEFAULT 0 COMMENT 'Points bonus montant estimé',
  bonus_deadline INT DEFAULT 0 COMMENT 'Points bonus urgence (deadline proche)',
  bonus_acheteur INT DEFAULT 0 COMMENT 'Points bonus acheteur favorable',
  date_calcul DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Audit : date calcul',
  date_maj DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Audit : dernière recalculation',
  
  CONSTRAINT fk_score_annonce 
    FOREIGN KEY (annonce_id) REFERENCES annonces(id_annonce)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Table QUALIFICATION_SCORES - Scoring pertinence 1:1';

-- ============================================================================
-- 7. TABLE : NOTIFICATIONS (Alertes)
-- ============================================================================
CREATE TABLE IF NOT EXISTS notifications (
  id_notification BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT 'Identifiant unique notification',
  annonce_id BIGINT NOT NULL COMMENT 'Référence annonce',
  type_alerte VARCHAR(50) NOT NULL COMMENT 'Type (NEW_OPPORTUNITY, DEADLINE_CRITICAL, etc)',
  statut ENUM('NEW','SENT','ACKNOWLEDGED','ARCHIVED') DEFAULT 'NEW' COMMENT 'Pipeline : NEW->SENT->ACKNOWLEDGED->ARCHIVED',
  priorite INT DEFAULT 3 CHECK (priorite >= 1 AND priorite <= 5) COMMENT '1=urgent, 5=basse (pour tri queue)',
  date_creation DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Quand alerte créée',
  date_envoi DATETIME COMMENT 'Quand alerte envoyée (NULL=pas encore)',
  date_acknowledge DATETIME COMMENT 'Quand utilisateur confirmé (NULL=pas encore)',
  message LONGTEXT COMMENT 'Contenu alerte (ex: email body)',
  
  CONSTRAINT fk_notif_annonce 
    FOREIGN KEY (annonce_id) REFERENCES annonces(id_annonce)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Table NOTIFICATIONS - Alertes générées';

-- ============================================================================
-- 8. TABLE : LOG_TECHNIQUE (Audit technique - rétention 90j)
-- ============================================================================
CREATE TABLE IF NOT EXISTS log_technique (
  id_log_tech BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT 'Identifiant unique log',
  timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Quand opération exécutée',
  type_operation VARCHAR(100) NOT NULL COMMENT 'Ex: IMPORT_API_DATA_GOUV, SCORE_CALCULATION, BACKUP_FULL',
  source_operation VARCHAR(100) COMMENT 'Ex: notebook_j2_extraction, trigger_after_insert',
  status ENUM('OK','WARNING','ERREUR') DEFAULT 'OK' COMMENT 'Résultat opération',
  message TEXT COMMENT 'Message humain (ex: API timeout retry 2/3)',
  details_json JSON COMMENT 'Flex données structure variable (stack trace, HTTP status, etc)',
  duree_ms INT COMMENT 'Durée opération (monitoring performance)'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Table LOG_TECHNIQUE - Logs techniques (rétention 90 jours)';

-- ============================================================================
-- 9. TABLE : LOG_METIER (Audit métier - historique complet)
-- ============================================================================
CREATE TABLE IF NOT EXISTS log_metier (
  id_log_metier BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT 'Identifiant unique log',
  annonce_id BIGINT NOT NULL COMMENT 'Annonce concernée',
  timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Quand changement',
  type_operation VARCHAR(100) NOT NULL COMMENT 'STATUT_CHANGE, SCORE_RECALC, KEYWORD_ADD, etc',
  utilisateur VARCHAR(255) COMMENT 'Qui a fait changement (système ou humain)',
  description TEXT COMMENT 'Raison changement',
  avant_state JSON COMMENT 'État avant changement (ex: {"statut":"NEW"})',
  apres_state JSON COMMENT 'État après changement (ex: {"statut":"QUALIFIED"})',
  
  CONSTRAINT fk_logmetier_annonce 
    FOREIGN KEY (annonce_id) REFERENCES annonces(id_annonce)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Table LOG_METIER - Historique modifications métier (complet)';

-- ============================================================================
-- 10. TABLE : HISTORIQUE_ANNONCES (Version control - RGPD compliance)
-- ============================================================================
CREATE TABLE IF NOT EXISTS historique_annonces (
  id_historique BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT 'Identifiant unique historique',
  annonce_id BIGINT NOT NULL COMMENT 'Annonce concernée',
  timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Quand modification',
  type_modification VARCHAR(100) COMMENT 'INSERT, UPDATE, DELETE',
  colonne_modifiee VARCHAR(100) COMMENT 'Quelle colonne changée (ex: statut, score)',
  valeur_ancienne TEXT COMMENT 'Valeur avant modification',
  valeur_nouvelle TEXT COMMENT 'Valeur après modification',
  
  CONSTRAINT fk_hist_annonce 
    FOREIGN KEY (annonce_id) REFERENCES annonces(id_annonce)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Table HISTORIQUE_ANNONCES - Version control RGPD (complet)';

-- ============================================================================
-- 11. TABLE : LOG_SAUVEGARDES (Backup audit - traçabilité RTO/RPO)
-- ============================================================================
CREATE TABLE IF NOT EXISTS log_sauvegardes (
  id_log_sauvegarde INT PRIMARY KEY AUTO_INCREMENT COMMENT 'Identifiant unique backup log',
  timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Quand backup effectué',
  type_backup ENUM('FULL','INCREMENTAL') DEFAULT 'FULL' COMMENT 'FULL (complet) ou INCREMENTAL (différentiel)',
  fichier VARCHAR(500) NOT NULL COMMENT 'Chemin fichier backup généré',
  status ENUM('OK','ERREUR') DEFAULT 'OK' COMMENT 'Succès ou erreur',
  nb_bytes BIGINT COMMENT 'Taille fichier backup',
  duree_secondes INT COMMENT 'Durée backup (secondes)',
  message_erreur TEXT COMMENT 'Si erreur, raison failure'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Table LOG_SAUVEGARDES - Backup audit (RTO/RPO)';

-- ============================================================================
-- VÉRIFICATION : Comptage tables créées
-- ============================================================================

SELECT 
  'SUCCÈS : Toutes 11 tables créées' as message,
  COUNT(*) as nombre_tables
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN (
    'sources', 'acheteurs', 'mots_cles', 'annonces',
    'annonce_mot_cle', 'qualification_scores', 'notifications',
    'log_technique', 'log_metier', 'historique_annonces', 'log_sauvegardes'
  );

-- ============================================================================
-- FIN SCRIPT 02_create_tables.sql
-- ============================================================================
