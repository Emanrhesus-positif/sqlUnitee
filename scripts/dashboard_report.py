#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
UNITEE Phase 3 - Dashboard Reporting Script
Purpose: Generate HTML and console reports from the UNITEE database
Features:
  - KPI summary (total announcements, scores, regions)
  - Alert prioritization (CRITIQUE/URGENT/NORMAL/IGNORE counts)
  - Geographic distribution
  - Top keywords and buyers
  - Data quality metrics
  - Export to HTML and CSV
"""

import mysql.connector
import os
import json
from datetime import datetime
from pathlib import Path

# ===========================
# Configuration
# ===========================

DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': int(os.getenv('DB_PORT', 3306)),
    'user': os.getenv('DB_USER', 'unitee_user'),
    'password': os.getenv('DB_PASS', 'UniteeStrong1234'),
    'database': 'unitee'
}

REPORT_DIR = Path(__file__).parent.parent / 'reports'
REPORT_DIR.mkdir(exist_ok=True)

# ===========================
# Dashboard Data Queries
# ===========================

QUERIES = {
    'kpi_summary': """
    SELECT 
        COUNT(*) as total_announcements,
        COALESCE(SUM(CASE WHEN qs.pertinence_score > 75 THEN 1 ELSE 0 END), 0) as critique_count,
        COALESCE(SUM(CASE WHEN qs.pertinence_score BETWEEN 61 AND 75 THEN 1 ELSE 0 END), 0) as urgent_count,
        COALESCE(SUM(CASE WHEN qs.pertinence_score BETWEEN 51 AND 60 THEN 1 ELSE 0 END), 0) as normal_count,
        COALESCE(SUM(CASE WHEN qs.pertinence_score <= 50 THEN 1 ELSE 0 END), 0) as ignore_count,
        COUNT(DISTINCT a.region) as regions,
        COUNT(DISTINCT a.buyer_id) as buyers,
        COUNT(DISTINCT a.source_id) as sources,
        ROUND(AVG(a.estimated_amount), 2) as avg_amount,
        MAX(a.estimated_amount) as max_amount,
        MIN(a.estimated_amount) as min_amount
    FROM announcements a
    LEFT JOIN qualification_scores qs ON a.announcement_id = qs.announcement_id
    """,
    
    'geographic_distribution': """
    SELECT 
        a.region,
        COUNT(*) as count,
        ROUND(AVG(qs.pertinence_score), 1) as avg_score,
        SUM(CASE WHEN qs.pertinence_score > 75 THEN 1 ELSE 0 END) as high_priority
    FROM announcements a
    LEFT JOIN qualification_scores qs ON a.announcement_id = qs.announcement_id
    WHERE a.status IN ('NEW', 'QUALIFIED') AND a.region IS NOT NULL
    GROUP BY a.region
    ORDER BY count DESC
    """,
    
    'top_buyers': """
    SELECT 
        b.buyer_name,
        COUNT(a.announcement_id) as announcement_count,
        ROUND(AVG(qs.pertinence_score), 1) as avg_score
    FROM announcements a
    JOIN buyers b ON a.buyer_id = b.buyer_id
    LEFT JOIN qualification_scores qs ON a.announcement_id = qs.announcement_id
    WHERE a.status IN ('NEW', 'QUALIFIED')
    GROUP BY a.buyer_id, b.buyer_name
    ORDER BY announcement_count DESC
    LIMIT 10
    """,
    
    'data_quality': """
    SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN a.title IS NULL OR a.title = '' THEN 1 ELSE 0 END) as null_titles,
        SUM(CASE WHEN a.external_id IS NULL OR a.external_id = '' THEN 1 ELSE 0 END) as null_external_ids,
        SUM(CASE WHEN a.estimated_amount IS NULL THEN 1 ELSE 0 END) as null_amounts,
        SUM(CASE WHEN a.response_deadline < a.publication_date THEN 1 ELSE 0 END) as invalid_dates,
        ROUND(100.0 * (COUNT(*) - SUM(CASE WHEN a.title IS NULL OR a.title = '' THEN 1 ELSE 0 END)) / COUNT(*), 1) as completeness_pct
    FROM announcements a
    """,
    
    'alert_distribution': """
    SELECT 
        qs.alert_level,
        COUNT(*) as count,
        ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM qualification_scores), 1) as percentage
    FROM qualification_scores qs
    GROUP BY qs.alert_level
    ORDER BY 
        CASE qs.alert_level 
            WHEN 'CRITIQUE' THEN 1 
            WHEN 'URGENT' THEN 2 
            WHEN 'NORMAL' THEN 3 
            ELSE 4 
        END
    """
}

# ===========================
# Database Connection & Query
# ===========================

def connect_database():
    """Establish database connection"""
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        print("[OK] Connected to {} database".format(DB_CONFIG['database']))
        return conn
    except mysql.connector.Error as err:
        print("[ERROR] Database connection failed: {}".format(err))
        return None

def execute_query(conn, query):
    """Execute a query and return results"""
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute(query)
        results = cursor.fetchall()
        cursor.close()
        return results
    except mysql.connector.Error as err:
        print("[ERROR] Query failed: {}".format(err))
        return []

# ===========================
# Report Generation
# ===========================

def generate_console_report(data):
    """Generate console output report"""
    print("\n" + "="*70)
    print("UNITEE PHASE 3 - DASHBOARD REPORT")
    print("Generated: {}".format(datetime.now().strftime('%Y-%m-%d %H:%M:%S')))
    print("="*70)
    
    # KPI Summary
    if data['kpi_summary']:
        kpi = data['kpi_summary'][0]
        print("\nKPI SUMMARY")
        print("-" * 70)
        print("Total Announcements: {}".format(kpi['total_announcements']))
        print("Alert Levels:")
        print("  - CRITIQUE:  {} ({:5.1f}%)".format(
            kpi['critique_count'],
            (100.0 * float(kpi['critique_count']) / max(kpi['total_announcements'], 1))
        ))
        print("  - URGENT:    {} ({:5.1f}%)".format(
            kpi['urgent_count'],
            (100.0 * float(kpi['urgent_count']) / max(kpi['total_announcements'], 1))
        ))
        print("  - NORMAL:    {} ({:5.1f}%)".format(
            kpi['normal_count'],
            (100.0 * float(kpi['normal_count']) / max(kpi['total_announcements'], 1))
        ))
        print("  - IGNORE:    {} ({:5.1f}%)".format(
            kpi['ignore_count'],
            (100.0 * float(kpi['ignore_count']) / max(kpi['total_announcements'], 1))
        ))
        print("Coverage: {} regions, {} buyers, {} sources".format(
            kpi['regions'], kpi['buyers'], kpi['sources']
        ))
        print("Amount: EUR {:.0f} avg, {:.0f} min, {:.0f} max".format(
            kpi['avg_amount'] or 0, kpi['min_amount'] or 0, kpi['max_amount'] or 0
        ))
    
    # Geographic Distribution
    if data['geographic_distribution']:
        print("\nGEOGRAPHIC DISTRIBUTION (Top 5)")
        print("-" * 70)
        for i, row in enumerate(data['geographic_distribution'][:5], 1):
            print("{}: {} - {} announcements (avg score: {}/100, high-priority: {})".format(
                i, row['region'], row['count'], row['avg_score'] or 0, row['high_priority'] or 0
            ))
    
    # Top Buyers
    if data['top_buyers']:
        print("\nTOP BUYERS (Top 5)")
        print("-" * 70)
        for i, row in enumerate(data['top_buyers'][:5], 1):
            print("{}: {} - {} announcements (avg score: {}/100)".format(
                i, row['buyer_name'], row['announcement_count'], row['avg_score'] or 0
            ))
    
    # Data Quality
    if data['data_quality']:
        quality = data['data_quality'][0]
        print("\nDATA QUALITY")
        print("-" * 70)
        print("Total Records: {}".format(quality['total']))
        print("Completeness: {:.1f}%".format(quality['completeness_pct'] or 0))
        print("Data Issues:")
        print("  - Null Titles: {}".format(quality['null_titles'] or 0))
        print("  - Null External IDs: {}".format(quality['null_external_ids'] or 0))
        print("  - Null Amounts: {}".format(quality['null_amounts'] or 0))
        print("  - Invalid Dates: {}".format(quality['invalid_dates'] or 0))
    
    # Alert Distribution
    if data['alert_distribution']:
        print("\nALERT DISTRIBUTION")
        print("-" * 70)
        for row in data['alert_distribution']:
            print("{:10s}: {:4d} ({:5.1f}%)".format(
                row['alert_level'], row['count'], row['percentage'] or 0
            ))
    
    print("\n" + "="*70)

def generate_html_report(data):
    """Generate HTML report"""
    html_template = """<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>UNITEE Phase 3 - Dashboard Report</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }}
        .container {{ max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 5px; }}
        h1 {{ color: #333; border-bottom: 3px solid #007bff; padding-bottom: 10px; }}
        h2 {{ color: #555; margin-top: 30px; }}
        .kpi-grid {{ display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px; margin: 20px 0; }}
        .kpi-card {{ background: #f8f9fa; padding: 15px; border-left: 4px solid #007bff; border-radius: 3px; }}
        .kpi-value {{ font-size: 28px; font-weight: bold; color: #007bff; }}
        .kpi-label {{ font-size: 14px; color: #666; }}
        .alert-critique {{ border-left-color: #dc3545; }}
        .alert-urgent {{ border-left-color: #fd7e14; }}
        .alert-normal {{ border-left-color: #28a745; }}
        .alert-ignore {{ border-left-color: #6c757d; }}
        .kpi-value.critique {{ color: #dc3545; }}
        .kpi-value.urgent {{ color: #fd7e14; }}
        .kpi-value.normal {{ color: #28a745; }}
        .kpi-value.ignore {{ color: #6c757d; }}
        table {{ width: 100%; border-collapse: collapse; margin: 20px 0; }}
        th, td {{ padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }}
        th {{ background: #f8f9fa; font-weight: bold; }}
        tr:hover {{ background: #f5f5f5; }}
        .metric {{ display: inline-block; margin: 10px 20px 10px 0; }}
        .metric-label {{ color: #666; font-size: 14px; }}
        .metric-value {{ font-size: 20px; font-weight: bold; color: #333; }}
        .footer {{ margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 12px; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>UNITEE Phase 3 - Dashboard Report</h1>
        <p>Generated: {timestamp}</p>
        
        {kpi_section}
        {geographic_section}
        {buyers_section}
        {quality_section}
        
        <div class="footer">
            <p>UNITEE - Automated Public Market Surveillance System</p>
            <p>Phase 3: Scoring, Alerts, and Dashboard</p>
        </div>
    </div>
</body>
</html>"""

    # KPI Section
    if data['kpi_summary']:
        kpi = data['kpi_summary'][0]
        kpi_html = """<h2>Key Performance Indicators</h2>
        <div class="kpi-grid">
            <div class="kpi-card alert-critique">
                <div class="kpi-value critique">{}</div>
                <div class="kpi-label">CRITIQUE</div>
            </div>
            <div class="kpi-card alert-urgent">
                <div class="kpi-value urgent">{}</div>
                <div class="kpi-label">URGENT</div>
            </div>
            <div class="kpi-card alert-normal">
                <div class="kpi-value normal">{}</div>
                <div class="kpi-label">NORMAL</div>
            </div>
            <div class="kpi-card alert-ignore">
                <div class="kpi-value ignore">{}</div>
                <div class="kpi-label">IGNORE</div>
            </div>
        </div>
        <div>
            <p class="metric"><span class="metric-label">Total Announcements:</span><span class="metric-value">{}</span></p>
            <p class="metric"><span class="metric-label">Regions:</span><span class="metric-value">{}</span></p>
            <p class="metric"><span class="metric-label">Buyers:</span><span class="metric-value">{}</span></p>
            <p class="metric"><span class="metric-label">Avg Amount:</span><span class="metric-value">EUR {:.0f}</span></p>
        </div>""".format(
            kpi['critique_count'] or 0,
            kpi['urgent_count'] or 0,
            kpi['normal_count'] or 0,
            kpi['ignore_count'] or 0,
            kpi['total_announcements'],
            kpi['regions'],
            kpi['buyers'],
            kpi['avg_amount'] or 0
        )
    else:
        kpi_html = ""
    
    # Geographic Section
    if data['geographic_distribution']:
        geo_rows = "".join([
            "<tr><td>{}</td><td>{}</td><td>{:.1f}</td><td>{}</td></tr>".format(
                row['region'], row['count'], row['avg_score'] or 0, row['high_priority'] or 0
            )
            for row in data['geographic_distribution'][:10]
        ])
        geographic_html = """<h2>Geographic Distribution</h2>
        <table>
            <thead><tr><th>Region</th><th>Announcements</th><th>Avg Score</th><th>High Priority</th></tr></thead>
            <tbody>{}</tbody>
        </table>""".format(geo_rows)
    else:
        geographic_html = ""
    
    # Buyers Section
    if data['top_buyers']:
        buyer_rows = "".join([
            "<tr><td>{}</td><td>{}</td><td>{:.1f}</td></tr>".format(
                row['buyer_name'], row['announcement_count'], row['avg_score'] or 0
            )
            for row in data['top_buyers'][:10]
        ])
        buyers_html = """<h2>Top Buyers</h2>
        <table>
            <thead><tr><th>Buyer</th><th>Announcements</th><th>Avg Score</th></tr></thead>
            <tbody>{}</tbody>
        </table>""".format(buyer_rows)
    else:
        buyers_html = ""
    
    # Quality Section
    if data['data_quality']:
        quality = data['data_quality'][0]
        quality_html = """<h2>Data Quality</h2>
        <div>
            <p class="metric"><span class="metric-label">Completeness:</span><span class="metric-value">{:.1f}%</span></p>
            <p class="metric"><span class="metric-label">Total Records:</span><span class="metric-value">{}</span></p>
            <p class="metric"><span class="metric-label">Issues:</span><span class="metric-value">{} (Null Title) + {} (Null ID) + {} (Invalid Date)</span></p>
        </div>""".format(
            quality['completeness_pct'] or 0,
            quality['total'],
            quality['null_titles'] or 0,
            quality['null_external_ids'] or 0,
            quality['invalid_dates'] or 0
        )
    else:
        quality_html = ""
    
    html_content = html_template.format(
        timestamp=datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        kpi_section=kpi_html,
        geographic_section=geographic_html,
        buyers_section=buyers_html,
        quality_section=quality_html
    )
    
    return html_content

# ===========================
# Main Execution
# ===========================

def main():
    print("="*70)
    print("UNITEE Phase 3 - Dashboard Reporting")
    print("="*70 + "\n")
    
    # Connect to database
    conn = connect_database()
    if not conn:
        return
    
    # Execute queries
    print("\nFetching dashboard data...")
    data = {}
    for query_name, query in QUERIES.items():
        data[query_name] = execute_query(conn, query)
        print("  [OK] {}".format(query_name))
    
    conn.close()
    
    # Generate reports
    print("\nGenerating reports...")
    
    # Console report
    generate_console_report(data)
    
    # HTML report
    html_content = generate_html_report(data)
    html_path = REPORT_DIR / 'dashboard_{}.html'.format(
        datetime.now().strftime('%Y%m%d_%H%M%S')
    )
    with open(html_path, 'w', encoding='utf-8') as f:
        f.write(html_content)
    print("  [OK] HTML report: {}".format(html_path))
    
    # JSON report
    json_data = {k: v for k, v in data.items()}
    json_path = REPORT_DIR / 'dashboard_{}.json'.format(
        datetime.now().strftime('%Y%m%d_%H%M%S')
    )
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(json_data, f, indent=2, default=str)
    print("  [OK] JSON report: {}".format(json_path))
    
    print("\n[SUCCESS] Dashboard reports generated successfully!")

if __name__ == '__main__':
    main()
