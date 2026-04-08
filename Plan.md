# 📋 PLAN D'ACTION FINAL - PROJET UNITEE

## 🎯 RÉSUMÉ EXÉCUTIF

**Projet** : Plateforme de veille automatisée des marchés publics (secteur bâtiment modulaire)  
**Équipe** : 1 personne (seul)  
**Durée totale** : 6 jours (J1-J6)  
**Approach** : Jupyter Notebook + MySQL local (Docker) + SQL avancé  
**Date démarrage** : 8 avril 2026

**Objectif principal** : Créer un système SQL robuste capable de :
- Récupérer données depuis **data.gouv.fr API + BOAMP**
- Transformer et valider via **Jupyter Notebook** (`Unitee.ipynb`)
- Stocker et qualifier via **MySQL avec logique avancée**
- Exposer via **Dashboard avec KPIs**
- Automatiser avec **Sauvegarde quotidienne**

---

## 📊 ARCHITECTURE GLOBALE

```
┌──────────────────────────────────────────────────┐
│     SOURCES DE DONNÉES EXTERNES                   │
├──────────────────────────────────────────────────┤
│  • data.gouv.fr API (marchés publics)            │
│  • BOAMP API (Bulletin Officiel)                 │
│  • Données synthétiques (test/demo)              │
└────────────────────┬─────────────────────────────┘
                     │ HTTP/REST + CSV
                     ▼
        ╔════════════════════════════════╗
        ║   UNITEE.IPYNB (Jupyter)      ║
        ║  ┌─ Onglet 1: Setup           ║
        ║  ├─ Onglet 2: Extraction      ║
        ║  ├─ Onglet 3: Transformation  ║
        ║  ├─ Onglet 4: Validation      ║
        ║  └─ Onglet 5: Export          ║
        ╚════════════╦═══════════════════╝
                     │ SQL INSERT / CSV
                     ▼
        ┌─────────────────────────────────┐
        │    MYSQL 8.0 (Docker)           │
        │  ┌─ Tables (10+)               │
        │  ├─ Fonctions (3)              │
        │  ├─ Procédures (4)             │
        │  ├─ Triggers (4)               │
        │  └─ Vues Dashboard (5+)        │
        └────────────┬────────────────────┘
                     │ SELECT
                     ▼
        ╔════════════════════════════════╗
        ║  KPIs & DASHBOARD              ║
        ║  • Nombre annonces détectées   ║
        ║  • Évolution temporelle        ║
        ║  • Répartition géographique    ║
        ║  • Alertes prioritaires        ║
        ║  • Performance sources         ║
        ╚════════════════════════════════╝
```

---

## 📁 STRUCTURE DU PROJET (Livrables)

