#!/usr/bin/env python3
"""
UNITEE Phase 2 - Data Extraction Script
Fetches public market data from data.gouv.fr and BOAMP APIs
"""

import os
import sys
import json
import yaml
import pandas as pd
import numpy as np
import requests
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
        return {'keywords': {'primary': ['modulaire', 'préfabriqué'], 'secondary': []}}

def test_db_connection() -> Tuple[bool, str]:
    """Test MySQL connection"""
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        if conn.is_connected():
            cursor = conn.cursor()
            cursor.execute("SELECT DATABASE(), USER(), VERSION()")
            db, user, version = cursor.fetchone()
            cursor.close()
            conn.close()
            return True, f"DB: {db} | User: {user} | Version: {version}"
        return False, "Connection failed"
    except Exception as e:
        return False, str(e)

def extract_data_gouv_fr(keywords: List[str], limit: int = 100) -> pd.DataFrame:
    """Extract from data.gouv.fr API"""
    logger.info(f"Extracting from data.gouv.fr with keywords: {keywords}")
    
    try:
        # Search for BOAMP dataset
        search_url = "https://www.data.gouv.fr/api/1/datasets/?q=BOAMP&page_size=5"
        
        print(f"[*] Fetching from data.gouv.fr...")
        response = requests.get(search_url, timeout=15)
        response.raise_for_status()
        
        data = response.json()
        datasets = data.get('data', [])
        
        print(f"Found {len(datasets)} dataset(s)")
        
        all_dfs = []
        
        for i, dataset in enumerate(datasets[:3]):
            print(f"\n  [{i+1}] {dataset.get('title', 'Unknown')[:60]}")
            
            resources = dataset.get('resources', [])
            csv_files = [r for r in resources if r.get('format', '').upper() == 'CSV']
            
            if csv_files:
                csv_url = csv_files[0].get('url')
                if csv_url:
                    try:
                        print(f"      [*] Downloading CSV ({csv_url[:50]}...)...")
                        csv_response = requests.get(csv_url, timeout=30)
                        csv_response.raise_for_status()
                        
                        df = pd.read_csv(StringIO(csv_response.text), encoding='utf-8', dtype=str)
                        print(f"      [OK] Loaded {len(df)} rows, {len(df.columns)} columns")
                        
                        # Add source column
                        df['source_name'] = 'data.gouv.fr'
                        all_dfs.append(df)
                        
                    except Exception as e:
                        print(f"      [!] Error: {str(e)[:50]}")
                        continue
        
        if all_dfs:
            df_combined = pd.concat(all_dfs, ignore_index=True, sort=False)
            
            # Save raw
            raw_file = DATA_DIR / 'data_gouv_fr_raw.csv'
            df_combined.to_csv(raw_file, index=False, encoding='utf-8')
            print(f"\n[OK] Saved: {raw_file} ({len(df_combined)} rows)")
            
            return df_combined.head(limit)
        
        print("[!] No CSV files found")
        return pd.DataFrame()
        
    except Exception as e:
        logger.error(f"Error in data.gouv.fr extraction: {e}")
        print(f"[ERROR] Error: {e}")
        return pd.DataFrame()

def extract_boamp(keywords: List[str], limit: int = 100) -> pd.DataFrame:
    """Extract from BOAMP via data.gouv.fr"""
    logger.info(f"Extracting from BOAMP with keywords: {keywords}")
    
    try:
        # BOAMP datasets
        search_url = "https://www.data.gouv.fr/api/1/datasets/?q=bulletin+officiel&page_size=5"
        
        print(f"[*] Fetching BOAMP data...")
        response = requests.get(search_url, timeout=15)
        response.raise_for_status()
        
        data = response.json()
        datasets = data.get('data', [])
        
        print(f"Found {len(datasets)} dataset(s)")
        
        all_dfs = []
        
        for i, dataset in enumerate(datasets[:3]):
            print(f"\n  [{i+1}] {dataset.get('title', 'Unknown')[:60]}")
            
            resources = dataset.get('resources', [])
            csv_files = [r for r in resources if r.get('format', '').upper() == 'CSV']
            
            if csv_files:
                csv_url = csv_files[0].get('url')
                if csv_url:
                    try:
                        print(f"      [*] Downloading CSV...")
                        csv_response = requests.get(csv_url, timeout=30)
                        csv_response.raise_for_status()
                        
                        df = pd.read_csv(StringIO(csv_response.text), encoding='utf-8', dtype=str)
                        print(f"      [OK] Loaded {len(df)} rows, {len(df.columns)} columns")
                        
                        # Add source column
                        df['source_name'] = 'BOAMP'
                        all_dfs.append(df)
                        
                    except Exception as e:
                        print(f"      [!] Error: {str(e)[:50]}")
                        continue
        
        if all_dfs:
            df_combined = pd.concat(all_dfs, ignore_index=True, sort=False)
            
            # Save raw
            raw_file = DATA_DIR / 'boamp_raw.csv'
            df_combined.to_csv(raw_file, index=False, encoding='utf-8')
            print(f"\n[OK] Saved: {raw_file} ({len(df_combined)} rows)")
            
            return df_combined.head(limit)
        
        print("[!] No CSV files found")
        return pd.DataFrame()
        
    except Exception as e:
        logger.error(f"Error in BOAMP extraction: {e}")
        print(f"[ERROR] Error: {e}")
        return pd.DataFrame()

