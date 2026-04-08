-- =====================================================================
-- UNITEE - Vues Dashboard KPI
-- Fichier : 09_views_dashboard.sql
-- Objet : Vues SQL pour le tableau de bord de veille marchés publics
--
-- Noms de tables conformes à 02_create_tables.sql :
--   sources, acheteurs, mots_cles, annonces, annonce_mot_cle,
--   qualification_scores, notifications, log_technique,
--   log_metier, historique_annonces, log_sauvegardes
-- =====================================================================

USE unitee;

-- =====================================================================
-- VUE 1 : vw_kpi_resume
-- Synthèse KPI globaux du portefeuille d'annonces actives
-- =====================================================================

DROP VIEW IF EXISTS vw_kpi_resume;

CREATE VIEW vw_kpi_resume AS
SELECT
    COUNT(*)                                                        AS total_annonces,
    COUNT(DISTINCT source_id)                                       AS sources_actives,
    COUNT(DISTINCT acheteur_id)                                     AS acheteurs_actifs,
    COUNT(DISTINCT region)                                          AS regions_couvertes,
    SUM(CASE WHEN montant_estime IS NOT NULL THEN 1 ELSE 0 END)    AS annonces_avec_montant,
    ROUND(AVG(montant_estime), 2)                                   AS montant_moyen,
    ROUND(MIN(montant_estime), 2)                                   AS montant_min,
    ROUND(MAX(montant_estime), 2)                                   AS montant_max,
    MIN(date_publication)                                           AS date_premiere_publication,
    MAX(date_publication)                                           AS date_derniere_publication,
    MIN(date_limite_reponse)                                        AS deadline_la_plus_proche,
    MAX(date_limite_reponse)                                        AS deadline_la_plus_lointaine,
    NOW()                                                           AS genere_le
FROM annonces
WHERE statut IN ('NEW', 'QUALIFIED');

-- =====================================================================
-- VUE 2 : vw_repartition_priorite
-- Répartition des annonces par niveau d'alerte (CRITIQUE/URGENT/NORMAL/IGNORE)
-- =====================================================================

DROP VIEW IF EXISTS vw_repartition_priorite;

CREATE VIEW vw_repartition_priorite AS
SELECT
    qs.niveau_alerte,
    COUNT(*)                                    AS nb_annonces,
    ROUND(AVG(qs.score_pertinence), 1)          AS score_moyen,
    ROUND(AVG(a.montant_estime), 2)             AS montant_moyen,
    MIN(a.date_limite_reponse)                  AS deadline_la_plus_proche,
    NOW()                                       AS genere_le
FROM qualification_scores qs
JOIN annonces a ON qs.annonce_id = a.id_annonce
WHERE a.statut IN ('NEW', 'QUALIFIED')
GROUP BY qs.niveau_alerte
ORDER BY FIELD(qs.niveau_alerte, 'CRITIQUE', 'URGENT', 'NORMAL', 'IGNORE');

-- =====================================================================
-- VUE 3 : vw_evolution_temporelle
-- Évolution quotidienne du volume de détections
-- =====================================================================

DROP VIEW IF EXISTS vw_evolution_temporelle;

CREATE VIEW vw_evolution_temporelle AS
SELECT
    DATE(date_publication)              AS date_publication,
    COUNT(*)                            AS nb_annonces,
    COUNT(DISTINCT source_id)           AS nb_sources,
    COUNT(DISTINCT acheteur_id)         AS nb_acheteurs,
    ROUND(AVG(montant_estime), 2)       AS montant_moyen,
    COUNT(DISTINCT region)              AS nb_regions,
    NOW()                               AS genere_le
FROM annonces
GROUP BY DATE(date_publication)
ORDER BY date_publication DESC;

-- =====================================================================
-- VUE 4 : vw_repartition_geo
-- Répartition géographique des annonces par région
-- =====================================================================

DROP VIEW IF EXISTS vw_repartition_geo;

