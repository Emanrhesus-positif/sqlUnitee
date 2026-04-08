# SCHÉMA BASE DE DONNÉES UNITEE - Documentation Complète

## Vue d'ensemble

Le schéma UNITEE est une base de données relationnelle MySQL 8.0+ conçue pour la surveillance automatisée des marchés publics français dans le secteur du bâtiment modulaire. Il comprend **11 tables** organisées en 4 catégories :
- **4 tables métier** : cœur du système
- **1 table liaison** (N:N) : associations keywords-annonces
- **2 tables qualification** : scoring et notifications
- **4 tables techniques** : logs et audit

---

## Architecture Globale

### Principes de Conception

1. **Normalisation 3FN/BCNF** : Élimination redondances, intégrité référentielle stricte
2. **Clés composites** : `(source_id, id_externe)` pour doublon detection au niveau DB
3. **Contraintes métier** : Validations au niveau base (CHECK, UNIQUE, FOREIGN KEY)
4. **Indexes stratégiques** : ~20 indexes pour recherches fréquentes (dates, montant, région)
5. **Audit complet** : Historiques techniques et métier conservés séparément
6. **Flexibilité JSON** : Colonnes JSON pour extensibilité (erreurs API, détails mémo)

### Configuration MySQL

```sql
-- Charset & Collation (support Unicode complet)
DEFAULT CHARSET utf8mb4
DEFAULT COLLATE utf8mb4_unicode_ci

-- Mode strict (rejette données invalides)
SQL_MODE = 'STRICT_TRANS_TABLES'

-- Storage Engine (ACID transactions)
ENGINE = InnoDB
```

---

## Tables Détaillées

### TABLE 1 : `sources` (Référence)

**Rôle** : Enregistre les sources de données (APIs, scraping, flux RSS)

