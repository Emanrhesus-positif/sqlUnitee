#!/usr/bin/env python3
"""
UNITEE Phase 2 - Data Transformation, Validation & Export
Handles Tabs 3-5 of the Jupyter Notebook
"""

import os
import sys
import json
import yaml
import pandas as pd
import numpy as np
import re
from datetime import datetime, timedelta
from typing import Dict, List, Tuple
import mysql.connector
from mysql.connector import Error as MySQLError
import logging
from pathlib import Path
from io import StringIO

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Get database configuration from environment
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': int(os.getenv('DB_PORT', 3306)),
    'user': os.getenv('DB_USER', 'unitee_user'),
    'password': os.getenv('DB_PASS', 'UniteeStrong1234'),
    'database': os.getenv('DB_NAME', 'unitee'),
    'charset': os.getenv('DB_CHARSET', 'utf8mb4'),
}

# Setup directories
PROJECT_ROOT = Path(__file__).parent.parent
DATA_DIR = PROJECT_ROOT / 'data'
DATA_DIR.mkdir(exist_ok=True)

def load_config() -> Dict:
    """Load configuration from config.yaml"""
    config_path = PROJECT_ROOT / 'config' / 'config.yaml'
    
    if config_path.exists():
        with open(config_path, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f)
    else:
        logger.warning(f"Config not found at {config_path}")
        return {'keywords': {'primary': [], 'secondary': []}}

def get_buyer_mapping() -> Dict[str, int]:
    """Get buyer_id mapping from database"""
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        cursor.execute("SELECT buyer_id, buyer_name FROM buyers LIMIT 100")
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        return {row[1]: row[0] for row in rows} if rows else {}
    except Exception as e:
        logger.error(f"Error loading buyers: {e}")
        return {}

def get_source_mapping() -> Dict[str, int]:
    """Get source_id mapping from database"""
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        cursor.execute("SELECT source_id, source_name FROM sources")
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        return {row[1]: row[0] for row in rows} if rows else {}
    except Exception as e:
        logger.error(f"Error loading sources: {e}")
        return {}

def extract_region_from_location(location: str) -> str:
    """Extract region from location string (simplified)"""
    if pd.isna(location):
        return 'Unknown'
    
    location_str = str(location).lower()
    
    # Map of regions
    regions = {
        'île-de-france': ['paris', 'île-de-france', 'idf'],
        'auvergne-rhône-alpes': ['lyon', 'auvergne', 'rhône'],
        'provence-alpes-côte d\'azur': ['marseille', 'nice', 'provence', 'paca'],
        'grand est': ['strasbourg', 'reims', 'grand est', 'metz'],
        'hauts-de-france': ['lille', 'amiens', 'hauts-de-france'],
        'normandie': ['rouen', 'caen', 'normandie'],
        'nouvelle-aquitaine': ['bordeaux', 'aquitaine', 'limoges'],
        'occitanie': ['toulouse', 'montpellier', 'occitanie'],
    }
    
    for region, keywords in regions.items():
        for kw in keywords:
            if kw in location_str:
                return region
    
    return 'Unknown'

def normalize_amount(amount) -> float:
    """Normalize amount to float, handle string amounts"""
    if pd.isna(amount):
        return None
    
    try:
        return float(amount)
    except:
        # Try to extract number from string
        match = re.search(r'\d+', str(amount).replace(',', '.'))
        return float(match.group()) if match else None

def extract_keywords_from_text(text: str, keywords_list: List[str]) -> List[str]:
    """Extract matching keywords from text"""
    if pd.isna(text):
        return []
    
    text_lower = str(text).lower()
    found = []
    
    for keyword in keywords_list:
        if keyword.lower() in text_lower:
            found.append(keyword)
    
    return found

