# Plan d'Action - Projet sqlUnitee
## Veille Automatisée des Marchés Publics (Bâtiment Modulaire)

**Équipe :** 3 personnes  
**Date :** 8 avril 2026  
**Durée estimée :** 6 jours

---

## 📋 Résumé du Projet

Créer une **plateforme de veille automatisée** des marchés publics dans le secteur du bâtiment modulaire utilisant SQL avancé.

**Contexte :** L'entreprise unitee (bâtiments modulaires) effectue manuellement la veille des appels d'offres. Solution demandée : système SQL robuste, centralisé, avec qualification automatique, logs, alertes et dashboard.

**Objectifs pédagogiques :**
- Schéma relationnel normalisé
- Fonctions et procédures SQL
- Triggers et automatisation
- Transactions et gestion d'erreur
- Sauvegarde/restauration
- Dashboard analytique

---

## 🎯 Division des Tâches (3 Personnes)

### 👤 PERSONNE 1 : Modélisation & Architecture
**Durée : 2-3 jours**

#### Objectifs
- Concevoir le schéma relationnel complet et normalisé (3FN minimum)
- Créer tous les scripts DDL
- Documenter les choix de conception

#### Tâches détaillées

1. **Identifier les entités**
   - `annonces` (marchés publics)
   - `sources` (portails : BOAMP, TED, etc.)
   - `acheteurs` (organismes émetteurs)
   - `mots_cles` (extraction automatique)
   - `annonce_mot_cle` (relation N:N)
   - `qualification_scores` (résultats calculs)

2. **Tables techniques de support**
   - `log_technique` (erreurs API, imports)
   - `log_metier` (qualification, modifications)
   - `notifications` (alertes générées)
   - `log_sauvegardes` (suivi des backups)
   - `historique_annonces` (audit des changements)

3. **Définir la structure**
   - Clés primaires (ID auto-increment)
   - Clés étrangères (intégrité référentielle)
   - Contraintes d'unicité (source + ID externe = clé composite)
   - Indices (recherche rapide sur titre, date, localisation)

4. **Créer les scripts DDL**
   - `01_create_tables.sql` → CREATE TABLE de toutes les entités
   - `02_create_indexes.sql` → Stratégie d'indexation
   - `03_alter_constraints.sql` → Contraintes métier

5. **Diagramme ER**
   - Visualisation PNG/JPG du schéma
   - Cardinalités clairement indiquées

#### Livrables
- ✅ Fichier `schema.md` (description du schéma)
- ✅ `01_create_tables.sql`
- ✅ `02_create_indexes.sql`
- ✅ Diagramme ER (image)
- ✅ Document justifications (pourquoi ces entités, ces relations)

---

### 👤 PERSONNE 2 : Logique Métier (Fonctions, Procédures, Triggers)
**Durée : 3-4 jours**

#### Objectifs
- Implémenter la logique métier en SQL
- Automatiser les traitements critiques
- Assurer la traçabilité des opérations

#### Tâches détaillées