def create_synthetic_data(num_records: int = 50) -> pd.DataFrame:
    """Create synthetic test data"""
    logger.info(f"Creating {num_records} synthetic announcements")
    
    titles = [
        "Marché de travaux de construction modulaire",
        "Marché de bâtiment préfabriqué Île-de-France",
        "Appel d'offres construction rapide modulaire",
        "Travaux d'assemblage bâtiment en kit",
        "Construction modulaire pour structure temporaire",
        "Marché préfabriqué classe temporaire",
        "Travaux extension construction modulaire",
        "Assemblage rapide bâtiment modulaire France",
    ]
    
    regions_fr = ['Île-de-France', 'Auvergne-Rhône-Alpes', 'Provence-Alpes-Côte d\'Azur',
                  'Grand Est', 'Hauts-de-France', 'Normandie', 'Nouvelle-Aquitaine', 'Occitanie']
    
    data = []
    for i in range(num_records):
        data.append({
            'title': f"{titles[i % len(titles)]} #{i+1}",
            'description': f"Marché public pour travaux de construction modulaire - Annonce #{i+1}",
            'estimated_amount': str(np.random.randint(50000, 500000)),
            'publication_date': (datetime.now() - timedelta(days=np.random.randint(0, 30))).isoformat(),
            'response_deadline': (datetime.now() + timedelta(days=np.random.randint(7, 60))).isoformat(),
            'location': f"Commune #{i+1}",
            'region': np.random.choice(regions_fr),
            'source_name': 'synthetic',
            'external_id': f'SYNTH_{i+1:05d}',
        })
    
    return pd.DataFrame(data)

def main():
    """Main execution function"""
    
    print("\n" + "="*70)
    print("UNITEE Phase 2 - Data Extraction")
    print("="*70)
    
    # Load configuration
    print("\n[*] Loading configuration...")
    config = load_config()
    keywords = config.get('keywords', {}).get('primary', ['modulaire', 'préfabriqué'])
    print(f"[OK] Keywords: {keywords}")
    
    # Test DB connection
    print("\n[*] Testing database connection...")
    success, msg = test_db_connection()
    if success:
        print(f"[OK] {msg}")
    else:
        print(f"[ERROR] {msg}")
        print("[!] Continuing with extraction only...")
    
    # Extract data
    print("\n" + "="*70)
    print("EXTRACTION FROM APIs")
    print("="*70)
    
    dfs = []
    
    # 1. data.gouv.fr
    print("\n[1/3] data.gouv.fr")
    df_gouv = extract_data_gouv_fr(keywords, limit=100)
    if len(df_gouv) > 0:
        dfs.append(df_gouv)
        print(f"    Result: {len(df_gouv)} records")
    else:
        print(f"    Result: No data")
    
    # 2. BOAMP
    print("\n[2/3] BOAMP")
    df_boamp = extract_boamp(keywords, limit=100)
    if len(df_boamp) > 0:
        dfs.append(df_boamp)
        print(f"    Result: {len(df_boamp)} records")
    else:
        print(f"    Result: No data")
    
    # 3. Synthetic
    print("\n[3/3] Synthetic Data")
    df_synthetic = create_synthetic_data(50)
    dfs.append(df_synthetic)
    print(f"    Result: {len(df_synthetic)} records")
    
    # Combine all
    print("\n" + "="*70)
    print("DATA CONSOLIDATION")
    print("="*70)
    
    if dfs:
        df_raw = pd.concat(dfs, ignore_index=True, sort=False)
        
        # Save combined
        raw_file = DATA_DIR / 'annonces_raw.csv'
        df_raw.to_csv(raw_file, index=False, encoding='utf-8')
        
        print(f"\n[OK] COMPLETE: {len(df_raw)} total records")
        print(f"   Saved to: {raw_file}")
        print(f"\nColumns available:")
        for col in df_raw.columns:
            print(f"   - {col}")
    else:
        print("[ERROR] No data extracted")
        sys.exit(1)

if __name__ == '__main__':
    main()