```sql
CREATE TABLE sources (
  id_source INT PRIMARY KEY AUTO_INCREMENT,
  nom_source VARCHAR(100) UNIQUE NOT NULL,
  description TEXT,
  url_base VARCHAR(500),
  type_source ENUM('API','SCRAPING','FLUX_RSS') DEFAULT 'API',
  actif BOOLEAN DEFAULT true,
  date_creation DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

| Colonne | Type | Justification |
|---------|------|---------------|
| `id_source` | INT PK | Identifiant unique auto-incrémenté |
| `nom_source` | VARCHAR(100) UNIQUE | Nom unique : "data.gouv.fr", "BOAMP", "synthétique" |
| `description` | TEXT | Documentation sur la source (optionnel) |
| `url_base` | VARCHAR(500) | URL de base API (ex: https://www.data.gouv.fr/api/1/) |
| `type_source` | ENUM | API, scraping web, ou flux RSS (extensible future) |
| `actif` | BOOLEAN | Flag pour désactiver source sans suppression |
| `date_creation` | DATETIME | Audit : quand source ajoutée |

**Données initiales requises** :
- `data.gouv.fr` - API REST données gouvernementales
- `BOAMP` - BOAMP API ou scraping
- `synthetic` - Données test/fallback

**Cardinalité** : ~3-5 sources permanentes + sources test

---

### TABLE 2 : `acheteurs` (Référence)

**Rôle** : Enregistre les acheteurs publics (collectivités, État, entreprises publiques)

```sql
CREATE TABLE acheteurs (
  id_acheteur INT PRIMARY KEY AUTO_INCREMENT,
  nom_acheteur VARCHAR(255) UNIQUE NOT NULL,
  type_acheteur ENUM('COLLECTIVITE','ETAT','ENTREPRISE_PUBLIQUE'),
  region VARCHAR(100),
  contact_email VARCHAR(255),
  contact_phone VARCHAR(20),
  date_creation DATETIME DEFAULT CURRENT_TIMESTAMP,
  
  INDEX idx_region (region),
  INDEX idx_type (type_acheteur)
);
```

| Colonne | Type | Justification |
|---------|------|---------------|
| `id_acheteur` | INT PK | Identifiant unique |
| `nom_acheteur` | VARCHAR(255) UNIQUE | Nom officiel acheteur (ex: "Ville de Paris", "SNCF") |
| `type_acheteur` | ENUM | Catégorisation pour filtering/scoring |
| `region` | VARCHAR(100) | Région siège social (pour stats géographiques) |
| `contact_email` | VARCHAR(255) | Email contact (optionnel, pour notifications futures) |
| `contact_phone` | VARCHAR(20) | Téléphone contact (optionnel) |
| `date_creation` | DATETIME | Audit |

**Indexes** :
- `idx_region` : Recherche par région (pour dashboards)
- `idx_type` : Recherche par type acheteur

**Cardinalité** : Croissance lente (1,000-10,000 acheteurs possibles sur 1 an)

---

### TABLE 3 : `mots_cles` (Référence)

**Rôle** : Catalogue des mots-clés de recherche (keywords pertinents + extracted)

```sql
CREATE TABLE mots_cles (
  id_mot_cle INT PRIMARY KEY AUTO_INCREMENT,
  mot_cle VARCHAR(100) UNIQUE NOT NULL,
  categorie ENUM('PRIMARY','SECONDARY','EXTRACTED') DEFAULT 'EXTRACTED',
  pertinence INT CHECK (pertinence >= 0 AND pertinence <= 100) DEFAULT 50,
  date_creation DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

| Colonne | Type | Justification |
|---------|------|---------------|
| `id_mot_cle` | INT PK | Identifiant unique |
| `mot_cle` | VARCHAR(100) UNIQUE | Keyword exact (ex: "modulaire", "préfabriqué") |
| `categorie` | ENUM | PRIMARY (config.yaml), SECONDARY (config.yaml), ou EXTRACTED (découverts via TF-IDF J3) |
| `pertinence` | INT 0-100 | Score pertinence par défaut (utilisé si mot trouvé sans contexte) |
| `date_creation` | DATETIME | Audit : quand keyword découvert |

**Données initiales** (à partir `config.yaml`) :
- **PRIMARY** : modulaire, préfabriqué, assemblage rapide, bâtiment en kit, base vie
- **SECONDARY** : extension, classe temporaire, structure préfabriquée, construction modulaire, bâtiment rapide
- **EXTRACTED** : À remplir J3 via analyse TF-IDF

**Cardinalité** : ~50-200 mots-clés (en croissance avec découvertes)

---

### TABLE 4 : `annonces` (PRINCIPALE - Business Core)

**Rôle** : Stockage des annonces de marchés publics extraites des sources

```sql
CREATE TABLE annonces (
  id_annonce BIGINT PRIMARY KEY AUTO_INCREMENT,
  
  -- Références externes
  source_id INT NOT NULL,
  acheteur_id INT NOT NULL,
  id_externe VARCHAR(100) NOT NULL,
  
  -- Contenu
  titre VARCHAR(500) NOT NULL CHECK (CHAR_LENGTH(titre) > 5),
  resume TEXT,
  description LONGTEXT,
  montant_estime DECIMAL(15,2) CHECK (montant_estime >= 0),
  devise VARCHAR(3) DEFAULT 'EUR',
  
  -- Dates
  date_publication DATETIME NOT NULL,
  date_limite_reponse DATETIME NOT NULL,
  
  -- Localisation
  localisation VARCHAR(255),
  region VARCHAR(100),
  lien_source TEXT UNIQUE,
  
  -- Métadonnées
  statut ENUM('NEW','QUALIFIED','IGNORED','RESPONDED') DEFAULT 'NEW',
  timestamp_import DATETIME DEFAULT CURRENT_TIMESTAMP,
  timestamp_maj DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  -- Contraintes intégrité
  CONSTRAINT fk_annonces_source 
    FOREIGN KEY (source_id) REFERENCES sources(id_source)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_annonces_acheteur 
    FOREIGN KEY (acheteur_id) REFERENCES acheteurs(id_acheteur)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT uk_annonce_doublon 
    UNIQUE (source_id, id_externe),
  
  CONSTRAINT ck_dates_annonce 
    CHECK (date_publication <= date_limite_reponse),
  
  -- Indexes recherche
  INDEX idx_source_id (source_id),
  INDEX idx_acheteur_id (acheteur_id),
  INDEX idx_date_pub (date_publication),
  INDEX idx_date_deadline (date_limite_reponse),
  INDEX idx_region (region),
  INDEX idx_statut (statut),
  INDEX idx_montant (montant_estime)
);
```

| Colonne | Type | Justification |
|---------|------|---------------|
| `id_annonce` | BIGINT PK | ID unique base, support 8+ milliards enregistrements |
| `source_id` | INT FK | Référence source (data.gouv.fr, BOAMP, etc.) |
| `acheteur_id` | INT FK | Référence acheteur public |
| `id_externe` | VARCHAR(100) | ID fourni par source (ex: "GOV_12345") |
| `titre` | VARCHAR(500) CHK | Min 6 caractères (rejette titres garbage) |
| `resume` | TEXT | Résumé court annonce |
| `description` | LONGTEXT | Contenu complet (peut être très long) |
| `montant_estime` | DECIMAL(15,2) CHK | Montant EUR, ≥ 0€ |
| `devise` | VARCHAR(3) | EUR par défaut (extensible future) |
| `date_publication` | DATETIME | Date de publication officielle |
| `date_limite_reponse` | DATETIME | Deadline réponse (crucial pour urgence) |
| `localisation` | VARCHAR(255) | Lieu exécution travaux |
| `region` | VARCHAR(100) | Région France (pour filtrage/stats) |
| `lien_source` | TEXT UNIQUE | URL source (1 lien = 1 annonce max) |
| `statut` | ENUM | NEW, QUALIFIED, IGNORED, RESPONDED |
| `timestamp_import` | DATETIME | Audit : quand importée |
| `timestamp_maj` | DATETIME | Audit : dernière modification |

**Contraintes Critiques** :
- `UNIQUE (source_id, id_externe)` : **Détection doublon au niveau DB** (pas besoin logique applicative)
- `CHECK (montant >= 0)` : Rejette montants négatifs
- `CHECK (date_pub <= deadline)` : Logique métier validée
- `CHECK (titre LENGTH > 5)` : Évite données garbage

**Indexes Stratégiques** :
- `idx_source_id` : Recherche par source
- `idx_acheteur_id` : Recherche par acheteur
- `idx_date_pub`, `idx_date_deadline` : **CRITIQUE** pour urgence (J-7, J-14)
- `idx_region` : Recherche géographique
- `idx_statut` : Filtrer annonces traitées
- `idx_montant` : Requêtes montant > X

**Cardinalité** : 50-500 annonces/jour → ~18,000-180,000/an (croissance linéaire)

**Storage** : ~500 bytes/annonce moyenne → ~9-90 MB/an (petit tableau)

---

### TABLE 5 : `annonce_mot_cle` (LIAISON N:N)

**Rôle** : Associe annonces ↔ mots-clés (plusieurs keywords par annonce)

```sql
CREATE TABLE annonce_mot_cle (
  annonce_id BIGINT NOT NULL,
  mot_cle_id INT NOT NULL,
  
  pertinence_score INT CHECK (pertinence_score >= 0 AND pertinence_score <= 100) DEFAULT 50,
  type_extraction ENUM('TF-IDF','REGEX','MANUAL','LLM') DEFAULT 'REGEX',
  date_extraction DATETIME DEFAULT CURRENT_TIMESTAMP,
  
  PRIMARY KEY (annonce_id, mot_cle_id),
  
  CONSTRAINT fk_amc_annonce 
    FOREIGN KEY (annonce_id) REFERENCES annonces(id_annonce)
    ON DELETE CASCADE ON UPDATE CASCADE,
  
  CONSTRAINT fk_amc_mot_cle 
    FOREIGN KEY (mot_cle_id) REFERENCES mots_cles(id_mot_cle)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  INDEX idx_mot_cle_id (mot_cle_id),
  INDEX idx_pertinence (pertinence_score)
);
```

| Colonne | Type | Justification |
|---------|------|---------------|
| `annonce_id` | BIGINT FK | Référence annonce |
| `mot_cle_id` | INT FK | Référence keyword |
| `pertinence_score` | INT 0-100 | Score contextuel (ex: keyword titre = 90, description = 40) |
| `type_extraction` | ENUM | **Audit d'extraction** : REGEX (rapide), TF-IDF (ML), MANUAL (humain), LLM (future) |
| `date_extraction` | DATETIME | Audit : quand extraction faite |

**PK Composite** : `(annonce_id, mot_cle_id)` → 1 seule association par paire

**On DELETE CASCADE** : Si annonce supprimée, associations auto-nettoyées

**Indexes** :
- `idx_mot_cle_id` : Recherche "annonces avec keyword X"
- `idx_pertinence` : Recherche "annonces avec score > 70"

**Cardinalité** : ~3-5 keywords/annonce → 150,000-900,000 lignes/an

---

### TABLE 6 : `qualification_scores` (Scoring)

**Rôle** : Score pertinence complexe pour chaque annonce (1:1 avec annonces)

```sql
CREATE TABLE qualification_scores (
  id_score INT PRIMARY KEY AUTO_INCREMENT,
  annonce_id BIGINT UNIQUE NOT NULL,
  
  -- Score global
  score_pertinence INT NOT NULL CHECK (score_pertinence >= 0 AND score_pertinence <= 100),
  niveau_alerte ENUM('CRITIQUE','URGENT','NORMAL','IGNORE') DEFAULT 'NORMAL',
  
  -- Audit scoring
  raison_scoring TEXT,
  bonus_keywords INT DEFAULT 0,
  bonus_montant INT DEFAULT 0,
  bonus_deadline INT DEFAULT 0,
  bonus_acheteur INT DEFAULT 0,
  
  -- Dates
  date_calcul DATETIME DEFAULT CURRENT_TIMESTAMP,
  date_maj DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  CONSTRAINT fk_score_annonce 
    FOREIGN KEY (annonce_id) REFERENCES annonces(id_annonce)
    ON DELETE CASCADE ON UPDATE CASCADE,
  
  INDEX idx_score_pertinence (score_pertinence),
  INDEX idx_niveau_alerte (niveau_alerte)
);
```

| Colonne | Type | Justification |
|---------|------|---------------|
| `id_score` | INT PK | Identifiant unique |
| `annonce_id` | BIGINT UNIQUE FK | Relation 1:1 (1 score/annonce) |
| `score_pertinence` | INT 0-100 | Score final (calculé par fonction SQL) |
| `niveau_alerte` | ENUM | **Dérivé de score + deadline** : CRITIQUE (>75 + <7j), URGENT (>60 + <14j), NORMAL (>50), IGNORE (≤50) |
| `raison_scoring` | TEXT | Description raisons score (ex: "2 keywords primaires + montant >500k") |
| `bonus_keywords` | INT | Points bonus keywords trouvés |
| `bonus_montant` | INT | Points bonus montant estimé |
| `bonus_deadline` | INT | Points bonus urgence (deadline proche) |
| `bonus_acheteur` | INT | Points bonus acheteur (ex: frequent buyer) |
| `date_calcul` | DATETIME | Audit |
| `date_maj` | DATETIME | Audit |

**Logique Scoring** (implémentée fonction SQL `CalculerScorePertinence()`) :
1. **Base** : 50 points
2. **+ Keywords** : +5/PRIMARY found, +3/SECONDARY found
3. **+ Montant** : +25 si >500k, +15 si >100k, +5 si >50k
4. **+ Deadline** : +10 si <7j, +5 si <14j
5. **+ Acheteur** : +5 si acheteur "favorable"

**Cardinalité** : 1 ligne/annonce

**Indexes** :
- `idx_score_pertinence` : Recherche "annonces score > 70"
- `idx_niveau_alerte` : Filtrer "toutes CRITIQUE"

---

### TABLE 7 : `notifications` (Alertes)

**Rôle** : Gestion des alertes générées pour annonces qualifiées

```sql
CREATE TABLE notifications (
  id_notification BIGINT PRIMARY KEY AUTO_INCREMENT,
  annonce_id BIGINT NOT NULL,
  
  type_alerte VARCHAR(50) NOT NULL,
  statut ENUM('NEW','SENT','ACKNOWLEDGED','ARCHIVED') DEFAULT 'NEW',
  priorite INT DEFAULT 3 CHECK (priorite >= 1 AND priorite <= 5),
  
  date_creation DATETIME DEFAULT CURRENT_TIMESTAMP,
  date_envoi DATETIME,
  date_acknowledge DATETIME,
  message LONGTEXT,
  
  CONSTRAINT fk_notif_annonce 
    FOREIGN KEY (annonce_id) REFERENCES annonces(id_annonce)
    ON DELETE CASCADE ON UPDATE CASCADE,
  
  INDEX idx_annonce_id (annonce_id),
  INDEX idx_statut (statut),
  INDEX idx_date_creation (date_creation),
  INDEX idx_priorite (priorite)
);
```

| Colonne | Type | Justification |
|---------|------|---------------|
| `id_notification` | BIGINT PK | Identifiant unique |
| `annonce_id` | BIGINT FK | Référence annonce |
| `type_alerte` | VARCHAR(50) | Type (ex: "NEW_OPPORTUNITY", "DEADLINE_CRITICAL") |
| `statut` | ENUM | Pipeline : NEW → SENT → ACKNOWLEDGED → ARCHIVED |
| `priorite` | INT 1-5 | 1=max urgent, 5=basse (pour tri queue) |
| `date_creation` | DATETIME | Quand alerte créée |
| `date_envoi` | DATETIME | Quand alerte envoyée (NULL=pas encore) |
| `date_acknowledge` | DATETIME | Quand utilisateur confirmé (NULL=pas encore) |
| `message` | LONGTEXT | Contenu alerte (ex: email body) |

**Cardinalité** : 1-5 notifications/annonce (création lors scoring URGENT/CRITIQUE)

**Indexes** :
- `idx_statut` : Recherche "alerte à envoyer"
- `idx_priorite` : Tri par urgence
- `idx_date_creation` : Recherche par période

---

### TABLE 8 : `log_technique` (Audit technique)

**Rôle** : Logs des opérations système (imports API, erreurs, performance)

```sql
CREATE TABLE log_technique (
  id_log_tech BIGINT PRIMARY KEY AUTO_INCREMENT,
  
  timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  type_operation VARCHAR(100) NOT NULL,
  source_operation VARCHAR(100),
  status ENUM('OK','WARNING','ERREUR') DEFAULT 'OK',
  
  message TEXT,
  details_json JSON,
  duree_ms INT,
  
  INDEX idx_timestamp (timestamp),
  INDEX idx_type_operation (type_operation),
  INDEX idx_status (status)
);
```

| Colonne | Type | Justification |
|---------|------|---------------|
| `timestamp` | DATETIME | Quand opération exécutée |
| `type_operation` | VARCHAR(100) | Ex: "IMPORT_API_DATA_GOUV", "SCORE_CALCULATION", "BACKUP_FULL" |
| `source_operation` | VARCHAR(100) | Ex: "notebook_j2_extraction", "trigger_after_insert" |
| `status` | ENUM | OK (succès), WARNING (partiellement), ERREUR (échec) |
| `message` | TEXT | Message humain "API timeout retry 2/3" |
| `details_json` | JSON | Flex données structure variable (stack trace, HTTP status, etc.) |
| `duree_ms` | INT | Durée opération (monitoring performance) |

**Rétention** : 90 jours (archivage après via procédure)

**Indexes** :
- `idx_timestamp` : Recherche par période
- `idx_type_operation` : Filtrer erreurs "IMPORT" seulement
- `idx_status` : Recherche "toutes ERREUR"

**Cardinalité** : 10-100 logs/jour → 3,600-36,000/an

---

### TABLE 9 : `log_metier` (Audit métier)

**Rôle** : Historique modifications métier (changements statut annonce, scoring updates)

```sql
CREATE TABLE log_metier (
  id_log_metier BIGINT PRIMARY KEY AUTO_INCREMENT,
  annonce_id BIGINT NOT NULL,
  
  timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  type_operation VARCHAR(100) NOT NULL,
  utilisateur VARCHAR(255),
  description TEXT,
  
  avant_state JSON,
  apres_state JSON,
  
  CONSTRAINT fk_logmetier_annonce 
    FOREIGN KEY (annonce_id) REFERENCES annonces(id_annonce)
    ON DELETE CASCADE ON UPDATE CASCADE,
  
  INDEX idx_annonce_id (annonce_id),
  INDEX idx_timestamp (timestamp),
  INDEX idx_type_operation (type_operation)
);
```

| Colonne | Type | Justification |
|---------|------|---------------|
| `annonce_id` | BIGINT FK | Annonce concernée |
| `timestamp` | DATETIME | Quand changement |
| `type_operation` | VARCHAR(100) | "STATUT_CHANGE", "SCORE_RECALC", "KEYWORD_ADD" |
| `utilisateur` | VARCHAR(255) | Qui a fait changement (système ou humain) |
| `description` | TEXT | Raison changement |
| `avant_state` | JSON | État avant (ex: `{"statut":"NEW"}`) |
| `apres_state` | JSON | État après (ex: `{"statut":"QUALIFIED"}`) |

**Rétention** : Historique complet (pas de suppression)

**Cardinalité** : 2-5 logs/annonce → 36,000-180,000/an

---

### TABLE 10 : `historique_annonces` (Version control)

**Rôle** : Historique colonne-par-colonne des modifications (pour audit RGPD/traçabilité)

```sql
CREATE TABLE historique_annonces (
  id_historique BIGINT PRIMARY KEY AUTO_INCREMENT,
  annonce_id BIGINT NOT NULL,
  
  timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  type_modification VARCHAR(100),
  colonne_modifiee VARCHAR(100),
  
  valeur_ancienne TEXT,
  valeur_nouvelle TEXT,
  
  CONSTRAINT fk_hist_annonce 
    FOREIGN KEY (annonce_id) REFERENCES annonces(id_annonce)
    ON DELETE CASCADE ON UPDATE CASCADE,
  
  INDEX idx_annonce_id (annonce_id),
  INDEX idx_timestamp (timestamp)
);
```

| Colonne | Type | Justification |
|---------|------|---------------|
| `annonce_id` | BIGINT FK | Annonce concernée |
| `timestamp` | DATETIME | Quand modification |
| `type_modification` | VARCHAR(100) | INSERT, UPDATE, DELETE |
| `colonne_modifiee` | VARCHAR(100) | Quelle colonne changée (ex: "statut", "score") |
| `valeur_ancienne` | TEXT | Valeur avant |
| `valeur_nouvelle` | TEXT | Valeur après |

**Rétention** : Historique complet (RGPD compliance)

**Cardinalité** : Peut être très grand (toute modification tracée)

---

### TABLE 11 : `log_sauvegardes` (Backup audit)

**Rôle** : Logs des sauvegardes (traçabilité RTO/RPO)

```sql
CREATE TABLE log_sauvegardes (
  id_log_sauvegarde INT PRIMARY KEY AUTO_INCREMENT,
  
  timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  type_backup ENUM('FULL','INCREMENTAL') DEFAULT 'FULL',
  fichier VARCHAR(500) NOT NULL,
  status ENUM('OK','ERREUR') DEFAULT 'OK',
  
  nb_bytes BIGINT,
  duree_secondes INT,
  message_erreur TEXT,
  
  INDEX idx_timestamp (timestamp),
  INDEX idx_status (status)
);
```

| Colonne | Type | Justification |
|---------|------|---------------|
| `timestamp` | DATETIME | Quand backup effectué |
| `type_backup` | ENUM | FULL (complet) ou INCREMENTAL (différentiel) |
| `fichier` | VARCHAR(500) | Chemin fichier backup généré |
| `status` | ENUM | OK ou ERREUR |
| `nb_bytes` | BIGINT | Taille fichier |
| `duree_secondes` | INT | Durée backup |
| `message_erreur` | TEXT | Si ERREUR, raison failure |

**Rétention** : Historique complet (important pour audit)

**Indexes** :
- `idx_timestamp` : Recherche "dernier backup"
- `idx_status` : Recherche "backups en erreur"

---

## Résumé Tables

| Table | Rôle | Cardinalité | Growth/an |
|-------|------|-------------|-----------|
| `sources` | Référence sources | ~5 | ~0 |
| `acheteurs` | Référence acheteurs | ~1,000 | ~500 |
| `mots_cles` | Catalogue keywords | ~50-200 | ~50 |
| `annonces` | **PRINCIPALE** | 18k-180k | Linéaire |
| `annonce_mot_cle` | Liaison N:N | 150k-900k | Linéaire |
| `qualification_scores` | Scoring 1:1 | 18k-180k | Linéaire |
| `notifications` | Alertes | 36k-900k | Linéaire |
| `log_technique` | Audit technique | 3.6k-36k | Linéaire |
| `log_metier` | Audit métier | 36k-180k | Linéaire |
| `historique_annonces` | Version control | 100k-1M | Linéaire |
| `log_sauvegardes` | Backup audit | ~366 | Linéaire |

---

## Stratégie Indexes

### Indexes Critiques (O(1) lookup)

1. **Doublon Detection** : `UNIQUE (source_id, id_externe)` sur `annonces`
   - Empêche insertion doublon au niveau DB
   - Performance : O(1) check avant INSERT

2. **Recherche dates (URGENT)** :
   - `idx_date_deadline` sur `annonces`
   - Requête : "annonces deadline < 7 jours"

3. **Recherche géographique** :
   - `idx_region` sur `annonces`
   - `idx_region` sur `acheteurs`

4. **Recherche montant** :
   - `idx_montant` sur `annonces`
   - Requête : "montant > 100k€"

### Indexes Secondaires

- Foreign keys : Auto-indexed MySQL (sauf explicit)
- `idx_statut` : Filtrer NEW vs QUALIFIED
- `idx_score_pertinence` : Dashboard queries

### Stratégie Composite Keys (Futures)

```sql
-- Si besoin recherche combinée (région + montant + deadline)
CREATE INDEX idx_region_montant_deadline ON annonces(region, montant_estime DESC, date_limite_reponse);
```

---

## Contraintes de Données

### Domaine

- **Montant** : 0 ≤ montant ≤ 999,999,999,999.99 EUR
- **Score pertinence** : 0-100 (pourcentage)
- **Priorite notification** : 1-5
- **Titre annonce** : 6-500 caractères
- **Date logique** : date_publication ≤ date_deadline

### Référentiel

- Clé étrangère (source_id) → restrict delete
- Clé étrangère (acheteur_id) → restrict delete
- Clé étrangère (annonce_id) → cascade delete (logs auto-nettoyés)

---

## Scénarios de Requête

### Cas d'usage 1 : Import Daily (J2)

```sql
-- Vérifier doublon avant insert
SELECT COUNT(*) FROM annonces 
WHERE source_id = 1 AND id_externe = 'GOV_12345';

-- Insérer si pas doublon
INSERT INTO annonces (...) VALUES (...);
```

**Performance** : O(1) via UNIQUE KEY

### Cas d'usage 2 : Dashboard Urgent (J5)

```sql
-- Trouver annonces critiques/urgentes
SELECT a.*, qs.score_pertinence, qs.niveau_alerte
FROM annonces a
JOIN qualification_scores qs ON a.id_annonce = qs.annonce_id
WHERE qs.niveau_alerte IN ('CRITIQUE','URGENT')
  AND a.date_limite_reponse < DATE_ADD(NOW(), INTERVAL 14 DAY)
ORDER BY qs.score_pertinence DESC;
```

**Performance** : O(n) scan, mais n petit via WHERE filters

### Cas d'usage 3 : Recherche par Keyword (J3)

```sql
-- Annonces contenant keyword "modulaire"
SELECT a.*
FROM annonces a
JOIN annonce_mot_cle amc ON a.id_annonce = amc.annonce_id
JOIN mots_cles mc ON amc.mot_cle_id = mc.id_mot_cle
WHERE mc.mot_cle = 'modulaire'
  AND a.region = 'Île-de-France'
ORDER BY a.date_publication DESC;
```

**Performance** : O(log n) via indexes

---

## Migration & Deployment

### DDL Execution Order

1. **01_create_tables.sql** : Toutes tables (foreign keys référencent)
2. **02_create_indexes.sql** : Indexes stratégiques
3. **03_create_base_data.sql** : Données initiales (sources, keywords)
4. **04_functions.sql** : Fonctions SQL (J4)
5. **05_procedures.sql** : Procédures (J4)
6. **06_triggers.sql** : Triggers (J4)

### Rollback Plan

```bash
# Si problème pendant import J2
ROLLBACK;  -- Tout annule (ACID)

# Restaurer depuis sauvegarde
mysql unitee < backups/unitee_2026_04_07.sql
```

---

## Notes Techniques

### Choix MySQL 8.0+

- **JSON Support** : Flexibilité logs
- **Generated Columns** : Calculs automats
- **Window Functions** : Analytics avancées
- **ACID Transactions** : Intégrité données critiques

### Charset utf8mb4

- Support complet Unicode
- Français accents (é, è, ê, ô) ✓
- Futurs caractères spéciaux ✓

### Storage Estimation

- Annonces : 18k-180k lignes = 9-90 MB (500 bytes/row)
- Keywords : 50-200 = <1 MB
- Logs : 150k-1M = 15-100 MB
- **Total** : ~50-300 MB (très petit, aucun problème stockage)

---

## Prochains Fichiers

- `02_create_tables.sql` : Implémentation complète DDL
- `03_create_indexes.sql` : Index strategy détaillée
- `04_create_base_data.sql` : Données référence (sources, keywords)
- `docs/SCHEMA.md` : Documentation format différent (cette doc est technique)

---

*Document généré le 2026-04-08 | Projet UNITEE v1.0*