```
sqlUnitee/
│
├── Plan.md                          [CE DOCUMENT]
├── README.md                        [Mis à jour]
│
├── config/
│   ├── config.yaml                  [Paramètres ajustables]
│   ├── PARAMETRES.md                [Explications détaillées]
│   └── sources_config.yaml          [URLs API + endpoints]
│
├── data_sources/                    [SOURCES DE DONNÉES]
│   ├── SOURCES_DATA.md              [Guide récupération données]
│   ├── data_gouv_fr.md              [Documentation API data.gouv.fr]
│   └── boamp_api.md                 [Documentation API BOAMP]
│
├── notebook/
│   └── Unitee.ipynb                 [Jupyter - 5 onglets]
│
├── sql/
│   ├── schema/
│   │   ├── MCD.puml                 [Diagramme conceptuel (PlantUML)]
│   │   ├── MLD.puml                 [Diagramme logique (PlantUML)]
│   │   ├── physique.puml            [Diagramme physique (PlantUML)]
│   │   ├── 01_schema.md             [Description détaillée]
│   │   ├── schema_diagram.png       [Export PNG des diagrammes]
│   │   │
│   │   ├── 02_create_tables.sql
│   │   ├── 03_create_indexes.sql
│   │   └── 04_create_base_data.sql
│   │
│   ├── logic/
│   │   ├── 05_functions.sql         [Fonctions de calcul]
│   │   ├── 06_procedures.sql        [Procédures métier]
│   │   ├── 07_triggers.sql          [Triggers automatisation]
│   │   └── 08_transactions.sql      [Tests transactions]
│   │
│   ├── analytics/
│   │   ├── 09_views_dashboard.sql   [Vues KPI]
│   │   ├── 10_analytics_queries.sql [Requêtes avancées]
│   │   └── 11_backup_system.sql     [Logs + archivage]
│   │
│   └── tests/
│       └── 12_tests.sql             [Tests unitaires]
│
├── scripts/
│   ├── backup.sh                    [Sauvegarde Linux/Mac]
│   ├── backup.bat                   [Sauvegarde Windows]
│   ├── restore.sh                   [Restauration]
│   ├── deploy.sh                    [Déploiement complet]
│   └── run_notebook.sh              [Lancer notebook]
│
├── data/
│   ├── annonces_raw.csv             [Données brutes (EXPORT notebook)]
│   ├── annonces_cleaned.csv         [Données nettoyées (EXPORT notebook)]
│   ├── validation_report.md         [Rapport validation (EXPORT notebook)]
│   └── samples/                     [Données de test]
│       └── sample_data.json         [100 annonces test]
│
├── docs/
│   ├── SCHEMA.md                    [Description schéma détaillée]
│   ├── LOGIC.md                     [Fonctions/Procs/Triggers expliquées]
│   ├── EXPLOITATION.md              [Guide exploitation + monitoring]
│   └── NOTEBOOK_GUIDE.md            [Guide Unitee.ipynb]
│
├── docker-compose.yml               [Config MySQL + PhpMyAdmin]
├── .env.example                     [Variables d'environnement]
├── .gitignore                       [Git config]
└── requirements.txt                 [Dépendances Python]
```

---

## 📅 PLANNING DÉTAILLÉ PAR JOUR

### **JOUR 1 : Conception & Architecture (8h)**

#### Matin (4h)
- [ ] Concevoir **MCD (Modèle Conceptuel)** → `MCD.puml`
  - Entités : annonces, sources, acheteurs, mots_cles, qualification_scores
  - Relations : N:N, 1:N
  - Attributs clés
  
- [ ] Créer **MLD (Modèle Logique)** → `MLD.puml`
  - Tables normalisées (3FN)
  - Clés primaires/étrangères
  - Types de données

- [ ] Créer **Modèle Physique** → `physique.puml`
  - Avec contraintes SQL
  - Index strategy
  - Vue MySQL-compatible

#### Après-midi (4h)
- [ ] Générer `01_schema.md` (description + justifications)
- [ ] Créer `02_create_tables.sql` (DDL complet)
- [ ] Créer `03_create_indexes.sql` (stratégie indexation)
- [ ] Créer `04_create_base_data.sql` (tables de référence)
- [ ] Générer **PNG du schéma** depuis PlantUML

#### Livrables J1
✅ MCD.puml  
✅ MLD.puml  
✅ physique.puml  
✅ 01_schema.md  
✅ 02-04_create_*.sql  
✅ schema_diagram.png  

---

### **JOUR 2 : Setup + Extraction Données (8h)**

#### Matin (4h)
- [ ] Setup **Docker MySQL**
  - Créer `docker-compose.yml`
  - Créer `.env.example`
  - Lancer MySQL + PhpMyAdmin
  - Vérifier connexion

- [ ] **Recherche sources de données**
  - Tester API data.gouv.fr (récupération datasets marchés publics)
  - Documenter endpoint API dans `data_sources/data_gouv_fr.md`
  - Vérifier BOAMP API dans `data_sources/boamp_api.md`
  - Créer `sources_config.yaml` avec URLs de base

#### Après-midi (4h)
- [ ] Commencer **Unitee.ipynb - Onglet 1 & 2**
  - Setup imports & config (requests, pandas, mysql.connector)
  - Charger config.yaml et sources_config.yaml
  - Fonction `fetch_data_gouv_fr()` (extraction API data.gouv.fr)
  - Fonction `fetch_boamp()` (extraction BOAMP)
  - Fallback données synthétiques si API fail
  - Sauvegarde données brutes `data/annonces_raw.csv`

