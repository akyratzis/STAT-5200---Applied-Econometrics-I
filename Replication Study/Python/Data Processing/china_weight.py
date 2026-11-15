"""
China weights: pre-war importance of each HS10 product within its HS6 group.

Python port of the authors' code/china_weight.do.

For US imports from China in 2015-2017, each HS10 product's share of China's
total imports in its HS6 group; the same for US exports to China. The import
shares are used by z_usch.py to average US tariffs from HS10 up to HS6, and
the merge with this file decides which HS10 products enter that average.

Input : US Census monthly HS10 trade, in the authors' package
        (CENSUS_DIR/m_flow_hs10_fm.dta and x_flow_hs10_fm.dta)
Output: Data/Processed/china_weight_hs6.parquet
        one row per HS10 product x country (all China), columns
        hs10, hs6, cty_code, m_cty_weight_hs6, x_cty_weight_hs6
"""

import sys
import time
from pathlib import Path

import pyreadstat

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from config import CENSUS_DIR, PROCESSED_DIR  # noqa: E402


def read_census_china(flow):
    """US trade with China in 2015-2017 from the Census file.

    flow is "m" (imports) or "x" (exports). Mirrors
    `use * if inrange(year,2015,2017) & cty_name=="CHINA" using ...`
    but reads only the columns we need.
    """
    path = CENSUS_DIR / f"{flow}_flow_hs10_fm.dta"
    cols = ["cty_name", "cty_code", "hs10", "hs6", "year", f"{flow}_val"]
    start = time.time()
    d, _ = pyreadstat.read_dta(str(path), usecols=cols)
    d = d[(d["cty_name"] == "CHINA") & d["year"].between(2015, 2017)]
    print(f"  read {path.name}: {len(d):,} China rows, 2015-17 "
          f"({time.time() - start:.0f} s)")
    return d.drop(columns=["cty_name", "year"])


def variety_weights(d, flow):
    """Share of each HS10 product in China's trade within its HS6 group."""
    val = f"{flow}_val"
    name = f"{flow}_cty_weight_hs6"

    # Total trade within HS6, and within HS10 x country.
    tot = d.groupby("hs6", dropna=False)[val].transform("sum")
    c = d.groupby(["hs10", "cty_code"], dropna=False)[val].transform("sum")

    # Share; Stata gives missing (not infinity) when dividing by zero.
    d = d.assign(**{name: (c / tot).where(tot != 0)})

    # One row per HS10 x country (the share is constant within it).
    d = (d.groupby(["hs10", "hs6", "cty_code"], dropna=False)[name]
          .mean().reset_index())

    # Checks from the Stata code: shares sum to 1 within HS6; unique keys.
    d = d.dropna(subset=["cty_code", "hs10", "hs6"])
    check = d.groupby("hs6")[name].transform("sum")
    assert 0.999 <= check.mean() <= 1.001
    assert not d.duplicated(["hs10", "cty_code"]).any()

    d[name] = d[name].astype("float32")   # Stata `generate` stores floats
    return d


def main():
    print("China weights (china_weight.do)")
    m = variety_weights(read_census_china("m"), "m")
    x = variety_weights(read_census_china("x"), "x")

    # merge 1:1 hs10 cty_code, keeping products found in either flow.
    w = m.merge(x, on=["hs10", "cty_code"], how="outer",
                suffixes=("", "_x"))
    w["hs6"] = w["hs6"].fillna(w.pop("hs6_x"))
    w = w.sort_values(["hs10", "cty_code"]).reset_index(drop=True)
    assert not w.duplicated(["cty_code", "hs10"]).any()

    w = w.astype({"hs6": "int32", "cty_code": "int16"})
    w = w[["hs10", "hs6", "cty_code", "m_cty_weight_hs6",
           "x_cty_weight_hs6"]]

    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    out = PROCESSED_DIR / "china_weight_hs6.parquet"
    w.to_parquet(out, index=False)
    print(f"  saved {out.name}: {len(w):,} rows")


if __name__ == "__main__":
    main()
