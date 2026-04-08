# 📊 UNITEE - Plateforme de Veille Automatisée des Marchés Publics

[![Status](https://img.shields.io/badge/status-en%20cours-yellow)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()
[![Python](https://img.shields.io/badge/python-3.8+-blue)]()
[![MySQL](https://img.shields.io/badge/mysql-8.0+-brightgreen)]()

## 🎯 Vue d'ensemble

**UNITEE** est une plateforme de veille automatisée pour les marchés publics français, spécialisée dans le **secteur du bâtiment modulaire et préfabriqué**.

Le système :
- ✅ Récupère les annonces depuis **data.gouv.fr** et **BOAMP**
- ✅ Transforme et valide les données via **Jupyter Notebook**
- ✅ Qualifie les opportunités via **logique SQL avancée**
- ✅ Expose les KPIs via **vues SQL et Dashboard**
- ✅ Automatise la sauvegarde quotidienne

---

## 📋 TABLE DES MATIÈRES

- [🚀 Démarrage rapide](#-démarrage-rapide)
- [📊 Architecture](#-architecture)
- [📁 Structure](#-structure-du-projet)
- [📅 Planning](#-planning-6-jours)
- [📖 Documentation](#-documentation)
- [🆘 Troubleshooting](#-troubleshooting)

---

## 🚀 Démarrage rapide

### Prérequis

```bash
# Système
- Docker + Docker Compose
- Python 3.8+ avec pip
- Git

# Dépendances Python
pip install -r requirements.txt
```

### Installation (5 min)

```bash
# 1. Cloner repo
git clone https://github.com/sqlunitee/sqlunitee.git
cd sqlunitee

# 2. Setup Python
pip install -r requirements.txt

# 3. Setup Docker (MySQL + PhpMyAdmin)
docker-compose up -d

# 4. Vérifier MySQL
sleep 30
mysql -h localhost -u unitee_user -p -D unitee

# 5. Lancer Notebook
jupyter notebook notebook/Unitee.ipynb
```

---

## 📊 Architecture

```
data.gouv.fr + BOAMP API
        ↓ HTTP/REST
  Unitee.ipynb (Jupyter)
    • Extraction
    • Transformation
    • Validation
    • Export SQL
        ↓ SQL INSERT
  MySQL 8.0 (Docker)
    • Tables (11)
    • Fonctions (3)
    • Procédures (4)
    • Triggers (4)
        ↓ SELECT
  Dashboard & KPIs
    • Opportunités
    • Alertes
    • Statistiques
```

---

## 📁 Structure du projet

```
sqlUnitee/
├── Plan.md                    ← À LIRE D'ABORD !
├── config/
│   ├── config.yaml            ← Paramètres métier
│   ├── PARAMETRES.md          ← Explications
│   └── sources_config.yaml    ← URLs API
├── notebook/
│   └── Unitee.ipynb           ← Extraction + Transformation
├── sql/
│   ├── schema/                ← MCD/MLD/physique + DDL
│   ├── logic/                 ← Fonctions/Procédures/Triggers
│   ├── analytics/             ← Vues + Backup
│   └── tests/                 ← Tests unitaires
├── scripts/
│   ├── backup.sh              ← Sauvegarde quotidienne
│   └── restore.sh             ← Restauration
├── data/
│   ├── annonces_raw.csv
│   ├── annonces_cleaned.csv
│   └── samples/sample_data.json
├── docs/
│   ├── SCHEMA.md
│   ├── LOGIC.md
│   ├── EXPLOITATION.md
│   └── NOTEBOOK_GUIDE.md
├── docker-compose.yml
└── requirements.txt
```

**LIRE EN PREMIER** : `Plan.md` (planning détaillé 6 jours)

---

## 📅 Planning (6 jours)

| Jour | Tâche | Livrables |
|------|-------|-----------|
| J1 | Conception BD | MCD/MLD/physique + DDL |
| J2 | Setup + Extraction | Docker + Notebook Onglets 1-2 |
| J3 | Transformation | Notebook Onglets 3-5 + données chargées |
| J4 | SQL avancé | Fonctions + Procédures + Triggers |
| J5 | Dashboard + Backup | Vues KPI + scripts sauvegarde |
| J6 | Tests + Docs | Documentation finale + tests E2E |

Voir `Plan.md` pour détails complets.

---

## 📖 Documentation

| Document | Contenu |
|----------|---------|
| **Plan.md** | ⭐ Planning détaillé + architecture |
| **config/PARAMETRES.md** | Comment modifier les paramètres |
| **docs/SCHEMA.md** | Schéma détaillé |
| **docs/LOGIC.md** | Fonctions/Procédures/Triggers |
| **docs/EXPLOITATION.md** | Guide opérationnel |
| **docs/NOTEBOOK_GUIDE.md** | Utilisation notebook |

---

## ⚙️ Configuration

**Fichier** : `config/config.yaml`

```yaml
# Mots-clés de recherche
keywords:
  primary:
    - "modulaire"
    - "préfabriqué"
    - "assemblage rapide"

# Montant minimum
procurement:
  min_amount: 0           # 0 = inclure tout

# Sauvegarde
backup:
  frequency: "daily"
  time: "22:00"
  retention_days: 30
```

**Pour modifier** : Lire `config/PARAMETRES.md`

---

## 🗄️ Base de données

### Accès

```bash
# MySQL direct
mysql -h localhost -u unitee_user -p -D unitee

# PhpMyAdmin (web)
http://localhost:8080
```

### Tables (11)

- Métier : `annonces`, `sources`, `acheteurs`, `mots_cles`
- Qualification : `qualification_scores`, `notifications`
- Audit : `log_technique`, `log_metier`, `historique_annonces`, `log_sauvegardes`
- Liaison : `annonce_mot_cle` (N:N)

---

## 📈 Jupyter Notebook

### 5 Onglets

1. **Setup** - Imports + configuration YAML
2. **Extraction** - data.gouv.fr + BOAMP API
3. **Transformation** - Nettoyage + enrichissement
4. **Validation** - Tests de cohérence
5. **Export** - SQL INSERT + CSV

### Utilisation

```bash
jupyter notebook notebook/Unitee.ipynb
# Puis exécuter Onglet 1 → 5
```

---

## 🔄 Sauvegarde

### Manuel

```bash
./scripts/backup.sh              # Linux/Mac
backup.bat                       # Windows
```

### Automatique

Configure cron (Linux) ou Task Scheduler (Windows) pour exécuter à 22h00 quotidien.

Voir `docs/EXPLOITATION.md` pour détails.

---

## 🆘 Troubleshooting

**MySQL n'active pas ?**
```bash
docker-compose logs mysql
docker-compose down && docker-compose up -d
```

**API timeout ?**
```yaml
# config.yaml
notebook:
  api:
    timeout_seconds: 60
```

**Besoin d'aide ?** → Voir `Plan.md` section Troubleshooting

---

## 📞 Support

1. **Configuration** → `config/PARAMETRES.md`
2. **SQL** → `docs/LOGIC.md`
3. **Notebook** → `docs/NOTEBOOK_GUIDE.md`
4. **Opérationnel** → `docs/EXPLOITATION.md`

---

**Dernière mise à jour** : 8 avril 2026