#### Livrables J2
✅ docker-compose.yml + .env.example  
✅ data_sources/data_gouv_fr.md  
✅ data_sources/boamp_api.md  
✅ sources_config.yaml  
✅ Unitee.ipynb (Onglets 1-2 fonctionnels)  
✅ data/annonces_raw.csv (100-500 annonces)  

---

### **JOUR 3 : Transformation + Validation (8h)**

#### Matin (4h)
- [ ] **Unitee.ipynb - Onglet 3 & 4**
  - Fonction `transform_annonces(df)` avec :
    - Nettoyage colonnes (minuscules, trim whitespace)
    - Normalisation types (dates → DATETIME, montants → DECIMAL)
    - Suppression colonnes inutiles
    - Extraction `region` depuis `localisation` (regex ou mappings)
    - Extraction mots-clés via regex/TF-IDF
    - Ajout `timestamp_import = NOW()`
  
  - Fonction `validate_data(df)` avec :
    - Tests doublons (source + id_externe)
    - Validation dates (publication < deadline)
    - Validation montants (> 0 si present)
    - Validation titre (not NULL, len > 5)
    - Génération rapport rejet

- [ ] Générer rapport validation `data/validation_report.md`

#### Après-midi (4h)
- [ ] **Analyse mots-clés pertinents**
  - À partir des données transformées
  - Récupérer top 5 mots-clés via comptage + TF
  - Mettre à jour `config.yaml` avec les résultats
  
- [ ] **Unitee.ipynb - Onglet 5**
  - Fonction `export_to_sql(df_valid)` :
    - Générer INSERT statements lisibles
    - Générer CSV pour bulk import
  - Exporter `05_insert_test_data.sql`
  - Exporter `data/annonces_cleaned.csv`

- [ ] **Charger données dans MySQL**
  - Exécuter 02_create_tables.sql
  - Exécuter 03_create_indexes.sql
  - Exécuter 04_create_base_data.sql
  - Insérer données test (05_insert_test_data.sql)
  - Vérifier intégrité (SELECT COUNT, vérifier clés)

#### Livrables J3
✅ Unitee.ipynb (Onglets 3-5 complets)  
✅ data/annonces_cleaned.csv  
✅ data/validation_report.md  
✅ 05_insert_test_data.sql  
✅ config.yaml (mis à jour avec top 5 keywords)  
✅ MySQL avec données chargées ✅ vérifiées  

---

### **JOUR 4 : Logique SQL Avancée (8h)**

#### Matin (4h)
- [ ] **Fonctions SQL** → `05_functions.sql`
  
  **Fonction 1 : `CalculerScorePertinence(titre, description, montant, region)`**
  ```
  Logique scoring (0-100) :
  • Présence mots-clés (config.yaml keywords) : +30
  • Montant estimé > 100k€ : +25
  • Région = France (toutes) : +20 (adaptable future)
  • Deadline < 30 jours : +15
  • Matching acheteur historique : +10
  • Bonus pour TOP keywords : +5
  ```

  **Fonction 2 : `CategoriserAlerte(score INT, days_left INT)`**
  ```
  Retourne :
  • 'CRITIQUE' si score > 75 ET days_left < 7
  • 'URGENT' si score > 60 ET days_left < 14
  • 'NORMAL' si score > 50
  • 'IGNORE' si score <= 50
  ```

  **Fonction 3 : `NormaliserRegion(localisation TEXT)`**
  ```
  Retourne région standardisée :
  Île-de-France, Occitanie, Provence-Alpes-Côte d'Azur, etc.
  Utilise mapping regex ou table de régions
  ```

