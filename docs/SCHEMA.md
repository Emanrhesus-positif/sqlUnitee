# SCHEMA DOCUMENTATION - UNITEE

## Quick Reference

### 11 Tables Organization

```
┌─────────────────────────┐
│ REFERENCE TABLES        │
├─────────────────────────┤
│ sources (3)             │
│ acheteurs (30+)         │
│ mots_cles (10+)         │
└─────────────────────────┘
        ↓
┌─────────────────────────┐
│ BUSINESS CORE           │
├─────────────────────────┤
│ annonces (18k-180k)     │← Main table
│ annonce_mot_cle (N:N)   │← Linking keywords
└─────────────────────────┘
        ↓
┌─────────────────────────┐
│ QUALIFICATION           │
├─────────────────────────┤
│ qualification_scores    │
│ notifications           │
└─────────────────────────┘
        ↓
┌─────────────────────────┐
│ AUDIT & LOGS            │
├─────────────────────────┤
│ log_technique (90j)     │
│ log_metier (full)       │
│ historique_annonces (full) │
│ log_sauvegardes (full)  │
└─────────────────────────┘
```

---

## Table Specifications

### 1. sources
**Role**: Source reference data  
**Rows**: ~3-5 (data.gouv.fr, BOAMP, synthetic)  
**Key**: id_source (PK)

| Column | Type | Notes |
|--------|------|-------|
| id_source | INT PK | Auto-increment |
| nom_source | VARCHAR(100) UNIQUE | Unique name per source |
| description | TEXT | Source documentation |
| url_base | VARCHAR(500) | API base URL |
| type_source | ENUM | API, SCRAPING, or FLUX_RSS |
| actif | BOOLEAN | Enable/disable flag |
| date_creation | DATETIME | Audit trail |

**Used by**: Annonces (FK) → Always RESTRICT on delete

---

### 2. acheteurs
**Role**: Public buyer reference  
**Rows**: ~1,000-10,000 (grows slowly)  
**Keys**: id_acheteur (PK), nom_acheteur (UNIQUE)

| Column | Type | Notes |
|--------|------|-------|
| id_acheteur | INT PK | Auto-increment |
| nom_acheteur | VARCHAR(255) UNIQUE | Official buyer name |
| type_acheteur | ENUM | COLLECTIVITE, ETAT, ENTREPRISE_PUBLIQUE |
| region | VARCHAR(100) | Regional categorization |
| contact_email | VARCHAR(255) | Optional contact |
| contact_phone | VARCHAR(20) | Optional contact |
| date_creation | DATETIME | Audit |

**Indexes**:
- idx_type_acheteur (filter by type)
- idx_region (filter by region)
- idx_type_region (composite: type + region)

**Initial data**: 32 rows (major cities + state entities)

---

### 3. mots_cles
**Role**: Keyword catalog  
**Rows**: ~50-200 (grows via TF-IDF analysis)  
**Keys**: id_mot_cle (PK), mot_cle (UNIQUE)

| Column | Type | Notes |
|--------|------|-------|
| id_mot_cle | INT PK | Auto-increment |
| mot_cle | VARCHAR(100) UNIQUE | Exact keyword string |
| categorie | ENUM | PRIMARY, SECONDARY, EXTRACTED |
| pertinence | INT 0-100 | Default relevance score |
| date_creation | DATETIME | Audit (when discovered) |

**Categories**:
- **PRIMARY** (5): From config.yaml - high impact (modulaire, préfabriqué, etc.)
- **SECONDARY** (5): From config.yaml - medium impact (extension, classe temporaire, etc.)
- **EXTRACTED** (0 initially): Discovered via TF-IDF analysis in Day 3

**Initial data**: 10 rows (5 PRIMARY + 5 SECONDARY)

---

### 4. annonces ⭐ MAIN TABLE
**Role**: Core business data - marketplace announcements  
**Rows**: 18,000-180,000 (50-500/day growth)  
**Keys**: id_annonce (PK), (source_id, id_externe) UNIQUE, lien_source UNIQUE

