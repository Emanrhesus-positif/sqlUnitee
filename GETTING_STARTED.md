# 🚀 GETTING STARTED - UNITEE

**Tu dois commencer par lire ce fichier** (5 min).

---

## 📍 TU ES OÙ MAINTENANT ?

Tous les fichiers de **plan d'action** ont été créés. Tu peux maintenant démarrer l'implémentation.

---

## ⭐ TOP 3 CHOSES À FAIRE D'ABORD

### 1️⃣ Lire `Plan.md` (15 min)
C'est le plan détaillé 6 jours avec :
- Architecture globale
- Planning jour par jour
- Explications sources de données
- Points critiques à ne pas manquer

```bash
cat Plan.md
# Ou ouvrir dans ton éditeur préféré
```

### 2️⃣ Lire `config/PARAMETRES.md` (10 min)
Explique **comment modifier les paramètres** (keywords, montants, etc.) sans casser le système.

```bash
cat config/PARAMETRES.md
```

### 3️⃣ Vérifier la structure créée
```bash
# Lister tous les fichiers créés
ls -la

# Vérifier les 3 diagrammes PlantUML
ls sql/schema/*.puml

# Vérifier les configs YAML
ls config/*.yaml
```

---

## 📋 FICHIERS CRÉÉS (À CONNAÎTRE)

### 🎯 Plan & Documentation (À LIRE)

| Fichier | Contenu |
|---------|---------|
| **Plan.md** | ⭐ Plan détaillé 6 jours (À LIRE ABSOLUMENT) |
| **README.md** | Vue d'ensemble du projet |
| **config/PARAMETRES.md** | Comment modifier les paramètres |

### ⚙️ Configuration (À ADAPTER)

| Fichier | Contenu |
|---------|---------|
| **config/config.yaml** | Paramètres métier (keywords, montants, etc.) |
| **config/sources_config.yaml** | URLs API (À découvrir J2) |
| **.env.example** | Variables d'environnement (copier en .env) |

### 📐 Diagrammes PlantUML (À GÉNÉRER PNG)

| Fichier | Contenu |
|---------|---------|
| **sql/schema/MCD.puml** | Modèle Conceptuel (métier) |
| **sql/schema/MLD.puml** | Modèle Logique (tables) |
| **sql/schema/physique.puml** | Modèle Physique (SQL MySQL) |