def transform_data(df_raw: pd.DataFrame, config: Dict) -> pd.DataFrame:
    """
    TAB 3: Transform and normalize raw data
    """
    print("\n" + "="*70)
    print("TAB 3: DATA TRANSFORMATION")
    print("="*70)
    
    df = df_raw.copy()
    
    print(f"\nInput: {len(df)} rows")
    
    # 1. Map source names to source_id
    print("\n[1/6] Mapping sources...")
    source_map = get_source_mapping()
    print(f"  Available sources: {list(source_map.keys())}")
    
    df['source_id'] = df['source_name'].map(source_map)
    
    # For synthetic data, use source_id=3 (synthetic)
    if 'source_name' in df.columns:
        df.loc[df['source_name'] == 'synthetic', 'source_id'] = 3
        df.loc[df['source_name'] == 'data.gouv.fr', 'source_id'] = 1
        df.loc[df['source_name'] == 'BOAMP', 'source_id'] = 2
    
    if df['source_id'].isnull().any():
        print(f"  [!] {df['source_id'].isnull().sum()} unmatched sources, using default")
        df['source_id'].fillna(3, inplace=True)  # Default to synthetic
    
    print(f"  [OK] Sources mapped")
    
    # 2. Default buyer_id (will match against description later if needed)
    print("\n[2/6] Assigning default buyer...")
    buyer_map = get_buyer_mapping()
    default_buyer = list(buyer_map.values())[0] if buyer_map else 1
    df['buyer_id'] = default_buyer
    print(f"  Default buyer_id: {default_buyer}")
    
    # 3. Normalize estimated_amount
    print("\n[3/6] Normalizing amounts...")
    df['estimated_amount'] = df['estimated_amount'].apply(normalize_amount)
    print(f"  Min: {df['estimated_amount'].min()}, Max: {df['estimated_amount'].max()}")
    
    # 4. Normalize dates
    print("\n[4/6] Normalizing dates...")
    df['publication_date'] = pd.to_datetime(df['publication_date'], errors='coerce')
    df['response_deadline'] = pd.to_datetime(df['response_deadline'], errors='coerce')
    print(f"  Publication dates: {df['publication_date'].min()} to {df['publication_date'].max()}")
    print(f"  Response deadlines: {df['response_deadline'].min()} to {df['response_deadline'].max()}")
    
    # 5. Extract/normalize region
    print("\n[5/6] Extracting regions...")
    if 'region' not in df.columns:
        df['region'] = df['location'].apply(extract_region_from_location)
    df['region'] = df['region'].fillna('Unknown')
    print(f"  Unique regions: {df['region'].nunique()}")
    print(f"  Regions: {df['region'].unique().tolist()}")
    
    # 6. Set status to 'NEW' for all new announcements (valid per schema)
    print("\n[6/6] Setting announcement status...")
    df['status'] = 'NEW'
    
    # Map columns to database schema
    print("\n[*] Mapping to database schema...")
    df_transformed = pd.DataFrame({
        'source_id': df['source_id'],
        'buyer_id': df['buyer_id'],
        'external_id': df['external_id'],
        'title': df['title'],
        'description': df['description'],
        'estimated_amount': df['estimated_amount'],
        'currency': 'EUR',  # Default currency
        'publication_date': df['publication_date'],
        'response_deadline': df['response_deadline'],
        'location': df['location'],
        'region': df['region'],
        'source_link': '',  # Will be empty for API data
        'status': df['status'],
    })
    
    # Save transformed data
    transformed_file = DATA_DIR / 'annonces_cleaned.csv'
    df_transformed.to_csv(transformed_file, index=False, encoding='utf-8')
    print(f"\n[OK] Transformed data saved: {transformed_file}")
    
    return df_transformed