CREATE VIEW vw_repartition_geo AS
SELECT
    region,
    COUNT(*)                                                                        AS nb_annonces,
    COUNT(DISTINCT source_id)                                                       AS nb_sources,
    COUNT(DISTINCT acheteur_id)                                                     AS nb_acheteurs,
    ROUND(SUM(CASE WHEN montant_estime IS NOT NULL THEN montant_estime ELSE 0 END), 2) AS montant_total,
    ROUND(AVG(montant_estime), 2)                                                   AS montant_moyen,
    MIN(date_publication)                                                           AS date_premiere,
    MAX(date_limite_reponse)                                                        AS deadline_derniere,
    NOW()                                                                           AS genere_le
FROM annonces
WHERE statut IN ('NEW', 'QUALIFIED')
GROUP BY region
ORDER BY nb_annonces DESC;

-- =====================================================================
-- VUE 5 : vw_alertes_prioritaires
-- Annonces urgentes non expirées, triées par deadline
-- Utilise qualification_scores (1:1) pour éviter recalcul en live
-- =====================================================================

DROP VIEW IF EXISTS vw_alertes_prioritaires;

CREATE VIEW vw_alertes_prioritaires AS
SELECT
    a.id_annonce,
    a.id_externe,
    a.titre,
    a.montant_estime,
    s.nom_source,
    ac.nom_acheteur,
    a.region,
    a.date_publication,
    a.date_limite_reponse,
    DATEDIFF(a.date_limite_reponse, NOW())      AS jours_restants,
    qs.score_pertinence,
    qs.niveau_alerte,
    NOW()                                       AS genere_le
FROM annonces a
JOIN sources s          ON a.source_id      = s.id_source
JOIN acheteurs ac       ON a.acheteur_id    = ac.id_acheteur
LEFT JOIN qualification_scores qs ON qs.annonce_id = a.id_annonce
WHERE a.date_limite_reponse > NOW()
  AND a.statut IN ('NEW', 'QUALIFIED')
  AND qs.niveau_alerte IN ('CRITIQUE', 'URGENT')
ORDER BY jours_restants ASC, qs.score_pertinence DESC;

-- =====================================================================
-- VUE 6 : vw_performance_sources
-- Productivité de chaque source de données
-- =====================================================================

DROP VIEW IF EXISTS vw_performance_sources;

CREATE VIEW vw_performance_sources AS
SELECT
    s.id_source,
    s.nom_source,
    s.type_source,
    COUNT(a.id_annonce)                                                                     AS nb_annonces_total,
    COUNT(DISTINCT a.acheteur_id)                                                           AS nb_acheteurs_distincts,
    COUNT(DISTINCT a.region)                                                                AS nb_regions,
    ROUND(AVG(a.montant_estime), 2)                                                         AS montant_moyen,
    ROUND(MAX(a.montant_estime), 2)                                                         AS montant_max,
    COUNT(CASE WHEN a.date_publication >= DATE_SUB(NOW(), INTERVAL 7  DAY) THEN 1 END)     AS annonces_7_derniers_jours,
    COUNT(CASE WHEN a.date_publication >= DATE_SUB(NOW(), INTERVAL 30 DAY) THEN 1 END)     AS annonces_30_derniers_jours,
    MIN(a.date_publication)                                                                 AS date_premiere_annonce,
    MAX(a.date_publication)                                                                 AS date_derniere_annonce,
    NOW()                                                                                   AS genere_le
FROM sources s
LEFT JOIN annonces a ON s.id_source = a.source_id
GROUP BY s.id_source, s.nom_source, s.type_source
ORDER BY nb_annonces_total DESC;

-- =====================================================================
-- VUE 7 : vw_acheteurs_principaux
-- Top acheteurs par volume d'annonces
-- =====================================================================

DROP VIEW IF EXISTS vw_acheteurs_principaux;

