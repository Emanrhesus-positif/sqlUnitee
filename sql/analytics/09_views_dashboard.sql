-- =====================================================================
-- UNITEE Phase 3 - Dashboard Views
-- File: 09_views_dashboard.sql
-- Purpose: KPI views for monitoring and reporting
-- =====================================================================

USE unitee;

-- =====================================================================
-- VIEW 1: vw_kpi_resume
-- Global KPI summary
-- =====================================================================

DROP VIEW IF EXISTS vw_kpi_resume;

CREATE VIEW vw_kpi_resume AS
SELECT
    COUNT(*) as total_announcements,
    COUNT(DISTINCT source_id) as active_sources,
    COUNT(DISTINCT buyer_id) as active_buyers,
    COUNT(DISTINCT region) as regions_covered,
    SUM(CASE WHEN estimated_amount IS NOT NULL THEN 1 ELSE 0 END) as announcements_with_amount,
    ROUND(AVG(estimated_amount), 2) as avg_amount,
    ROUND(MIN(estimated_amount), 2) as min_amount,
    ROUND(MAX(estimated_amount), 2) as max_amount,
    MIN(publication_date) as earliest_publication,
    MAX(publication_date) as latest_publication,
    MIN(response_deadline) as earliest_deadline,
    MAX(response_deadline) as latest_deadline,
    NOW() as generated_at
FROM announcements
WHERE status IN ('NEW', 'QUALIFIED');

-- =====================================================================
-- VIEW 2: vw_evolution_temporelle
-- Daily announcement volume and scoring trends
-- =====================================================================

DROP VIEW IF EXISTS vw_evolution_temporelle;

CREATE VIEW vw_evolution_temporelle AS
SELECT
    DATE(publication_date) as date_publication,
    COUNT(*) as nb_announcements,
    COUNT(DISTINCT source_id) as nb_sources,
    ROUND(AVG(estimated_amount), 2) as avg_amount,
    COUNT(DISTINCT region) as nb_regions,
    NOW() as generated_at
FROM announcements
GROUP BY DATE(publication_date)
ORDER BY date_publication DESC;

-- =====================================================================
-- VIEW 3: vw_repartition_geo
-- Geographic distribution of announcements
-- =====================================================================

DROP VIEW IF EXISTS vw_repartition_geo;

CREATE VIEW vw_repartition_geo AS
SELECT
    region,
    COUNT(*) as nb_announcements,
    COUNT(DISTINCT source_id) as nb_sources,
    COUNT(DISTINCT buyer_id) as nb_buyers,
    ROUND(SUM(CASE WHEN estimated_amount IS NOT NULL THEN estimated_amount ELSE 0 END), 2) as montant_total,
    ROUND(AVG(estimated_amount), 2) as montant_moyen,
    MIN(publication_date) as date_premiere,
    MAX(response_deadline) as dernier_deadline,
    NOW() as generated_at
FROM announcements
WHERE status IN ('NEW', 'QUALIFIED')
GROUP BY region
ORDER BY nb_announcements DESC;

-- =====================================================================
-- VIEW 4: vw_alertes_prioritaires
-- High-priority announcements needing attention
-- =====================================================================

DROP VIEW IF EXISTS vw_alertes_prioritaires;

CREATE VIEW vw_alertes_prioritaires AS
SELECT
    a.announcement_id,
    a.external_id,
    a.title,
    a.estimated_amount,
    s.source_name,
    a.region,
    a.publication_date,
    a.response_deadline,
    DATEDIFF(a.response_deadline, NOW()) as jours_restants,
    DATEDIFF(a.response_deadline, NOW()) as days_left,
    CASE
        WHEN CalculerScorePertinence(
            a.title, a.description, a.estimated_amount, 
            a.region, a.response_deadline) > 75 
            AND DATEDIFF(a.response_deadline, NOW()) < 7 THEN 'CRITIQUE'
        WHEN CalculerScorePertinence(
            a.title, a.description, a.estimated_amount,
            a.region, a.response_deadline) > 75 
            AND DATEDIFF(a.response_deadline, NOW()) < 14 THEN 'URGENT'
        WHEN CalculerScorePertinence(
            a.title, a.description, a.estimated_amount,
            a.region, a.response_deadline) > 60 
            AND DATEDIFF(a.response_deadline, NOW()) < 14 THEN 'URGENT'
        WHEN CalculerScorePertinence(
            a.title, a.description, a.estimated_amount,
            a.region, a.response_deadline) > 50 THEN 'NORMAL'
        ELSE 'IGNORE'
    END as niveau_alerte,
    NOW() as generated_at
FROM announcements a
JOIN sources s ON a.source_id = s.source_id
WHERE a.response_deadline > NOW() 
  AND a.status IN ('NEW', 'QUALIFIED')
ORDER BY jours_restants ASC, estimated_amount DESC;

-- =====================================================================
-- VIEW 5: vw_performance_sources
-- Source performance metrics
-- =====================================================================

DROP VIEW IF EXISTS vw_performance_sources;