def validate_data(df_transformed: pd.DataFrame) -> Tuple[pd.DataFrame, Dict]:
    """
    TAB 4: Validate data quality and detect doublons
    """
    print("\n" + "="*70)
    print("TAB 4: DATA VALIDATION")
    print("="*70)
    
    df = df_transformed.copy()
    validation_report = {
        'total_records': len(df),
        'issues': {},
        'doublons': 0,
        'valid_records': 0,
    }
    
    print(f"\nInput: {len(df)} rows\n")
    
    # Check 1: Null values
    print("[1/5] Checking for null values...")
    null_cols = df.isnull().sum()
    null_issues = null_cols[null_cols > 0]
    if len(null_issues) > 0:
        validation_report['issues']['null_values'] = null_issues.to_dict()
        print(f"  [!] Found nulls in: {null_issues.to_dict()}")
    else:
        print(f"  [OK] No null values found")
    
    # Check 2: Date logic (publication_date <= response_deadline)
    print("\n[2/5] Checking date logic...")
    bad_dates = df[df['publication_date'] > df['response_deadline']]
    if len(bad_dates) > 0:
        validation_report['issues']['bad_dates'] = len(bad_dates)
        print(f"  [!] {len(bad_dates)} records have publication_date > response_deadline")
        # Fix: swap them
        df.loc[bad_dates.index, ['publication_date', 'response_deadline']] = \
            df.loc[bad_dates.index, ['response_deadline', 'publication_date']].values
        print(f"  [*] Fixed by swapping dates")
    else:
        print(f"  [OK] All dates are valid")
    
    # Check 3: Amount validation
    print("\n[3/5] Checking amounts...")
    bad_amounts = df[(df['estimated_amount'] <= 0) | (df['estimated_amount'].isna())]
    if len(bad_amounts) > 0:
        validation_report['issues']['bad_amounts'] = len(bad_amounts)
        print(f"  [!] {len(bad_amounts)} records have invalid amounts")
        # Set to NULL for invalid amounts
        df.loc[bad_amounts.index, 'estimated_amount'] = None
    else:
        print(f"  [OK] All amounts valid")
    
    # Check 4: Title validation (length > 5)
    print("\n[4/5] Checking titles...")
    bad_titles = df[df['title'].str.len() < 5]
    if len(bad_titles) > 0:
        validation_report['issues']['bad_titles'] = len(bad_titles)
        print(f"  [!] {len(bad_titles)} records have titles < 5 chars")
    else:
        print(f"  [OK] All titles valid")
    
    # Check 5: Doublon detection (source_id, external_id)
    print("\n[5/5] Checking for doublons...")
    duplicates = df.duplicated(subset=['source_id', 'external_id'], keep=False)
    if duplicates.sum() > 0:
        validation_report['doublons'] = duplicates.sum()
        print(f"  [!] {duplicates.sum()} potential doublons found")
        # Keep first occurrence, remove duplicates
        df = df.drop_duplicates(subset=['source_id', 'external_id'], keep='first')
        print(f"  [*] Removed doublons, keeping {len(df)} unique records")
    else:
        print(f"  [OK] No doublons detected")
    
    validation_report['valid_records'] = len(df)
    
    # Save validation report
    report_file = DATA_DIR / 'validation_report.json'
    with open(report_file, 'w', encoding='utf-8') as f:
        json.dump(validation_report, f, indent=2, default=str)
    print(f"\n[OK] Validation report saved: {report_file}")
    
    return df, validation_report

def export_to_sql(df_validated: pd.DataFrame) -> str:
    """
    TAB 5: Generate SQL INSERT statements
    """
    print("\n" + "="*70)
    print("TAB 5: SQL EXPORT")
    print("="*70)
    
    print(f"\nInput: {len(df_validated)} rows\n")
    
    # Generate INSERT statements
    insert_statements = []
    
    for idx, row in df_validated.iterrows():
        # Escape single quotes in strings
        title = str(row['title']).replace("'", "''")
        description = str(row['description']).replace("'", "''")
        location = str(row['location']).replace("'", "''")
        region = str(row['region']).replace("'", "''")
        source_link = str(row['source_link']).replace("'", "''") if pd.notna(row['source_link']) else ''
        external_id = str(row['external_id']).replace("'", "''")
        
        # Format dates as MySQL DATETIME
        pub_date = row['publication_date'].strftime('%Y-%m-%d %H:%M:%S') if pd.notna(row['publication_date']) else 'NULL'
        resp_date = row['response_deadline'].strftime('%Y-%m-%d %H:%M:%S') if pd.notna(row['response_deadline']) else 'NULL'
        
        # Amount (NULL or float)
        amount = row['estimated_amount'] if pd.notna(row['estimated_amount']) else 'NULL'
        
        sql = f"""INSERT INTO announcements (source_id, buyer_id, external_id, title, description, estimated_amount, currency, publication_date, response_deadline, location, region, source_link, status, imported_at) 
VALUES ({int(row['source_id'])}, {int(row['buyer_id'])}, '{external_id}', '{title}', '{description}', {amount}, '{row['currency']}', '{pub_date}', '{resp_date}', '{location}', '{region}', '{source_link}', '{row['status']}', NOW());"""
        
        insert_statements.append(sql)
    
    # Save SQL file
    sql_file = DATA_DIR / 'annonces_insert.sql'
    with open(sql_file, 'w', encoding='utf-8') as f:
        f.write("-- UNITEE Phase 2 - Announcement Inserts\n")
        f.write(f"-- Generated: {datetime.now().isoformat()}\n")
        f.write(f"-- Records: {len(insert_statements)}\n\n")
        f.write("\n".join(insert_statements))
    
    print(f"[OK] SQL statements generated: {len(insert_statements)}")
    print(f"[OK] Saved to: {sql_file}")
    
    # Also save as CSV for bulk import (if needed)
    csv_file = DATA_DIR / 'annonces_import.csv'
    df_validated.to_csv(csv_file, index=False, encoding='utf-8')
    print(f"[OK] CSV for bulk import saved: {csv_file}")
    
    return sql_file

