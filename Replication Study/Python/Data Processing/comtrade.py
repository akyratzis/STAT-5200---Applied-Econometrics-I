"""
Trade flows: UN Comtrade bulk files -> one table of bilateral trade by HS6
product and year, in the format of the authors' trade file.

Python port of the authors' code/comtrade.do. The authors started from
Comtrade "Classic" extracts (raw/comtrade/<year>.dta, not included in their
package); we start from the "Plus" bulk files downloaded by
comtrade_download.py, so this script also does what their extraction did:

1. Keep the rows that hold total trade: all customs procedures (customsCode
   C00), all modes of transport (motCode 0), no second partner
   (partner2Code 0), imports (M) and exports (X) only, 6-digit HS products.
   Plus files also contain these flows broken down by procedure and mode,
   and re-exports, re-imports and processing trade, which are dropped.
2. Drop regional aggregates that report as a single area: the EU (97) and
   ASEAN (975).
3. Use the country codes of the authors' file: Italy is 380 in the Plus
   files and 381 in Classic. Every other code is the same (checked against
   all codes in the authors' file).
4. One row per year x reporter x partner x HS6, with imports and exports
   side by side, values in millions of US dollars (comtrade.do divides by
   10^6), quantities and net weights as reported. Partner 0 is the world.
5. ISO3 codes from Data/Raw/Wb_country_groups/iso_codes.csv. The file lacks
   Saint Barthelemy (652), which is set to BLM as in the authors' file.

comtrade.do also saves a list of partner names
(global_trade_hs6_ct_hs12_partnerlist); no later script uses it, so it is
not rebuilt.

Input : COMTRADE_DATA_DIR/<year>/comtrade_H4_<year>_<reporter>_plus.txt.gz
Output: Data/Processed/global_trade_hs6_ct_consistent_hs12_<year>.parquet,
        one file per year (too large for GitHub; rebuilt by this script)

Usage (from the Python folder):
    python "Data Processing/comtrade.py"                 # 2014-2019
    python "Data Processing/comtrade.py" --years 2014    # one year
"""

import argparse
import sys
import time
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from config import (COMTRADE_DATA_DIR, PROCESSED_DIR,  # noqa: E402
                    WB_COUNTRY_DIR)

YEARS = [2014, 2015, 2016, 2017, 2018, 2019]
AGGREGATE_REPORTERS = {97, 975}          # EU-27, ASEAN
PLUS_TO_CLASSIC = {380: 381}             # Italy
ISO3_MISSING = {652: "BLM"}              # Saint Barthelemy

PLUS_COLUMNS = {"refYear": "int16", "reporterCode": "int16",
                "flowCode": "string", "partnerCode": "int16",
                "partner2Code": "int16", "cmdCode": "string",
                "customsCode": "string", "motCode": "int32",
                "qty": "float64", "netWgt": "float64",
                "primaryValue": "float64"}


def read_plus_file(path):
    """Total imports and exports by partner and HS6 product in one file."""
    d = pd.read_csv(path, sep="\t", usecols=list(PLUS_COLUMNS),
                    dtype=PLUS_COLUMNS)
    d = d[(d["customsCode"] == "C00") & (d["motCode"] == 0)
          & (d["partner2Code"] == 0) & d["flowCode"].isin(["M", "X"])
          & (d["cmdCode"].str.len() == 6)]
    return d.drop(columns=["customsCode", "motCode", "partner2Code"])


def iso3_codes():
    """Comtrade country code -> ISO3, from the authors' iso_codes.csv."""
    iso = pd.read_csv(WB_COUNTRY_DIR / "iso_codes.csv", encoding="latin-1",
                      usecols=["ctycode", "iso3digitalpha"])
    iso = iso.drop_duplicates("ctycode").set_index("ctycode")
    codes = iso["iso3digitalpha"].to_dict()
    codes.update(ISO3_MISSING)
    return codes


def build_year(year, iso3):
    files = sorted((COMTRADE_DATA_DIR / str(year)).glob("*_plus.txt.gz"))
    if not files:
        sys.exit(f"No Comtrade files for {year} in {COMTRADE_DATA_DIR}. "
                 "Run comtrade_download.py first.")
    start = time.time()
    d = pd.concat([read_plus_file(f) for f in files], ignore_index=True)
    d = d[~d["reporterCode"].isin(AGGREGATE_REPORTERS)]
    for col in ("reporterCode", "partnerCode"):
        d[col] = d[col].replace(PLUS_TO_CLASSIC)
    assert not d.duplicated(["reporterCode", "partnerCode", "cmdCode",
                             "flowCode"]).any()

    # Imports and exports side by side, as in the authors' file.
    d["primaryValue"] = d["primaryValue"] / 10 ** 6       # $ millions
    wide = d.pivot(index=["refYear", "reporterCode", "partnerCode",
                          "cmdCode"],
                   columns="flowCode",
                   values=["qty", "netWgt", "primaryValue"])
    names = {("qty", "M"): "import_quantity", ("netWgt", "M"): "imports_nw",
             ("primaryValue", "M"): "import_value",
             ("qty", "X"): "export_quantity", ("netWgt", "X"): "exports_nw",
             ("primaryValue", "X"): "export_value"}
    wide.columns = [names[c] for c in wide.columns]
    wide = wide.reset_index().rename(columns={
        "refYear": "year", "reporterCode": "reporter",
        "partnerCode": "partner", "cmdCode": "hs6"})
    wide["hs6"] = wide["hs6"].astype("int32")
    wide["reporter_iso3"] = wide["reporter"].map(iso3).fillna("")
    wide["partner_iso3"] = wide["partner"].map(iso3).fillna("")

    cols = ["year", "reporter", "partner", "hs6", "import_quantity",
            "imports_nw", "import_value", "export_quantity", "exports_nw",
            "export_value", "reporter_iso3", "partner_iso3"]
    wide = (wide[cols].sort_values(["reporter", "partner", "hs6"])
                .reset_index(drop=True))
    out = PROCESSED_DIR / f"global_trade_hs6_ct_consistent_hs12_{year}.parquet"
    wide.to_parquet(out, index=False)
    print(f"  {year}: {len(files)} files, {wide['reporter'].nunique()} "
          f"reporters, {len(wide):,} rows -> {out.name} "
          f"({time.time() - start:.0f} s)")


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--years", type=int, nargs="+", default=YEARS)
    args = p.parse_args()

    print("Trade flows (comtrade.do)")
    iso3 = iso3_codes()
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    for year in args.years:
        build_year(year, iso3)


if __name__ == "__main__":
    main()