CREATE VIEW vw_acheteurs_principaux AS
SELECT
    ac.id_acheteur,
    ac.nom_acheteur,
    ac.type_acheteur,
    ac.region,
    COUNT(a.id_annonce)                                 AS nb_annonces,
    COUNT(DISTINCT a.source_id)                         AS nb_sources,
    ROUND(AVG(a.montant_estime), 2)                     AS montant_moyen,
    ROUND(SUM(a.montant_estime), 2)                     AS montant_total,
    MIN(a.date_publication)                             AS date_premiere,
    MAX(a.date_publication)                             AS date_derniere,
    NOW()                                               AS genere_le
FROM acheteurs ac
LEFT JOIN annonces a ON ac.id_acheteur = a.acheteur_id
    AND a.statut IN ('NEW', 'QUALIFIED')
GROUP BY ac.id_acheteur, ac.nom_acheteur, ac.type_acheteur, ac.region
ORDER BY nb_annonces DESC;

-- =====================================================================
-- VUE 8 : vw_mots_cles_populaires
-- Fréquence des mots-clés sur les annonces actives
-- =====================================================================

DROP VIEW IF EXISTS vw_mots_cles_populaires;

CREATE VIEW vw_mots_cles_populaires AS
SELECT
    mk.id_mot_cle,
    mk.mot_cle,
    mk.categorie,
    COUNT(DISTINCT amc.annonce_id)          AS nb_annonces,
    ROUND(AVG(amc.pertinence_score), 1)     AS score_moyen,
    COUNT(DISTINCT a.source_id)             AS nb_sources,
    ROUND(AVG(a.montant_estime), 2)         AS montant_moyen_annonces,
    NOW()                                   AS genere_le
FROM mots_cles mk
LEFT JOIN annonce_mot_cle amc ON mk.id_mot_cle = amc.mot_cle_id
LEFT JOIN annonces a ON amc.annonce_id = a.id_annonce
    AND a.statut IN ('NEW', 'QUALIFIED')
GROUP BY mk.id_mot_cle, mk.mot_cle, mk.categorie
ORDER BY nb_annonces DESC;

-- =====================================================================
-- VUE 9 : vw_qualite_donnees
-- Métriques de complétude et qualité des données
-- =====================================================================

DROP VIEW IF EXISTS vw_qualite_donnees;

CREATE VIEW vw_qualite_donnees AS
SELECT
    COUNT(*)                                                                            AS total_annonces,
    COUNT(CASE WHEN titre IS NOT NULL AND CHAR_LENGTH(titre) > 5 THEN 1 END)           AS titres_valides,
    COUNT(CASE WHEN description IS NOT NULL AND CHAR_LENGTH(description) > 10 THEN 1 END) AS descriptions_valides,
    COUNT(CASE WHEN montant_estime IS NOT NULL AND montant_estime > 0 THEN 1 END)      AS montants_valides,
    COUNT(CASE WHEN date_publication IS NOT NULL THEN 1 END)                           AS dates_publication_valides,
    COUNT(CASE WHEN date_limite_reponse IS NOT NULL THEN 1 END)                        AS deadlines_valides,
    COUNT(CASE WHEN region IS NOT NULL AND region != 'Inconnu' THEN 1 END)             AS regions_valides,
    ROUND(100.0 * COUNT(DISTINCT id_externe) / NULLIF(COUNT(*), 0), 2)                AS taux_unicite_pct,
    NOW()                                                                              AS genere_le
FROM annonces;

-- =====================================================================
-- TESTS : Vérification des vues
-- =====================================================================

-- Synthèse KPI
SELECT * FROM vw_kpi_resume;

-- Répartition par niveau alerte
SELECT * FROM vw_repartition_priorite;

-- Évolution temporelle (5 derniers jours)
SELECT * FROM vw_evolution_temporelle LIMIT 5;

-- Répartition géographique
SELECT * FROM vw_repartition_geo LIMIT 5;

-- Alertes prioritaires
SELECT id_annonce, titre, jours_restants, score_pertinence, niveau_alerte
FROM vw_alertes_prioritaires
LIMIT 5;

-- Performance sources
SELECT * FROM vw_performance_sources;

-- Qualité données
SELECT * FROM vw_qualite_donnees;

-- =====================================================================
-- FIN FICHIER : 09_views_dashboard.sql
-- =====================================================================