CREATE VIEW vw_performance_sources AS
SELECT
    s.source_name,
    COUNT(a.announcement_id) as nb_announcements,
    COUNT(DISTINCT a.buyer_id) as nb_buyers,
    COUNT(DISTINCT a.region) as nb_regions,
    ROUND(AVG(a.estimated_amount), 2) as montant_moyen,
    ROUND(MAX(a.estimated_amount), 2) as montant_max,
    COUNT(CASE WHEN a.publication_date >= DATE_SUB(NOW(), INTERVAL 7 DAY) THEN 1 END) as derniers_7j,
    COUNT(CASE WHEN a.publication_date >= DATE_SUB(NOW(), INTERVAL 30 DAY) THEN 1 END) as derniers_30j,
    MIN(a.publication_date) as date_premiere_ann,
    MAX(a.publication_date) as date_derniere_ann,
    NOW() as generated_at
FROM sources s
LEFT JOIN announcements a ON s.source_id = a.source_id
GROUP BY s.source_id, s.source_name
ORDER BY nb_announcements DESC;

-- =====================================================================
-- VIEW 6: vw_acheteurs_principaux
-- Top buyers by announcement volume
-- =====================================================================

DROP VIEW IF EXISTS vw_acheteurs_principaux;

CREATE VIEW vw_acheteurs_principaux AS
SELECT
    b.buyer_id,
    b.buyer_name,
    b.buyer_type,
    b.region,
    COUNT(a.announcement_id) as nb_announcements,
    COUNT(DISTINCT a.source_id) as nb_sources,
    ROUND(AVG(a.estimated_amount), 2) as montant_moyen,
    ROUND(SUM(a.estimated_amount), 2) as montant_total,
    MIN(a.publication_date) as date_premiere,
    MAX(a.publication_date) as date_derniere,
    NOW() as generated_at
FROM buyers b
LEFT JOIN announcements a ON b.buyer_id = a.buyer_id AND a.status IN ('NEW', 'QUALIFIED')
GROUP BY b.buyer_id, b.buyer_name, b.buyer_type, b.region
ORDER BY nb_announcements DESC;

-- =====================================================================
-- VIEW 7: vw_mots_cles_populaires
-- Keyword frequency analysis
-- =====================================================================

DROP VIEW IF EXISTS vw_mots_cles_populaires;

CREATE VIEW vw_mots_cles_populaires AS
SELECT
    k.keyword_text,
    k.category,
    COUNT(DISTINCT a.announcement_id) as nb_annonces,
    COUNT(DISTINCT s.source_id) as nb_sources,
    ROUND(AVG(a.estimated_amount), 2) as montant_moyen,
    NOW() as generated_at
FROM keywords k
LEFT JOIN announcements a ON 
    LOWER(CONCAT(a.title, ' ', COALESCE(a.description, ''))) LIKE CONCAT('%', LOWER(k.keyword_text), '%')
    AND a.status IN ('NEW', 'QUALIFIED')
LEFT JOIN sources s ON a.source_id = s.source_id
GROUP BY k.keyword_id, k.keyword_text, k.category
ORDER BY nb_annonces DESC;

-- =====================================================================
-- VIEW 8: vw_quality_metrics
-- Data quality and completeness metrics
-- =====================================================================

DROP VIEW IF EXISTS vw_quality_metrics;

CREATE VIEW vw_quality_metrics AS
SELECT
    COUNT(*) as total_announcements,
    COUNT(CASE WHEN title IS NOT NULL AND LENGTH(title) > 5 THEN 1 END) as valid_titles,
    COUNT(CASE WHEN description IS NOT NULL AND LENGTH(description) > 10 THEN 1 END) as valid_descriptions,
    COUNT(CASE WHEN estimated_amount IS NOT NULL AND estimated_amount > 0 THEN 1 END) as valid_amounts,
    COUNT(CASE WHEN publication_date IS NOT NULL THEN 1 END) as valid_pub_dates,
    COUNT(CASE WHEN response_deadline IS NOT NULL THEN 1 END) as valid_deadlines,
    COUNT(CASE WHEN region IS NOT NULL AND region != 'Unknown' THEN 1 END) as valid_regions,
    ROUND(100 * COUNT(DISTINCT external_id) / COUNT(*), 2) as unique_rate_percent,
    NOW() as generated_at
FROM announcements;

-- =====================================================================
-- TEST: Query the views
-- =====================================================================

-- Test KPI Resume
SELECT * FROM vw_kpi_resume;

-- Test Evolution Temporelle
SELECT * FROM vw_evolution_temporelle LIMIT 5;

-- Test Geographic Distribution
SELECT * FROM vw_repartition_geo LIMIT 5;

-- Test Alertes Prioritaires
SELECT announcement_id, title, nb_announcements DESC
FROM vw_alertes_prioritaires
WHERE niveau_alerte IN ('CRITIQUE', 'URGENT')
LIMIT 5;

-- Test Source Performance
SELECT * FROM vw_performance_sources LIMIT 5;

-- Test Quality Metrics
SELECT * FROM vw_quality_metrics;

-- =====================================================================
-- END OF FILE: 09_views_dashboard.sql
-- =====================================================================
