# GUIDE TESTS DAY 1 - VALIDATION SCHÉMA

## 📋 Checklist Tests Avant Phase 2

Avant de lancer l'extraction de données (Phase 2), tu dois valider :

### ✅ Tests Critiques (Obligatoires)

1. **Docker MySQL est démarré**
   - Container running
   - Port 3306 accessible
   - Credentials fonctionnent

2. **DDL Scripts exécutés avec succès**
   - 11 tables créées
   - Données initiales chargées
   - Indexes créés (~55 total)

3. **Contraintes validées**
   - UNIQUE (source_id, id_externe) rejette doublons
   - CHECK constraints rejettent données invalides
   - Foreign Keys rejettent références manquantes
   - timestamp_maj se met à jour automatiquement

4. **Sample INSERT fonctionne**
   - Annonce + keywords inserted
   - Requêtes SELECT retournent données
   - Queries utilisent les indexes

---

## 🚀 Comment Exécuter les Tests

### Étape 1 : Démarrer Docker

```bash
docker-compose up -d
sleep 30  # Attendre MySQL démarrage
docker ps | grep mysql
```

### Étape 2 : Exécuter les DDL scripts

```bash
# Depuis le répertoire du projet
mysql -h localhost -u unitee_user -p unitee < sql/schema/02_create_tables.sql
mysql -h localhost -u unitee_user -p unitee < sql/schema/03_create_indexes.sql
mysql -h localhost -u unitee_user -p unitee < sql/schema/04_create_base_data.sql
```

Ou via MySQL prompt :
```sql
USE unitee;
SOURCE sql/schema/02_create_tables.sql;
SOURCE sql/schema/03_create_indexes.sql;
SOURCE sql/schema/04_create_base_data.sql;
```

### Étape 3 : Exécuter les tests

```bash
mysql -h localhost -u unitee_user -p unitee < sql/tests/01_test_schema.sql
```

Ou via MySQL prompt :
```sql
USE unitee;
SOURCE sql/tests/01_test_schema.sql;
```

---

## 📊 Résultats Attendus

### Test 1 : Vérification 11 Tables
```
nombre_tables | resultat
11            | SUCCÈS
```

### Test 2 : Données Initiales
```
sources      : 3 rows (data.gouv.fr, BOAMP, synthetic)
mots_cles    : 10 rows (5 PRIMARY + 5 SECONDARY)
acheteurs    : 32 rows (collectivités + état + entreprises publiques)
annonces     : 0 rows (import Day 2)
```

### Test 3 : Doublon Detection
```
SUCCÈS - Doublon correctement rejeté par contrainte UNIQUE ✓
```

### Test 4 : CHECK Constraints
```
TEST 4a : Titre court correctement rejeté ✓
TEST 4b : Montant négatif correctement rejeté ✓
TEST 4c : Logique dates correctement validée ✓
```

### Test 5 : Foreign Keys
```
TEST 5a : FK source_id invalide correctement rejeté ✓
TEST 5b : FK acheteur_id invalide correctement rejeté ✓
```

### Test 6 : Sample INSERT
```
Annonce #2 insérée avec succès
Keywords liés à l'annonce avec succès
```

### Test 7 : Query Performance
Tous les EXPLAIN FORMAT=JSON doivent montrer :
- `type: "range"` ou `type: "ref"` (pas `type: "ALL"`)
- Utilisation des indexes (index_name non null)
- Rows examinées < 100 (même avec 180k annonces)

### Test 8 : Indexes
```
total_indexes > 50
SUCCÈS - Indexes stratégiques créés
```

---

## 🔍 Si tu as des erreurs ?

### Erreur: "Table already exists"
```bash
# Nettoyer et recommencer
docker exec mysql-unitee mysql -u unitee_user -p unitee -e "DROP TABLE IF EXISTS annonces; DROP TABLE IF EXISTS sources;"
# Puis relancer les DDL scripts
```

### Erreur: "Access denied for user"
```bash
# Vérifier credentials dans .env
cat .env | grep DB_
# Ou passer credentials en ligne:
mysql -h localhost -u root -p
```

### Erreur: "Duplicate entry" sur UNIQUE
C'est BON ! Ça veut dire la contrainte UNIQUE fonctionne. C'est test réussi ✓

### Erreur: "Foreign key constraint fails"
C'est BON ! Ça veut dire la constraint FK fonctionne. C'est test réussi ✓

### Erreur: "Check constraint fails"
C'est BON ! Ça veut dire le CHECK fonctionne. C'est test réussi ✓

---

## 📈 Taille Base Données Attendue

Après tous les tests :

```
Database Size : ~5-10 MB
- sources    : < 1 KB
- acheteurs  : ~50 KB
- mots_cles  : ~5 KB
- annonces   : ~500 bytes (test data only)
- log tables : ~1 KB
```

---

## ✅ Validation Complète

Quand tous les tests passent ✓, tu es prêt pour :

### Phase 2 (Day 2) :
- Lancer Jupyter Notebook
- Onglet 1 : Setup (charger config.yaml, configure APIs)
- Onglet 2 : Extraction (import data.gouv.fr + BOAMP)
- Tester insertion dans annonces
- Remplir `sources_config.yaml` avec endpoints réels

---

## 📝 Notes importantes

**Pas besoin de tester manuellement chaque constraint** si tu exécutes `01_test_schema.sql` :
- Le script teste automatiquement toutes les contraintes
- Affiche SUCCÈS/ERREUR pour chaque test
- Génère un résumé final

**Les triggers n'existent pas encore** (J4) :
- timestamp_maj ON UPDATE fonctionne nativement (pas trigger)
- Les triggers BEFORE/AFTER INSERT seront créés J4
- Les procedures seront créées J4

**Les views et KPI n'existent pas encore** (J5) :
- qualification_scores table existe
- Mais les views KPI seront créées J5
- Les procédures backup seront créées J5

---

## 🎯 Suivant

Une fois tous les tests verts ✓ :

```bash
# Commit test scripts
git add sql/tests/01_test_schema.sql sql/tests/README.md
git commit -m "test: add Day 1 schema validation tests"

# Passer à Phase 2
# → Lancer docker-compose up
# → Ouvrir Jupyter Notebook
# → Onglet 1 : Setup
# → Onglet 2 : Extraction (API data.gouv.fr + BOAMP)
```

Besoin d'aide pour exécuter les tests ?

*Document créé le 2026-04-08*