#### Après-midi (4h)
- [ ] **Procédures Stockées** → `06_procedures.sql`

  **Procédure 1 : `InsererAnnonce(source_name, id_externe, titre, ...)`**
  - Vérifier doublon (source_id + id_externe)
  - Si existe : UPDATE avec log métier
  - Si nouveau : INSERT
  - Calculer score via fonction
  - Insérer dans log_metier (qui, quand, quoi)
  - Créer notification si score > 75
  - Retourner ID annonce ou code erreur
  - Gestion transaction + ROLLBACK si erreur

  **Procédure 2 : `TraiterLotAnnonces(source_id INT, batch_size INT)`**
  - BEGIN TRANSACTION
  - Récupérer lot d'annonces statut = 'NEW' (LIMIT batch_size)
  - Pour chaque : appeler InsererAnnonce()
  - Compter succès/erreurs
  - Si > 20% erreurs : ROLLBACK
  - Sinon : COMMIT
  - Retourner (@nb_inserted, @nb_updated, @nb_errors)
  - Log dans log_technique

  **Procédure 3 : `GenererKPIDashboard()`**
  - Calculer KPI globaux
  - Remplir vue `vw_kpi_resume` avec aggrégations
  - Retourner SELECT résumé

  **Procédure 4 : `ArchiverDonneeAncienne(days_retention INT)`**
  - Copier annonces > X jours vers table archive_annonces
  - Supprimer originales
  - Archiver logs techniques > 90 jours
  - Retourner nombre records archivés

- [ ] **Triggers** → `07_triggers.sql`

  **BEFORE INSERT ON annonces**
  - Valider : titre NOT NULL ET LEN > 5
  - Valider : source_id existe (FK)
  - Valider : date_publication <= NOW()
  - Valider : montant NULL OU >= 0
  - SIGNAL si validation échoue

  **AFTER INSERT ON annonces**
  - Insérer dans log_metier : ("ANNONCE_CREEE", NEW.id, ...)
  - Calculer score via CalculerScorePertinence()
  - Insérer dans qualification_scores
  - Si score > 75 : Créer row dans notifications (statut='NEW', alerte='SCORE_ÉLEVÉ')

  **AFTER UPDATE ON annonces**
  - Si colonnes clés changent (titre, montant, etc.)
  - Copier ancien state dans historique_annonces
  - Insérer dans log_metier : ("ANNONCE_MODIFIEE", OLD.id, ...)
  - Recalculer score

  **BEFORE DELETE ON annonces**
  - Copier row vers archive_annonces
  - Empêcher vraie suppression logique (via trigger)

- [ ] **Tests Transactions** → `08_transactions.sql`

  **Scénario 1 : Insertion lot avec erreur au milieu**
  ```sql
  START TRANSACTION;
  -- Insérer 10 annonces (sans erreur)
  -- Insérer 1 annonce invalide (montant < 0)
  -- Insérer 10 annonces (sans erreur)
  -- Résultat attendu : ROLLBACK complet, 0 annonce insérée
  ROLLBACK;
  ```

  **Scénario 2 : Insertion lot avec gestion partielle**
  ```sql
  -- Insérer 20 annonces
  -- Compter erreurs
  -- Si < 20% : COMMIT (garde succès, loggue erreurs)
  -- Si > 20% : ROLLBACK
  ```

  **Scénario 3 : SAVEPOINT**
  ```sql
  -- Insérer annonce 1 → SUCCESS
  -- SAVEPOINT sp1
  -- Insérer annonce 2 → ERREUR
  -- ROLLBACK TO sp1
  -- Annonce 1 restée, annonce 2 supprimée
  ```

#### Livrables J4
✅ 05_functions.sql (3 functions testées)  
✅ 06_procedures.sql (4 procedures testées)  
✅ 07_triggers.sql (4 triggers validés)  
✅ 08_transactions.sql (3 scenarios testés)  

---

### **JOUR 5 : Dashboard & Exploitation (8h)**

