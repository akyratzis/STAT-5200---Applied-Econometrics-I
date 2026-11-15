"""
Paths shared by all replication scripts.

Scripts
    Python/config.py               this file
    Python/comtrade_download.py    downloads the UN Comtrade data
    Python/Data Processing/        raw data -> Data/Processed (ports of the
                                   authors' data processing do-files)
    Python/Data Analysis/          Data/Processed -> Figures and Tables

Scripts in the subfolders import this file with
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from config import ...

Data locations
1. This repository (Replication Study/):
   Data/Raw         small raw files copied from the authors' package, and the
                    UN Comtrade catalogue and download log
   Data/Processed   datasets built by the Data Processing scripts
   Figures, Tables  outputs of the Data Analysis scripts
2. The UN Comtrade data files (about 14 GB), kept outside the repository and
   outside iCloud. Set the environment variable COMTRADE_DATA_DIR to their
   folder, or leave it unset to use ~/Downloads/Comtrade_raw.
3. The authors' replication package (about 18 GB), kept outside the
   repository. The pipeline reads only the two US Census files from it.
   Set the environment variable GTW_REPLICATION_DIR to its folder, or leave it
   unset to use ~/Downloads/GTW_replication.
"""

import os
from pathlib import Path

# --- This repository ---------------------------------------------------------
REPLICATION_DIR = Path(__file__).resolve().parent.parent

RAW_DIR = REPLICATION_DIR / "Data" / "Raw"
PROCESSED_DIR = REPLICATION_DIR / "Data" / "Processed"
FIGURES_DIR = REPLICATION_DIR / "Figures"
TABLES_DIR = REPLICATION_DIR / "Tables"

# Raw data by source (folder names follow the authors' data/raw/ folders).
COMTRADE_RAW_DIR = RAW_DIR / "Comtrade"             # catalogue + download log
AKW_DIR = RAW_DIR / "AKW"                           # China's imports from the US
BOWN_DIR = RAW_DIR / "Bown_etal"                    # China's 2019 exemptions
CROSSWALK_DIR = RAW_DIR / "Crosswalk"               # HS17->HS12, sectors
RETALIATORY_DIR = RAW_DIR / "Retaliatory_tariffs"   # China's retaliation lists
WB_COUNTRY_DIR = RAW_DIR / "Wb_country_groups"      # ISO country codes

# --- UN Comtrade data files (outside the repository) -------------------------
# One gzip file per reporter and year, in <year>/ subfolders. Written by
# comtrade_download.py, read by Data Processing/comtrade.py.
COMTRADE_DATA_DIR = Path(os.environ.get(
    "COMTRADE_DATA_DIR",
    Path.home() / "Downloads" / "Comtrade_raw"))

# --- Authors' replication package (outside the repository) -------------------
PACKAGE_DIR = Path(os.environ.get(
    "GTW_REPLICATION_DIR",
    Path.home() / "Downloads" / "GTW_replication"))

# US Census monthly HS10 trade with US tariffs (13 GB): read in place.
# Used by Data Processing/china_weight.py and z_usch.py.
CENSUS_DIR = PACKAGE_DIR / "data" / "raw" / "census_trade"