**Pour afficher** : Ouvrir sur [plantuml.com](https://plantuml.com) ou générer PNG avec PlantUML local.

### 🐳 Docker

| Fichier | Contenu |
|---------|---------|
| **docker-compose.yml** | Config MySQL 8.0 + PhpMyAdmin |
| **.env** | Copier depuis .env.example et remplir |

### 📓 Notebook Jupyter

| Fichier | Contenu |
|---------|---------|
| **notebook/Unitee.ipynb** | À créer J2 (structure template) |
| **requirements.txt** | Dépendances Python |

### 📁 Data Sources (À DOCUMENTER J2)

| Fichier | Contenu |
|---------|---------|
| **data_sources/SOURCES_DATA.md** | À créer : Guide récupération données |
| **data_sources/data_gouv_fr.md** | À créer : Doc API data.gouv.fr |
| **data_sources/boamp_api.md** | À créer : Doc API BOAMP |

### 📊 SQL (À CRÉER J1-J5)

Tous les fichiers SQL à créer jour par jour :

```
sql/
├── schema/
│   ├── 01_schema.md          # À créer J1
│   ├── 02_create_tables.sql  # À créer J1
│   ├── 03_create_indexes.sql # À créer J1
│   └── 04_create_base_data.sql # À créer J1
├── logic/
│   ├── 05_functions.sql      # À créer J4
│   ├── 06_procedures.sql     # À créer J4
│   ├── 07_triggers.sql       # À créer J4
│   └── 08_transactions.sql   # À créer J4
├── analytics/
│   ├── 09_views_dashboard.sql # À créer J5
│   ├── 10_analytics_queries.sql # À créer J5
│   └── 11_backup_system.sql  # À créer J5
└── tests/
    └── 12_tests.sql          # À créer J6
```

---

## 🎬 DÉMARRAGE RAPIDE (30 min)

### Step 1️⃣ : Clone + Setup Python (5 min)

```bash
# Python env
python -m venv venv
source venv/bin/activate  # Linux/Mac
# ou
venv\Scripts\activate     # Windows

# Install deps
pip install -r requirements.txt
```

### Step 2️⃣ : Setup .env (5 min)

```bash
# Copier template
cp .env.example .env

# Éditer .env avec tes valeurs réelles
# (éditeur préféré)

# ⚠️ Vérifier :
# [ ] DB_USER = unitee_user
# [ ] DB_PASS = mot de passe fort
# [ ] DB_NAME = unitee
```

### Step 3️⃣ : Lancer Docker (5 min)

```bash
# Démarrer MySQL + PhpMyAdmin
docker-compose up -d

# Attendre 30 secondes MySQL startup
sleep 30

# Vérifier
docker-compose ps
# Doit afficher 2 services UP
```

### Step 4️⃣ : Tester connexion MySQL (5 min)

```bash
# Test direct
mysql -h localhost -u unitee_user -p -D unitee
# Tape password, puis : SELECT NOW();

# Test via Python
python -c "
import mysql.connector
cnx = mysql.connector.connect(
  host='localhost',
  user='unitee_user',
  password='ton_password',
  database='unitee'
)
print('Connected OK!')
cnx.close()
"

# Test via Jupyter (Unitee.ipynb Onglet 1)
jupyter notebook notebook/Unitee.ipynb
```

### Step 5️⃣ : Vérifier PlantUML (5 min)

```bash
# Générer PNG depuis PlantUML
# Option 1 : Online
# → Ouvrir https://plantuml.com/plantuml/uml
# → Copier contenu sql/schema/MCD.puml
# → Générer PNG

# Option 2 : Local (si plantuml installé)
plantuml sql/schema/MCD.puml -o sql/schema/
plantuml sql/schema/MLD.puml -o sql/schema/
plantuml sql/schema/physique.puml -o sql/schema/
```

---

## 📅 JOUR 1 CHECKLIST

Tu dois faire ces choses **aujourd'hui** :

- [ ] Lire `Plan.md` en entier
- [ ] Copier `.env.example` en `.env` et remplir valeurs réelles
- [ ] Tester Docker : `docker-compose up -d`
- [ ] Tester connexion MySQL
- [ ] Générer PNG depuis PlantUML
- [ ] Créer `sql/schema/01_schema.md` (description schéma)
- [ ] Créer `sql/schema/02_create_tables.sql` (DDL complet)
- [ ] Créer `sql/schema/03_create_indexes.sql` (indexes)
- [ ] Créer `sql/schema/04_create_base_data.sql` (données de référence)
- [ ] Git commit : `init: database schema and architecture`

**Voir `Plan.md` - JOUR 1 pour détails exact.**

---

## 🆘 HELP & RÉFÉRENCES

| Question | Réponse |
|----------|---------|
| **Quel est le plan détaillé ?** | Lire `Plan.md` |
| **Comment modifier les paramètres ?** | Lire `config/PARAMETRES.md` |
| **SQL avancé comment ?** | Voir `docs/LOGIC.md` (à créer J4) |
| **Notebook comment utiliser ?** | Voir `docs/NOTEBOOK_GUIDE.md` (à créer J3) |
| **MySQL ne démarre pas ?** | Voir section Troubleshooting en bas |
| **Besoin schéma visuel ?** | Diagrammes PlantUML : `sql/schema/*.puml` |

---

## 🐛 TROUBLESHOOTING IMMÉDIAT

### ❌ "mysql command not found"
→ Installer MySQL client ou utiliser Docker

### ❌ "Docker not installed"
→ Installer Docker Desktop : https://www.docker.com/products/docker-desktop

### ❌ "Port 3306 already in use"
```bash
# Vérifier quoi utilise le port
lsof -i :3306

# Ou changer dans .env
DB_PORT=3307
```

### ❌ "Permission denied on docker-compose"
```bash
# Linux
sudo docker-compose up -d

# Ou ajouter user à docker group
sudo usermod -aG docker $USER
newgrp docker
```

### ❌ "Python modules not found"
```bash
# Réinstaller
pip install -r requirements.txt

# Ou utiliser venv :
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

---

## 📖 LECTURES OBLIGATOIRES (DANS CET ORDRE)

1. **CE FICHIER** (tu le lis maintenant) ✅
2. **Plan.md** (15 min) - Plan détaillé
3. **config/PARAMETRES.md** (10 min) - Paramètres
4. **README.md** (5 min) - Vue d'ensemble

**Total : 30 min de lecture avant de coder.**

---

## ✅ VÉRIFICATION FINALE

Avant de démarrer J1, vérifier :

```bash
# ✅ Tous les fichiers existent
ls Plan.md README.md config/config.yaml docker-compose.yml

# ✅ Docker fonctionne
docker --version
docker-compose --version

# ✅ Python fonctionne
python --version
pip list | grep jupyter

# ✅ PlantUML fichiers présents
ls sql/schema/*.puml

# ✅ Git propre
git status
# (Doit montrer : rien à commiter ou fichiers à tracker)
```

---

## 🚀 PROCHAINE ÉTAPE

**Lire `Plan.md`** en entier. C'est la roadmap complète 6 jours.

Après ça, tu peux commencer **JOUR 1** (Conception DB).

---

## 📞 QUESTIONS AVANT DE DÉMARRER ?

Tu peux me poser des questions sur :
- La configuration
- Les sources de données
- L'architecture
- Les technologies utilisées

**Je reste disponible** pour clarifications.

---

**Bon développement ! 🎉**

*Créé : 8 avril 2026*