| Column | Type | Key Features |
|--------|------|--------------|
| id_annonce | BIGINT PK | Support 8B+ records |
| source_id | INT FK | RESTRICT on delete |
| acheteur_id | INT FK | RESTRICT on delete |
| id_externe | VARCHAR(100) | External source ID |
| titre | VARCHAR(500) | MIN 6 chars (CHECK) |
| resume | TEXT | Short summary |
| description | LONGTEXT | Full text |
| montant_estime | DECIMAL(15,2) | ≥ 0 (CHECK) |
| devise | VARCHAR(3) | EUR default |
| date_publication | DATETIME | **CRITICAL** for urgency |
| date_limite_reponse | DATETIME | **CRITICAL** deadline |
| localisation | VARCHAR(255) | Work location |
| region | VARCHAR(100) | Regional categorization |
| lien_source | TEXT UNIQUE | Source URL (1 per record) |
| statut | ENUM | NOUVEAU, QUALIFIE, IGNORE, REPONDU |
| timestamp_import | DATETIME | Audit: import time |
| timestamp_maj | DATETIME | Audit: last update |

**Unique Constraints** ⚠️ **CRITICAL**:
- `UNIQUE (source_id, id_externe)` → **O(1) doublon detection at DB level**
- `UNIQUE (lien_source)` → One URL per announcement

**Check Constraints**:
- `CHECK (CHAR_LENGTH(titre) > 5)` → Min 6 chars
- `CHECK (montant_estime >= 0)` → No negative amounts
- `CHECK (date_publication <= date_limite_reponse)` → Logic validation

**Indexes** (CRITICAL for performance):
- `idx_date_limite_reponse` ⭐ → Find urgents (< 7 days)
- `idx_region_deadline` ⭐ → Urgent by region
- `idx_montant_estime` → Filter by amount
- `idx_statut` → Filter by processing status
- `idx_region` → Geographic filtering
- Full index list in `03_create_indexes.sql`

**Foreign Keys**:
- source_id → sources.id_source (RESTRICT)
- acheteur_id → acheteurs.id_acheteur (RESTRICT)

---

### 5. annonce_mot_cle
**Role**: N:N linking table (announcements ↔ keywords)  
**Rows**: ~150,000-900,000 (3-5 keywords per announcement)  
**Keys**: (annonce_id, mot_cle_id) composite PK

| Column | Type | Notes |
|--------|------|-------|
| annonce_id | BIGINT FK | CASCADE delete |
| mot_cle_id | INT FK | RESTRICT delete |
| pertinence_score | INT 0-100 | Contextual score (90=title, 40=description) |
| type_extraction | ENUM | REGEX, TF-IDF, MANUAL, LLM (audit) |
| date_extraction | DATETIME | Audit |

**Purpose**: Track which keywords found in which announcements + extraction method

**Indexes**:
- `idx_mot_cle_id` → Find "announcements with keyword X"
- `idx_pertinence_score` → Filter by relevance
- `idx_mot_cle_pertinence` → Composite for high-relevance keywords

---

### 6. qualification_scores
**Role**: Pertinence scoring (1:1 with announcements)  
**Rows**: 18,000-180,000 (1 per announcement)  
**Keys**: id_score (PK), annonce_id (UNIQUE FK)

| Column | Type | Calculation |
|--------|------|-------------|
| id_score | INT PK | Auto-increment |
| annonce_id | BIGINT UNIQUE FK | CASCADE delete |
| score_pertinence | INT 0-100 | **Final score** (function: CalculerScorePertinence) |
| niveau_alerte | ENUM | Derived: CRITIQUE, URGENT, NORMAL, IGNORE |
| raison_scoring | TEXT | Human-readable explanation |
| bonus_keywords | INT | Points from keywords found |
| bonus_montant | INT | Points from amount (>500k=+25, >100k=+15, >50k=+5) |
| bonus_deadline | INT | Points from urgency (<7j=+10, <14j=+5) |
| bonus_acheteur | INT | Points from buyer favorability |
| date_calcul | DATETIME | Audit: when calculated |
| date_maj | DATETIME | Audit: when last recalculated |

**Scoring Algorithm** (Function CalculerScorePertinence - J4):
```
base_score = 50
+ bonus_keywords (5 per PRIMARY found, 3 per SECONDARY)
+ bonus_montant (0-25 based on amount)
+ bonus_deadline (0-10 based on deadline proximity)
+ bonus_acheteur (0-5 for favorable buyers)
= score_pertinence (0-100)
```