1. **Fonctions SQL (minimum 2-3)**

   **Fonction 1 : `CalculerScorePertinence()`**
   - Entrée : ID annonce (ou titre, description, montant, localisation)
   - Sortie : score numérique (0-100)
   - Logique :
     - Recherche mots-clés pertinents (modulaire, préfabriqué, assemblage rapide)
     - Bonus montant (si budget > seuil)
     - Bonus localisation (zones d'intérêt)
     - Formule pondérée
   - Gestion cas limites : champs NULL, descriptions vides

   **Fonction 2 : `CategoriserNiveauAlerte()`**
   - Entrée : score pertinence, date limite, montant
   - Sortie : niveau ('FAIBLE', 'MOYEN', 'ÉLEVÉ') ou BOOLEAN
   - Règles métier : score > 70 ET deadline proche = ALERTE ÉLEVÉE
   - Usage : trigger pour générer notifications

   **Fonction 3 (optionnel) : `NormaliserLocalisationAnnonce()`**
   - Entrée : localisation brute (TEXT)
   - Sortie : région/département standardisé
   - Usage : classification géographique dashboard

2. **Procédures Stockées (minimum 4)**

   **Procédure 1 : `InsererOuMettAJourAnnonce()`**
   - Paramètres : ID_source, ID_externe, titre, description, montant, localisation, URL, acheteur
   - Logique :
     - Vérifier doublon (source + ID_externe)
     - Si existe : UPDATE, sinon INSERT
     - Calculer score via fonction
     - Déterminer statut (NEW, QUALIFIED, IGNORED)
     - Appeler trigger pour log métier
   - Gestion erreur : transaction ROLLBACK si validation échoue
   - Retour : ID annonce inséré/mis à jour ou code erreur

   **Procédure 2 : `TraiterLotAnnonces()`**
   - Paramètres : @id_lot, @source_id
   - Logique :
     - Récupérer lot d'annonces en attente
     - Boucle : appeler InsererOuMettAJourAnnonce() pour chacune
     - Compter succès/erreurs
     - Journaliser résumé du traitement
     - COMMIT si tout OK, ROLLBACK si > 10% erreurs
   - Retour : @nb_inserted, @nb_updated, @nb_errors

   **Procédure 3 : `GenererDonneesDashboard()`**
   - Paramètres : @date_debut, @date_fin (optionnels)
   - Logique :
     - Calculer : nombre total annonces, nombre pertinentes (score > 50)
     - Grouper par priorité (LOW/MEDIUM/HIGH)
     - Évolution temporelle (par jour/semaine)
     - Répartition géographique (région)
     - Insérer/mettre à jour vue `vw_dashboard_kpi`
   - Retour : SELECT depuis vue

   **Procédure 4 : `PurgerDonneeAncienne()`**
   - Paramètres : @nombre_jours_retention (ex. 365)
   - Logique :
     - Archiver (copier vers table `archive_annonces`) puis supprimer les annonces > nombre_jours
     - Nettoyer logs techniques/métier > 90 jours
     - Compresser historique (garder 1 enregistrement par jour pour anciennes data)
     - Journaliser : nombre enregistrements archivés/supprimés
   - Gestion erreur : transaction atomique

3. **Triggers (minimum 3-4)**

   **Trigger 1 : `BEFORE INSERT ON annonces`**
   - Validations :
     - Titre non NULL et longueur > 5
     - Source_id doit exister
     - Date_publication <= aujourd'hui
     - Montant >= 0 si présent
   - Action : lever erreur (SIGNAL) si validation échoue

   **Trigger 2 : `AFTER INSERT ON annonces`**
   - Actions :
     - Insérer dans `log_metier` (annonce créée, par qui, quand)
     - Calculer score via fonction, insérer dans `qualification_scores`
     - Si score > 75 : créer notification dans table `notifications`
   - Optionnel : envoyer alerte e-mail (simulé par flag dans `notifications`)

   **Trigger 3 : `AFTER UPDATE ON annonces`**
   - Actions :
     - Historiser changement dans `historique_annonces` (avant/après)
     - Journaliser qui a modifié, quand, quoi
     - Recalculer score si données pertinentes changent

   **Trigger 4 (optionnel) : `BEFORE DELETE ON annonces`**
   - Actions :
     - Archiver dans table `archive_annonces`
     - Empêcher vraie suppression logique

4. **Gestion des Transactions**
   - Écrire procédure `TestTransactionScenario()`
   - Scénario 1 : Insertion lot, 1 erreur au milieu → tout ROLLBACK
   - Scénario 2 : Insertion lot, gestion partielle (garder succès, loger erreurs)
   - Démontrer : BEGIN, COMMIT, ROLLBACK, SAVEPOINT
   - Documenter : cas d'usage métier (intégrité critique pour doublons)

#### Livrables
- ✅ `04_functions.sql` (toutes les fonctions)
- ✅ `05_procedures.sql` (toutes les procédures)
- ✅ `06_triggers.sql` (tous les triggers)
- ✅ `07_transactions_tests.sql` (scénarios transactionnels)
- ✅ Document `LOGIC.md` (description logique métier, hypothèses, cas limites)

---

### 👤 PERSONNE 3 : Exploitation, Sauvegarde & Dashboard
**Durée : 2-3 jours**

#### Objectifs
- Mettre en place stratégie sauvegarde robuste
- Créer requêtes dashboard pour KPI
- Documenter exploitation & supervision

#### Tâches détaillées

1. **Stratégie de Sauvegarde Complète**

   **Script 1 : `backup.sh` (ou .bat pour Windows)**
   - Fréquence : quotidienne (22h00) + hebdomadaire (dimanche 02h00)
   - Éléments sauvegardés :
     - Structure complète (tables, index)
     - Données
     - Fonctions, procédures, triggers
     - Vues, événements
   - Commande MySQL : `mysqldump --all-databases --routines --triggers > backup_YYYY-MM-DD.sql`
   - Stockage :
     - Local : `./backups/` (conservation 30 jours)
     - Optionnel : copie externe (décrire)
   - Rotation : supprimer backups > 30 jours

   **Script 2 : `08_create_backup_log.sql`**
   - Table `log_sauvegardes` :
     - id, timestamp, type_backup, fichier, status (OK/ERREUR), nb_bytes, duree_secondes, message_erreur
   - Trigger sur début/fin backup pour journaliser

   **Script 3 : `09_restore_procedure.sql`**
   - Procédure `RestaurerDepuisBackup()` :
     - Paramètres : nom_fichier_backup
     - Action : `mysql < fichier_backup.sql`
     - Vérifications post-restore :
       - Nombre de tables
       - Existence procédures/triggers
       - Intégrité clés étrangères (FOREIGN_KEY_CHECKS)
     - Journaliser succès/erreur

   **Test de Restauration Minimale**
   - Procédure documentée :
     1. Créer BD test
     2. Restaurer depuis backup
     3. Exécuter requête de vérification (SELECT COUNT(*) depuis chaque table)
     4. Appeler procédure pour vérifier structure

2. **Requêtes & Vues pour Dashboard**

   **Vue 1 : `vw_dashboard_resume`**
   ```sql
   SELECT
     COUNT(*) as total_annonces,
     SUM(CASE WHEN score_pertinence > 50 THEN 1 ELSE 0 END) as annonces_pertinentes,
     COUNT(DISTINCT source_id) as nb_sources,
     COUNT(DISTINCT acheteur_id) as nb_acheteurs,
     MIN(date_publication) as date_premiere_annonce,
     MAX(date_publication) as date_derniere_annonce
   FROM annonces;