#### Matin (4h)
- [ ] **Vues Dashboard** → `09_views_dashboard.sql`

  **Vue 1 : `vw_kpi_resume`**
  ```sql
  SELECT
    COUNT(*) as total_annonces,
    SUM(CASE WHEN score_pertinence > 50 THEN 1 ELSE 0 END) as annonces_pertinentes,
    COUNT(DISTINCT source_id) as nb_sources,
    COUNT(DISTINCT acheteur_id) as nb_acheteurs,
    MIN(date_publication) as date_premiere,
    MAX(date_publication) as date_derniere
  FROM annonces;
  ```

  **Vue 2 : `vw_evolution_temporelle`**
  ```sql
  SELECT
    DATE(date_publication) as jour,
    COUNT(*) as nb_annonces,
    SUM(CASE WHEN score_pertinence > 50 THEN 1 ELSE 0 END) as nb_pertinentes,
    AVG(score_pertinence) as score_moyen
  FROM annonces
  GROUP BY DATE(date_publication)
  ORDER BY jour DESC;
  ```

  **Vue 3 : `vw_repartition_geo`**
  ```sql
  SELECT
    region,
    COUNT(*) as nb_annonces,
    SUM(montant_estime) as montant_total,
    AVG(score_pertinence) as score_moyen
  FROM annonces
  GROUP BY region
  ORDER BY nb_annonces DESC;
  ```

  **Vue 4 : `vw_alertes_critiques`**
  ```sql
  SELECT
    id, titre, source_id, montant_estime, date_limite_reponse,
    DATEDIFF(date_limite_reponse, NOW()) as jours_restants,
    score_pertinence,
    CASE
      WHEN score_pertinence > 75 AND DATEDIFF(...) < 7 THEN 'CRITIQUE'
      WHEN score_pertinence > 60 AND DATEDIFF(...) < 14 THEN 'URGENT'
      ELSE 'NORMAL'
    END as niveau_alerte
  FROM annonces
  WHERE score_pertinence > 50 AND date_limite_reponse > NOW()
  ORDER BY date_limite_reponse ASC;
  ```

  **Vue 5 : `vw_performance_source`**
  ```sql
  SELECT
    s.nom_source,
    COUNT(a.id) as nb_annonces,
    ROUND(AVG(a.score_pertinence), 2) as score_moyen,
    COUNT(CASE WHEN a.date_publication >= DATE_SUB(NOW(), INTERVAL 7 DAY) THEN 1 END) as derniers_7j,
    AVG(a.montant_estime) as montant_moyen
  FROM annonces a
  JOIN sources s ON a.source_id = s.id
  GROUP BY s.id
  ORDER BY nb_annonces DESC;
  ```

- [ ] **Requêtes Analytiques** → `10_analytics_queries.sql`
  - Tendances mots-clés (GROUP BY, COUNT)
  - Acheteurs publics principaux
  - Évolution montants moyens par mois

#### Après-midi (4h)
- [ ] **Système de Sauvegarde** → `11_backup_system.sql`
  
  - Table `log_sauvegardes` :
    ```sql
    CREATE TABLE log_sauvegardes (
      id INT PRIMARY KEY AUTO_INCREMENT,
      timestamp DATETIME DEFAULT NOW(),
      type_backup VARCHAR(50),
      fichier VARCHAR(255),
      status ENUM('OK', 'ERREUR'),
      nb_bytes BIGINT,
      duree_secondes INT,
      message_erreur TEXT
    );
    ```
  
  - Procédure `ExecuterBackup()` pour journaliser

- [ ] **Scripts Backup & Restore**
  
  **backup.sh** (Linux/Mac - cron job à 07h30 jours ouvrés)
  ```bash
  #!/bin/bash
  # mysqldump --all-databases --routines --triggers > backup_YYYY-MM-DD.sql
  # Log dans log_sauvegardes
  # Rotation : supprimer backups > 30 jours
  ```

  **backup.bat** (Windows - Task Scheduler)
  ```batch
  REM Same logic as backup.sh
  ```

  **restore.sh**
  ```bash
  # Procédure RestaurerDepuisBackup(filename)
  # mysql < backup_file.sql
  # Tests intégrité post-restore
  # Vérifier triggers, fonctions, procédures existent
  ```

#### Livrables J5
✅ 09_views_dashboard.sql (5 vues testées)  
✅ 10_analytics_queries.sql (requêtes avancées)  
✅ 11_backup_system.sql (logs + procedures)  
✅ backup.sh + backup.bat (scripts executables)  
✅ restore.sh (script restauration)  

---

### **JOUR 6 : Tests & Documentation Finale (8h)**