**Alert Levels** (Derived from score + deadline):
- **CRITIQUE**: score > 75 AND deadline < 7 days
- **URGENT**: score > 60 AND deadline < 14 days
- **NORMAL**: score >= 50
- **IGNORE**: score < 50

---

### 7. notifications
**Role**: Alert management for qualified announcements  
**Rows**: ~36,000-900,000 (varies with urgency)  
**Keys**: id_notification (PK)

| Column | Type | Notes |
|--------|------|-------|
| id_notification | BIGINT PK | Auto-increment |
| annonce_id | BIGINT FK | CASCADE delete |
| type_alerte | VARCHAR(50) | NEW_OPPORTUNITY, DEADLINE_CRITICAL, etc. |
| statut | ENUM | NOUVEAU → ENVOYE → ACQUITTE → ARCHIVE |
| priorite | INT 1-5 | 1=urgent, 5=basse (tri file d'attente) |
| date_creation | DATETIME | When alert generated |
| date_envoi | DATETIME | When alert sent (NULL=not yet) |
| date_acknowledge | DATETIME | When user acknowledged (NULL=not yet) |
| message | LONGTEXT | Alert content (email body, etc.) |

**Pipeline**: NOUVEAU → ENVOYE → ACQUITTE → ARCHIVE

---

### 8. log_technique
**Role**: Technical operation logs (API imports, errors, performance)  
**Retention**: 90 days (archive after via procedure)  
**Rows**: 3,600-36,000/year

| Column | Type | Notes |
|--------|------|-------|
| id_log_tech | BIGINT PK | Auto-increment |
| timestamp | DATETIME | Operation timestamp |
| type_operation | VARCHAR(100) | IMPORT_API_DATA_GOUV, SCORE_CALCULATION, etc. |
| source_operation | VARCHAR(100) | notebook_j2, trigger_after_insert, etc. |
| status | ENUM | OK, WARNING, ERREUR |
| message | TEXT | Human message |
| details_json | JSON | Flexible structure (stack trace, HTTP status) |
| duree_ms | INT | Operation duration (performance monitoring) |

**Indexes**: timestamp, type_operation, status (all searchable)

---

### 9. log_metier
**Role**: Business operation audit (status changes, scoring updates)  
**Retention**: Full history (no deletion)  
**Rows**: 36,000-180,000/year

| Column | Type | Notes |
|--------|------|-------|
| id_log_metier | BIGINT PK | Auto-increment |
| annonce_id | BIGINT FK | CASCADE delete |
| timestamp | DATETIME | When change occurred |
| type_operation | VARCHAR(100) | STATUT_CHANGE, SCORE_RECALC, KEYWORD_ADD |
| utilisateur | VARCHAR(255) | System or human user |
| description | TEXT | Change reason |
| avant_state | JSON | State before (e.g., {"statut":"NEW"}) |
| apres_state | JSON | State after (e.g., {"statut":"QUALIFIED"}) |

---

### 10. historique_annonces
**Role**: Column-level version control (GDPR compliance)  
**Retention**: Full history  
**Rows**: 100,000-1,000,000/year

| Column | Type | Notes |
|--------|------|-------|
| id_historique | BIGINT PK | Auto-increment |
| annonce_id | BIGINT FK | CASCADE delete |
| timestamp | DATETIME | When modified |
| type_modification | VARCHAR(100) | INSERT, UPDATE, DELETE |
| colonne_modifiee | VARCHAR(100) | Which column changed |
| valeur_ancienne | TEXT | Value before |
| valeur_nouvelle | TEXT | Value after |

---

### 11. log_sauvegardes
**Role**: Backup audit (RTO/RPO traceability)  
**Retention**: Full history  
**Rows**: ~366/year (daily backups)

| Column | Type | Notes |
|--------|------|-------|
| id_log_sauvegarde | INT PK | Auto-increment |
| timestamp | DATETIME | When backup executed |
| type_backup | ENUM | FULL or INCREMENTAL |
| fichier | VARCHAR(500) | Backup file path |
| status | ENUM | OK or ERREUR |
| nb_bytes | BIGINT | File size |
| duree_secondes | INT | Backup duration |
| message_erreur | TEXT | Error details if failed |

---

## Data Flow

```
EXTERNAL SOURCES
├─ data.gouv.fr API
├─ BOAMP API/Scraping
└─ Synthetic test data
    ↓
[NOTEBOOK J2-J3: Extract + Transform]
    ↓
INSERT into annonces + annonce_mot_cle
    ↓
TRIGGER: BEFORE INSERT
├─ Validate data (title length, dates, amount)
├─ Check doublon (source_id, id_externe)
└─ Log technical operation
    ↓
INSERT proceeds
    ↓
TRIGGER: AFTER INSERT
├─ Calculate score → qualification_scores
├─ Create alert if URGENT/CRITIQUE
├─ Log business operation
└─ Log version history
    ↓
DASHBOARD VIEWS (J5)
├─ KPI: Top 10 urgent announcements
├─ KPI: Geographic distribution
├─ KPI: Top keywords
├─ KPI: Buyer summary
└─ KPI: Weekly trends
    ↓
BACKUP SYSTEM (J5)
└─ Daily full backup at 22:00
    └─ 30-day retention
    └─ Log in log_sauvegardes
```

---

## Constraints Summary

### Unique Constraints
| Table | Constraint | Purpose |
|-------|-----------|---------|
| sources | nom_source | One per source name |
| acheteurs | nom_acheteur | One per buyer |
| mots_cles | mot_cle | One per keyword |
| annonces | (source_id, id_externe) | **Doublon detection** |
| annonces | lien_source | One per URL |
| qualification_scores | annonce_id | 1:1 with announcements |

### Check Constraints
| Table | Constraint | Validation |
|-------|-----------|------------|
| annonces | titre LENGTH > 5 | Min 6 chars |
| annonces | montant >= 0 | No negatives |
| annonces | date_pub <= deadline | Logic |
| qualification_scores | score 0-100 | Range |
| annonce_mot_cle | score 0-100 | Range |
| notifications | priorite 1-5 | Range |

### Foreign Key Constraints
| Table | FK | References | Delete Policy |
|-------|----|-----------:|--------------|
| annonces | source_id | sources | RESTRICT |
| annonces | acheteur_id | acheteurs | RESTRICT |
| annonce_mot_cle | annonce_id | annonces | CASCADE |
| annonce_mot_cle | mot_cle_id | mots_cles | RESTRICT |
| qualification_scores | annonce_id | annonces | CASCADE |
| notifications | annonce_id | annonces | CASCADE |
| log_metier | annonce_id | annonces | CASCADE |
| historique_annonces | annonce_id | annonces | CASCADE |

---

## Performance Considerations

### Critical Indexes (Must Have)
1. **annonces.idx_date_limite_reponse** → Find urgents efficiently
2. **annonces.idx_region_deadline** → Urgent by region
3. **qualification_scores.idx_niveau_alerte** → Dashboard alerts
4. **annonce_mot_cle.idx_mot_cle_id** → Keyword searches
5. **annonces.UNIQUE(source_id, id_externe)** → O(1) doublon detection

### Query Patterns
| Query | Indexes Used |
|-------|--------------|
| Find urgent announcements | idx_date_limite_reponse, idx_niveau_alerte |
| Search by keyword | idx_mot_cle_id, idx_amc_pertinence |
| Filter by region | idx_region, idx_region_deadline |
| Filter by amount | idx_montant_estime |
| Check doublon | UNIQUE(source_id, id_externe) |

### Storage Estimation
| Table | Records | Size/Record | Total |
|-------|---------|------------|-------|
| annonces | 180k | 500 B | 90 MB |
| annonce_mot_cle | 900k | 100 B | 90 MB |
| logs | 150k | 500 B | 75 MB |
| **TOTAL** | | | **~300 MB/year** |

---

## Migration Checklist

- [ ] Execute 02_create_tables.sql
- [ ] Execute 03_create_indexes.sql
- [ ] Execute 04_create_base_data.sql
- [ ] Verify 11 tables created: `SHOW TABLES;`
- [ ] Check sources (3 rows)
- [ ] Check mots_cles (10 rows)
- [ ] Check acheteurs (32 rows)
- [ ] Test UNIQUE constraints
- [ ] Test sample insert into annonces
- [ ] Verify timestamp_maj ON UPDATE

---

## Related Documentation

- **01_schema.md** → Detailed table specifications
- **Plan.md** → 6-day project roadmap
- **config/config.yaml** → Configuration parameters
- **config/PARAMETRES.md** → Parameter explanations

---

*Schema v1.0 | Generated 2026-04-08*