def load_into_database(sql_file: Path) -> Tuple[bool, str]:
    """Load SQL statements into database"""
    print("\n" + "="*70)
    print("LOADING INTO DATABASE")
    print("="*70)
    
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        # Read SQL file
        with open(sql_file, 'r', encoding='utf-8') as f:
            sql_content = f.read()
        
        # Split by semicolon and execute
        statements = [s.strip() for s in sql_content.split(';') if s.strip() and not s.strip().startswith('--')]
        
        print(f"\nExecuting {len(statements)} INSERT statements...")
        
        for i, stmt in enumerate(statements):
            try:
                cursor.execute(stmt)
            except MySQLError as e:
                if 'UNIQUE constraint failed' in str(e) or 'Duplicate entry' in str(e):
                    print(f"  [*] Statement {i+1}: Doublon detected, skipped")
                else:
                    print(f"  [!] Statement {i+1}: {str(e)[:50]}")
                    raise
        
        conn.commit()
        
        # Verify count
        cursor.execute("SELECT COUNT(*) FROM announcements")
        count = cursor.fetchone()[0]
        
        cursor.close()
        conn.close()
        
        print(f"\n[OK] All statements executed successfully")
        print(f"[OK] Total announcements in database: {count}")
        
        return True, f"Loaded {len(statements)} announcements"
        
    except Exception as e:
        print(f"\n[ERROR] Database load failed: {str(e)}")
        return False, str(e)

def main():
    """Main execution function"""
    
    print("\n" + "="*70)
    print("UNITEE Phase 2 - Transformation, Validation & Export")
    print("="*70)
    
    # Load raw data
    print("\n[*] Loading raw data...")
    raw_file = DATA_DIR / 'annonces_raw.csv'
    if not raw_file.exists():
        print(f"[ERROR] Raw data file not found: {raw_file}")
        sys.exit(1)
    
    df_raw = pd.read_csv(raw_file, encoding='utf-8')
    print(f"[OK] Loaded {len(df_raw)} records")
    
    # Load configuration
    print("\n[*] Loading configuration...")
    config = load_config()
    print(f"[OK] Configuration loaded")
    
    # TAB 3: Transform
    df_transformed = transform_data(df_raw, config)
    
    # TAB 4: Validate
    df_validated, validation_report = validate_data(df_transformed)
    
    # TAB 5: Export to SQL
    sql_file = export_to_sql(df_validated)
    
    # Load into database
    success, msg = load_into_database(sql_file)
    
    if success:
        print("\n" + "="*70)
        print("SUCCESS: Phase 2 Complete!")
        print("="*70)
        print(f"\nSummary:")
        print(f"  - Extracted: {validation_report['total_records']} records")
        print(f"  - Validated: {validation_report['valid_records']} records")
        print(f"  - Doublons removed: {validation_report['doublons']}")
        print(f"  - Database loaded: {validation_report['valid_records']} announcements")
    else:
        print(f"\n[ERROR] {msg}")
        sys.exit(1)

if __name__ == '__main__':
    main()