#### Matin (4h)
- [ ] **Tests Unitaires & E2E** → `12_tests.sql`
  
  Tests chaque fonction :
  ```sql
  SELECT CalculerScorePertinence('modulaire bâtiment', 'description...', 150000, 'Île-de-France');
  -- Vérifié : résultat entre 0 et 100, logique correct
  
  SELECT CategoriserAlerte(80, 5);
  -- Vérifié : retourne 'CRITIQUE'
  ```

  Tests chaque procédure :
  ```sql
  CALL InsererAnnonce('BOAMP', 'EXT123', 'Titre test', ...);
  CALL TraiterLotAnnonces(1, 10);
  CALL GenererKPIDashboard();
  CALL ArchiverDonneeAncienne(365);
  ```

  Tests triggers :
  - Vérifier log_metier se remplit au INSERT
  - Vérifier qualification_scores créé au INSERT
  - Vérifier notification créée si score > 75
  - Vérifier historique_annonces au UPDATE
  - Vérifier archive_annonces au DELETE

  Tests transactions :
  - Exécuter scénarios 08_transactions.sql
  - Vérifier ROLLBACK fonctionne
  - Vérifier COMMIT garde données

  Tests backup/restore :
  - Exécuter backup.sh
  - Vérifier fichier créé
  - Exécuter restore.sh
  - Vérifier données restaurées
  - Vérifier fonctions/procédures/triggers restaurés

- [ ] **Validation notebook E2E**
  - Exécuter notebook complet du début à fin
  - Vérifier extraction réussit (data.gouv.fr + BOAMP)
  - Vérifier transformation ok (annonces_cleaned.csv généré)
  - Vérifier validation passe (rapport ok)
  - Vérifier 05_insert_test_data.sql généré et exécutable

