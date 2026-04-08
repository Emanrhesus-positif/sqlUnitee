# ⚙️ GUIDE DES PARAMÈTRES - UNITEE

Ce document explique **chaque paramètre** du projet et comment les modifier sans casser le système.

---

## 📋 TABLE DES MATIÈRES

1. [Vue d'ensemble](#vue-densemble)
2. [Paramètres critiques](#paramètres-critiques)
3. [Mots-clés pertinents](#mots-clés-pertinents)
4. [Configuration sources de données](#configuration-sources-de-données)
5. [Paramètres de montant](#paramètres-de-montant)
6. [Paramètres géographiques](#paramètres-géographiques)
7. [Paramètres de sauvegarde](#paramètres-de-sauvegarde)
8. [Paramètres notebook](#paramètres-notebook)
9. [Troubleshooting](#troubleshooting)

---

## 📍 VUE D'ENSEMBLE

Les paramètres sont centralisés dans **`config/config.yaml`** pour :
- Éviter modifications du code Python/SQL
- Faciliter itérations rapides
- Documenter les choix métier

**Trois niveaux de paramètres** :

| Niveau | Fichier | Fréquence modif | Impact |
|--------|---------|-----------------|--------|
| **Métier** | `config.yaml` | Régulière | ⚠️ ÉLEVÉ |
| **Technique** | `sources_config.yaml` | Rare | ⚠️ ÉLEVÉ |
| **Système** | `.env` | Très rare | 🔴 CRITIQUE |

---

## 🔴 PARAMÈTRES CRITIQUES

### ⚠️ À NE PAS MODIFIER SANS SAVOIR CE QUE VOUS FAITES

#### **1. Clé composite doublon**
**Où** : Schéma BD (table annonces)  
**Valeur** : `(source_id, id_externe)`

```yaml
# ❌ DANGER : Ne pas changer cette combinaison !
# Cela risque d'autoriser les doublons
```

**Impact** : Si vous changez, vous pouvez avoir :
- Mêmes annonces en double dans BD
- Notifications multiples pour même marché
- Données corrompues

**Si vous vraiment besoin** : Recréer table + données

---

#### **2. Colonne de priorité**
**Où** : Table `annonces` - colonne `score_pertinence`  
**Type** : INT (0-100)  
**Logique** : Voir fonction `CalculerScorePertinence()` dans `LOGIC.md`

```yaml
# ❌ DANGER : Ne pas modifier la formule de scoring
# sans mettre à jour :
# 1. Fonction SQL CalculerScorePertinence()
# 2. Procédure GenererKPIDashboard()
# 3. Vues (vw_alertes_critiques, etc.)
```

---

#### **3. Calendrier de sauvegarde**
**Où** : `.env` + `config.yaml`  
**Fréquence** : Quotidienne 22h00  
**Rétention** : 30 jours

```yaml
# ❌ DANGER : Si vous baissez rétention à < 7 jours,
# vous risquez de perdre données si incident
```

**Recommandation** : Garder au moins 30 jours pour DR

---

## 📌 MOTS-CLÉS PERTINENTS

**Fichier** : `config/config.yaml` - section `keywords`

### Structure

```yaml
keywords:
  primary:        # Mots-clés de recherche principaux
    - "modulaire"
    - "préfabriqué"
    - "assemblage rapide"
    - "bâtiment en kit"
    - "base vie"
  secondary:      # Mots-clés secondaires (boost moins important)
    - "extension"
    - "classe temporaire"
    - "structure préfabriquée"
```

### Comment Modifier

#### **Ajouter un mot-clé**
```yaml
keywords:
  primary:
    - "modulaire"
    - "mon_nouveau_keyword"    # ← Ajouter ici
```

**Impact** :
- ✅ Meilleure détection d'annonces pertinentes
- ⚠️ Peut ajouter du bruit si trop générique

**À vérifier après** :
```sql
-- Vérifier que le keyword est bien détecté
SELECT * FROM annonces 
WHERE titre LIKE '%mon_nouveau_keyword%' 
  OR description LIKE '%mon_nouveau_keyword%';
```

---

#### **Retirer un mot-clé**
```yaml
keywords:
  primary:
    - "modulaire"
    # - "ancien_keyword"    # ← Commenter/retirer
```

**Impact** :
- ✅ Moins de faux positifs
- ⚠️ Risque de manquer des marchés pertinents

---

#### **Découvrir les TOP 5 keywords pertinents** (Jour 3)

**Processus** :
1. Extraire données réelles (Notebook Onglet 2)
2. Analyser TOP mots-clés les plus fréquents
3. Vérifier lesquels sont pertinents métier
4. Mettre à jour `config.yaml`

**Requête SQL pour analyse post-import** :
```sql
SELECT 
  mot_cle,
  COUNT(*) as frequence,
  AVG(a.score_pertinence) as score_moyen
FROM mots_cles mk
JOIN annonce_mot_cle amk ON mk.id = amk.mot_cle_id
JOIN annonces a ON amk.annonce_id = a.id
GROUP BY mot_cle
ORDER BY frequence DESC
LIMIT 10;
```

---

## 🔗 CONFIGURATION SOURCES DE DONNÉES

**Fichier** : `config/sources_config.yaml`

### data.gouv.fr API

```yaml
data_gouv_fr:
  enabled: true
  api_base: "https://www.data.gouv.fr/api/1/"
  endpoints:
    search: "/datasets/?q=marchés+publics&page={page}"
    dataset: "/datasets/{id}/"
    resources: "/datasets/{id}/resources/"
  
  # Paramètres de recherche
  search_params:
    q: "marchés publics"
    max_pages: 10            # Récupérer max 10 pages de résultats
    format_filter: ["csv", "json"]  # Accepter ces formats
  
  # Retry logic en cas d'erreur
  retry:
    max_attempts: 3
    timeout_seconds: 30
    backoff_multiplier: 2
```

**À modifier si** :
- API change (endpoint différent)
- Vous voulez chercher d'autres données
- Rate limiting détecté

**Comment tester** :
```bash
# Dans le notebook Onglet 2
curl "https://www.data.gouv.fr/api/1/datasets/?q=marchés+publics&page=1"
# Vérifier réponse JSON valide
```

---

### BOAMP API

```yaml
boamp:
  enabled: true
  url_base: "https://www.boamp.fr/"
  endpoints:
    search: "/pages/recherche/?keywords={keywords}"  # À découvrir
  
  search_params:
    keywords: "modulaire OR préfabriqué"
    date_from: "{7_days_ago}"  # Derniers 7 jours
```

**À découvrir pendant J2** :
- Endpoint exact pour recherche
- Format paramètres
- Authentification (si required)
- Format réponse (JSON/HTML/XML)

---

## 💰 PARAMÈTRES DE MONTANT

**Fichier** : `config/config.yaml` - section `procurement`

### Structure

```yaml
procurement:
  min_amount: 0              # ← IMPORTANT : montant minimum en EUR
  max_amount: null           # null = pas de max
  currency: "EUR"
  
  # Paliers pour scoring
  scoring_thresholds:
    very_high: 500000        # +25 points si > 500k
    high: 100000             # +15 points si > 100k
    medium: 50000            # +5 points si > 50k
```

### Comment Modifier

#### **Augmenter montant minimum**
```yaml
procurement:
  min_amount: 50000    # ← Filtrer marchés < 50k€
```

**Impact** :
- ✅ Moins d'annonces triviales
- ⚠️ Risque de manquer opportunités petites

**À vérifier après** :
```sql
-- Vérifier combien d'annonces exclues
SELECT COUNT(*) FROM annonces 
WHERE montant_estime < 50000;
```

---

#### **Ajuster paliers de scoring**
```yaml
scoring_thresholds:
  very_high: 1000000    # ← Augmenter seuil high-value
  high: 200000
  medium: 100000
```

**Impact** :
- Distribue points de scoring différemment
- Affecte quels marchés sont "CRITIQUE" vs "URGENT"
- Recalculer scores après changement

**Requête de recalcul** :
```sql
UPDATE qualification_scores qs
SET qs.score_pertinence = CalculerScorePertinence(...)
WHERE qs.annonce_id IN (SELECT id FROM annonces);
```

---

## 🗺️ PARAMÈTRES GÉOGRAPHIQUES

**Fichier** : `config/config.yaml` - section `regions`

### Structure

```yaml
regions:
  include_all: true           # true = toute la France
  excluded: []                # Régions à exclure
  
  # Si include_all: false, lister régions inclusives
  included:
    - "Île-de-France"
    - "Occitanie"
    - "Auvergne-Rhône-Alpes"
```

### Comment Modifier

#### **Inclure seulement certaines régions**
```yaml
regions:
  include_all: false
  included:
    - "Île-de-France"
    - "Provence-Alpes-Côte d'Azur"
```

**Impact** :
- ✅ Focus sur régions d'intérêt
- ⚠️ Manquer opportunités ailleurs

---

#### **Exclure certaines régions**
```yaml
regions:
  include_all: true
  excluded:
    - "Mayotte"              # Trop loin
    - "La Réunion"           # Trop loin
```

**À faire après** :
```sql
-- Vérifier filtrage fonctionne
SELECT COUNT(DISTINCT region) FROM annonces;
```

---

## 🔄 PARAMÈTRES DE SAUVEGARDE

**Fichier** : `config/config.yaml` - section `backup` + `.env`

### Structure

```yaml
backup:
  enabled: true
  frequency: "daily"         # daily, weekly, monthly
  time: "22:00"              # HH:MM en UTC
  timezone: "Europe/Paris"
  
  # Retention policy
  retention:
    days: 30                 # Garder 30 jours
    keep_latest: true        # Toujours garder dernière
  
  # Destination
  location: "./backups"      # Dossier local
  remote_backup: false       # Si true, envoyer ailleurs
  
  # Logging
  log_to_database: true      # Journaliser dans log_sauvegardes
```

### Comment Modifier

#### **Changer fréquence de sauvegarde**
```yaml
backup:
  frequency: "weekly"        # ← Passer à hebdo
  time: "02:00"              # À 2h du matin dimanche
```

**Avant de changer** : ⚠️ Évaluer vos besoins RTO/RPO
- RTO (Recovery Time Objective) : Combien de temps pour restaurer ?
- RPO (Recovery Point Objective) : Perte de données acceptable ?

**Recommandation** : Garder au minimum quotidien

---

#### **Augmenter rétention**
```yaml
backup:
  retention:
    days: 90    # ← Garder 90 jours au lieu de 30
```

**Impact** :
- ✅ Plus d'historique pour restore
- ⚠️ Plus d'espace disque utilisé

---

## 📓 PARAMÈTRES NOTEBOOK

**Fichier** : Débugage avec Unitee.ipynb

### Variables à ajuster dans Onglet 1 (Setup)

```python
# Chemins
DATA_RAW_PATH = "./data/annonces_raw.csv"
DATA_CLEAN_PATH = "./data/annonces_cleaned.csv"
CONFIG_PATH = "./config/config.yaml"

# API
API_TIMEOUT = 30            # Secondes avant timeout
MAX_RETRIES = 3             # Retries en cas d'erreur
BATCH_SIZE = 100            # Annonces par batch

# BD
DB_HOST = "localhost"
DB_PORT = 3306
DB_USER = os.getenv("DB_USER")      # Lire depuis .env
DB_PASS = os.getenv("DB_PASS")
DB_NAME = "unitee"
```

### Comment Modifier

#### **Augmenter timeout API**
```python
API_TIMEOUT = 60    # Si APIs lentes
```

---

#### **Réduire batch size pour moins de RAM**
```python
BATCH_SIZE = 50     # Si mémoire limitée
```

---

## 🆘 TROUBLESHOOTING

### **Problème 1 : "Trop de faux positifs dans annonces détectées"**

**Cause** : Mots-clés trop génériques

**Solution** :
```yaml
# config.yaml - retirer keywords trop large
keywords:
  primary:
    # - "bâtiment"    # ← TROP générique, remplacer par
    - "bâtiment modulaire"
    - "bâtiment préfabriqué"
```

**Vérifier après** :
```sql
SELECT COUNT(*) FROM annonces WHERE score_pertinence > 50;
-- Nombre devrait rester stable ou diminuer légèrement
```

---

### **Problème 2 : "Certains marchés importants manquent"**

**Cause** : Keywords pas assez complets

**Solution** : Analyser données importées
```sql
SELECT titre, description FROM annonces 
WHERE score_pertinence < 50 
  AND montant_estime > 100000  -- Montant important
LIMIT 10;

-- Identifier mots-clés manquants
-- Ajouter à config.yaml
```

---

### **Problème 3 : "Sauvegarde prend trop de place disque"**

**Cause** : Rétention trop longue

**Solution** :
```yaml
backup:
  retention:
    days: 14    # Réduire de 30 à 14
```

**Nettoyer ancien backup** :
```bash
rm backups/*-more-than-30-days-old.sql
```

---

### **Problème 4 : "API data.gouv.fr timeout"**

**Cause** : Serveur lent ou réseau instable

**Solution** :
```python
# Unitee.ipynb - Onglet 1
API_TIMEOUT = 60    # Augmenter timeout
MAX_RETRIES = 5     # Plus de tentatives
```

**Ou utiliser fallback** :
```python
# Utiliser données synthétiques si API fail
USE_FALLBACK_DATA = True
```

---

### **Problème 5 : "Score pertinence ne monte pas au-delà de 50"**

**Cause** : Données ne correspondent pas aux keywords

**Solution** : Vérifier mapping
```sql
-- Vérifier mots-clés détectés
SELECT DISTINCT mot_cle FROM mots_cles ORDER BY mot_cle;

-- Comparer avec config.yaml keywords
-- Ajuster si nécessaire
```

---

## 📝 TEMPLATE : CRÉER UNE NOUVELLE CONFIGURATION

Si vous voulez tester une nouvelle stratégie :

```yaml
# config_test.yaml (copie de config.yaml)

# Scénario test : focus très high-value à Île-de-France
keywords:
  primary:
    - "modulaire"
    - "préfabriqué"

procurement:
  min_amount: 1000000    # Très haute valeur

regions:
  include_all: false
  included:
    - "Île-de-France"

backup:
  retention:
    days: 7    # Rétention courte pour test
```

**Pour utiliser** :
```python
# Unitee.ipynb - Onglet 1
CONFIG_PATH = "./config/config_test.yaml"
```

---

## ✅ CHECKLIST AVANT MODIFICATION DE CONFIG

Avant de changer un paramètre :

- [ ] Lire cette section complètement
- [ ] Comprendre "Impact"
- [ ] Avoir backup de config.yaml original
- [ ] Tester dans config_test.yaml d'abord
- [ ] Vérifier requête SQL post-modification
- [ ] Committer change avec message clair
- [ ] Documenter la raison du changement

---

**DERNIER POINT IMPORTANT** :

> ⚠️ **Toute modification de paramètres métier doit être validée avec les responsables métier (Unitee)**, surtout pour :
> - Keywords pertinents
> - Montants minimums
> - Régions d'intérêt
> - Niveaux d'alerte

---

*Dernière mise à jour : 8 avril 2026*