#### Après-midi (4h)
- [ ] **Documentation complète** 

  **01_schema.md** (si besoin d'ajouts)
  - Description tables
  - Clés primaires/étrangères
  - Justification design

  **LOGIC.md** → Explications détaillées
  - Chaque fonction : rôle, paramètres, retour, edge cases
  - Chaque procédure : logique métier, cas d'erreur
  - Chaque trigger : when/why/impact
  - Exemples d'utilisation

  **EXPLOITATION.md** → Guide supervision
  - Comment lancer backup (manuel vs CRON)
  - Comment restaurer
  - Monitoring : requêtes pour vérifier santé BD
  - Alertes recommandées
  - SLA : RTO (1h), RPO (4h de perte max)

  **NOTEBOOK_GUIDE.md** → Comment utiliser Unitee.ipynb
  - Prérequis (Jupyter, Python, pandas, requests)
  - Installation (pip install -r requirements.txt)
  - Exécution onglet par onglet
  - Troubleshooting (API down, connection BD)

  **PARAMETRES.md** → Explications config.yaml
  - Chaque paramètre : description, impact, comment changer
  - Sections "IMPORTANT" pour éléments critiques
  - Exemples de modifications courantes

- [ ] **Nettoyage & finalisation**
  - Vérifier tous scripts SQL syntaxe OK (sans erreurs)
  - Vérifier notebook cellules exécutables (pas d'erreurs résiduelles)
  - Générer PNG depuis PlantUML (via plantuml.com ou local)
  - Créer `requirements.txt` avec versions Python deps
  - Mettre à jour `.gitignore` (backups/, .env, __pycache__, etc.)
  - Git status clean, tous commits atomiques
  - Vérifier README.md mis à jour

#### Livrables J6
✅ 12_tests.sql (tous les tests passent)  
✅ SCHEMA.md (finalisé)  
✅ LOGIC.md (complète)  
✅ EXPLOITATION.md (exploitable)  
✅ NOTEBOOK_GUIDE.md (clair)  
✅ PARAMETRES.md (détaillée)  
✅ requirements.txt (exact)  
✅ .gitignore (approprié)  
✅ README.md (à jour)  
✅ Tous diagrammes PNG (de PlantUML)  
✅ Repo clean + ready to push  

---

## 🔧 SOURCES DE DONNÉES (Détails)

### **1. data.gouv.fr API**

**URL Base** : `https://www.data.gouv.fr/api/1/`

**Endpoint Clé** : `/datasets/?q=marchés+publics&page=1`

**Approche en Python** (Unitee.ipynb Onglet 2) :
```python
import requests
import pandas as pd

# Récupérer liste datasets
response = requests.get('https://www.data.gouv.fr/api/1/datasets/', 
                       params={'q': 'marchés publics', 'page': 1})
datasets = response.json()['data']

# Pour chaque dataset, récupérer ressources .csv / .json
for dataset in datasets:
    for resource in dataset['resources']:
        if resource['format'].lower() in ['csv', 'json']:
            # Télécharger fichier
            df = pd.read_csv(resource['url'])
            # Mapper colonnes pour schéma Unitee
```

**Avantages** :
- ✅ Données officielles gouvernementales
- ✅ Libre d'accès (pas de clé)
- ✅ Formats multiples (CSV, JSON, XML)
- ✅ Mise à jour régulière

**Documentation** : À créer dans `data_sources/data_gouv_fr.md` avec :
- Liste endpoints
- Paramètres requête
- Format réponses
- Exemples appels

---

### **2. API BOAMP**

**URL Base** : `https://www.boamp.fr/`

**Approche** :
- Vérifier si API REST directe (/api/...) ou scraping HTML nécessaire
- Filtrer sur mots-clés (config.yaml)
- Récupérer JSON/XML si possible, sinon scraper BeautifulSoup

**Fallback** : Si API pas accessible ou rate-limited
→ Utiliser données synthétiques test (`data/samples/sample_data.json`)

**Documentation** : À créer dans `data_sources/boamp_api.md` avec :
- Endpoint(s) découverts
- Authentification (si required)
- Paramètres filtrage
- Format réponses

---

### **3. Données Synthétiques (test/demo)**

**Fichier** : `data/samples/sample_data.json`

100-200 annonces fictives pour tests en cas :
- API down
- Rate limiting
- Développement local sans internet

**Format** :
```json
[
  {
    "id": "1",
    "source": "BOAMP",
    "titre": "Fourniture de bâtiments modulaires - Île-de-France",
    "description": "Marché pour construction modulaire...",
    "acheteur": "Conseil régional Île-de-France",
    "montant": 500000,
    "date_publication": "2026-04-08",
    "date_limite": "2026-05-08",
    "localisation": "Île-de-France",
    "url": "https://..."
  },
  ...
]
```

---

## ⚙️ FICHIERS DE CONFIGURATION

### **config.yaml** (Paramètres ajustables)

À créer avec structure YAML, documenté chaque paramètre.

Voir fichier dédié : `config.yaml` (créé en parallèle).

---

### **sources_config.yaml** (URLs API)

À découvrir et documenter pendant J2.

```yaml
data_gouv_fr:
  enabled: true
  api_base: "https://www.data.gouv.fr/api/1/"
  endpoints:
    search: "/datasets/?q=marchés+publics&page={page}"

boamp:
  enabled: true
  url_base: "https://www.boamp.fr/"
  endpoints:
    search: "/pages/recherche/?..." # À découvrir
```

---

### **PARAMETRES.md** (Guide d'aide)

Document distinct avec explications pour chaque paramètre.

À créer le même jour que config.yaml pour cohérence.

---

## 🎯 POINTS CLÉS À NE PAS MANQUER

### **Prérequis avant J1**
- ✅ Docker installé + image MySQL disponible
- ✅ PlantUML installé OU accès plantuml.com
- ✅ Jupyter/Python 3.8+ installé
- ✅ Internet stable pour APIs data.gouv.fr + BOAMP

### **À contrôler chaque jour**
- ✅ Git commits réguliers (1-2 par demi-jour)
- ✅ Fichiers SQL vérifiés (SYNTAX CHECK)
- ✅ Notebook cellules exécutables (pas d'erreurs)
- ✅ Tests passent

### **Risques à gérer**

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|-----------|
| API data.gouv.fr down | MOYEN | MOYEN | Fallback données synthétiques |
| BOAMP API change format | FAIBLE | MOYEN | Documentation + tests flexibles |
| Doublons non détectés | MOYEN | ÉLEVÉ | Clé composite (source+id_externe) |
| Insertion lente | FAIBLE | MOYEN | Batch mode + BULK INSERT |
| Triggers lents | MOYEN | MOYEN | Index sur colonnes log |
| Mots-clés non pertinents | MOYEN | FAIBLE | Analyse J3 → config.yaml update |

---

## 📊 ESTIMATION CHARGE HORAIRE

| Jour | Phase | Durée | Critique ? | Dépendances |
|------|-------|-------|-----------|-------------|
| J1 | Conception | 8h | ✅ OUI | Aucune |
| J2 | Setup + Extraction | 8h | ✅ OUI | J1 ✅ |
| J3 | Transformation | 8h | ✅ OUI | J2 ✅ |
| J4 | Logique SQL | 8h | ✅ OUI | J3 ✅ |
| J5 | Dashboard + Ops | 8h | ⚠️ MOYEN | J4 ✅ |
| J6 | Tests + Docs | 8h | ✅ OUI | J5 ✅ |
| **TOTAL** | | **48h** | | **Séquentiel** |

---

## ✅ CRITÈRES DE SUCCÈS FINAL

À la fin du projet tu dois avoir et pouvoir démontrer :

1. ✅ **Schéma DB** 
   - Normalisé 3FN
   - MCD/MLD/physique en PlantUML (.puml files)
   - PNG exports fonctionnels

2. ✅ **Données réelles** 
   - 100-500 annonces chargées
   - Issues de data.gouv.fr API + BOAMP
   - Validation passée (rapport généré)

3. ✅ **Logique SQL avancée** 
   - 3 fonctions testées (calcul score, catégorisation, normalisation)
   - 4 procédures testées (insert, batch, KPI, archivage)
   - 4 triggers testés (BEFORE/AFTER INSERT/UPDATE/DELETE)

4. ✅ **Notebook Jupyter** 
   - 5 onglets fonctionnels (setup, extraction, transformation, validation, export)
   - Reproducible (exécutable du début à fin sans erreur)
   - Config gérée via YAML

5. ✅ **Dashboard + KPIs** 
   - 5+ vues SQL définies
   - Requêtes analytiques
   - Cohérence métier vérifiée

6. ✅ **Automatisation** 
   - Backup quotidien fonctionnel (script + logging)
   - Restauration testée
   - Rotation 30 jours ok

7. ✅ **Documentation complète** 
   - SCHEMA.md (description détaillée)
   - LOGIC.md (fonctions/procs/triggers)
   - EXPLOITATION.md (guide opérationnel)
   - NOTEBOOK_GUIDE.md (comment utiliser)
   - PARAMETRES.md (explications config)

8. ✅ **Tests & Qualité** 
   - Tous les scripts SQL testés + passent
   - Notebook E2E fonctionne
   - Transactions COMMIT/ROLLBACK vérifiées
   - Triggers loggent correctement

9. ✅ **Configuration** 
   - config.yaml avec paramètres clés
   - sources_config.yaml avec URLs APIs
   - PARAMETRES.md détaillée
   - Modifications faciles pour éléments importants

---

## ❓ QUESTIONS EN SUSPENS (Clarifiées)

| Question | Réponse |
|----------|---------|
| Mots-clés pertinents ? | À découvrir via J3 → top 5 via analyse TF-IDF |
| Montant minimum ? | 0€ pour l'instant (inclure tout) |
| Fréquence import ? | Quotidien à 07h30 jours ouvrés |
| Régions d'intérêt ? | Toute la France |
| Format MCD/MLD ? | PlantUML (3 fichiers : concept, logique, physique) |
| Format config ? | YAML pour lisibilité + facilité modification |

---

## 🚀 COMMANDE DE DÉMARRAGE J1

```bash
# 1. Créer dossiers
mkdir -p sql/schema sql/logic sql/analytics sql/tests
mkdir -p config data_sources data/samples docs scripts notebook

# 2. Initialiser PlantUML (pour MCD/MLD)
# - Sur plantuml.com
# - Ou localement avec :
# apt install plantuml (Linux)
# brew install plantuml (Mac)

# 3. Initialiser Jupyter
pip install -r requirements.txt
jupyter notebook

# 4. Initialiser Docker
docker-compose up -d

# 5. Git commit initial
git add .
git commit -m "init: project structure and planning"
```

---

**CE PLAN EST PRÊT POUR DÉMARRAGE J1. BON DÉVELOPPEMENT !**

Dernière mise à jour : 8 avril 2026
