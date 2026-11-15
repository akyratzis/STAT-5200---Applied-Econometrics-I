"""
US tariffs on China, by HS6 product and two-year period.

Python port of the authors' code/z_usch.do.

Steps
1. Monthly US imports from China by HS10 product (2015-2019), with the US
   tariff columns the authors merged into the Census file.
2. Keep products that have a China weight (china_weight.py) and complete the
   monthly panel, filling tariffs forward (and backward for early months).
3. Apply the authors' hard-coded fixes for the September 2018, October 2018,
   May 2019 and September 2019 tariff waves.
4. Average HS10 tariffs up to HS6 for each month, then average months
   within the two-year periods t = -1 (2015), 0 (2016-17) and 1 (2018-19).
5. Convert HS 2017 codes to HS 2012 and build the tariff level in each period
   as the 2015 level plus the war-period increase.
6. dlz_usch = change in log(1 + tariff) between periods (the regressor).

Input : CENSUS_DIR/m_flow_hs10_fm.dta (authors' package)
        Data/Processed/china_weight_hs6.parquet (from china_weight.py)
        Data/Raw/Crosswalk/.../CompleteCorrelationsOfHS-SITC-BEC_20170606.xlsx
Output: Data/Processed/z_usch_w.parquet, one row per hs6 x t

Stata conventions reproduced here: a missing value counts as larger than any
number in comparisons, and `generate` stores 4-byte floats.
"""

import sys
import time
from pathlib import Path

import numpy as np
import pandas as pd
import pyreadstat

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from config import CENSUS_DIR, PROCESSED_DIR  # noqa: E402
from tariff_common import f32, hs17_to_hs12, tariff_levels  # noqa: E402


def stata_month(year, month):
    """Stata monthly date tm(YYYYmM): months since January 1960."""
    return (year - 1960) * 12 + (month - 1)


def read_census_china():
    """Step 1: US imports from China by HS10 and month, 2015 onward."""
    path = CENSUS_DIR / "m_flow_hs10_fm.dta"
    cols = ["id", "cty_code", "cty_name", "hs10", "hs6", "year", "mdate",
            "m_stattariff4", "m_increase", "m_effective_mdate4", "m_T"]
    start = time.time()
    d, _ = pyreadstat.read_dta(str(path), usecols=cols,
                               disable_datetime_conversion=True)
    d = d[(d["cty_name"] == "CHINA") & (d["year"] >= 2015)]
    print(f"  read {path.name}: {len(d):,} China rows from 2015 "
          f"({time.time() - start:.0f} s)")
    return d.drop(columns=["cty_name", "year"])


def monthly_panel(d):
    """Step 2: merge weights and complete the product x month panel."""
    w = pd.read_parquet(PROCESSED_DIR / "china_weight_hs6.parquet",
                        columns=["hs10", "cty_code", "m_cty_weight_hs6"])
    d = d.merge(w, on=["cty_code", "hs10"], how="inner")   # keep(match)
    d = d.rename(columns={"m_cty_weight_hs6": "w"})

    # fillin id mdate: every product in every month.
    full = pd.MultiIndex.from_product(
        [d["id"].unique(), np.sort(d["mdate"].unique())],
        names=["id", "mdate"])
    d = (d.set_index(["id", "mdate"]).reindex(full).reset_index()
          .sort_values(["id", "mdate"]))

    # Product characteristics and weights are constant within a product:
    # copy them into the added months (Stata: carryforward after gsort).
    g = d.groupby("id")
    for v in ["cty_code", "hs10", "hs6", "m_effective_mdate4", "m_T", "w"]:
        d[v] = g[v].transform("first")
    # Tariffs: carry forward in time; the statutory tariff also backward.
    d[["m_stattariff4", "m_increase"]] = g[["m_stattariff4",
                                            "m_increase"]].ffill()
    d["m_stattariff4"] = d.groupby("id")["m_stattariff4"].bfill()
    return d.reset_index(drop=True)


def manual_fixes(d):
    """Step 3: the authors' corrections for China (cty_code 5700).

    Applied in the same order as in z_usch.do, because each condition uses
    m_increase == 0 and earlier lines change m_increase.
    """
    oct18 = d["m_effective_mdate4"] == stata_month(2018, 10)
    sep19 = d["m_effective_mdate4"] == stata_month(2019, 9)
    china = d["cty_code"] == 5700
    tariff = d["m_stattariff4"].astype("float64")
    fixes = [  # (effective month, rows' months, increase)
        (oct18, d["mdate"] >= stata_month(2019, 5), 0.25),
        (oct18, d["mdate"] == stata_month(2018, 9), 0.02),
        (oct18, d["mdate"] >= stata_month(2018, 10), 0.10),
        (sep19, d["mdate"] >= stata_month(2019, 9), 0.15),
    ]
    for effective, months, inc in fixes:
        rows = effective & (d["m_increase"] == 0) & months & china
        tariff = tariff.where(~rows, f32(tariff + inc).astype("float64"))
        d.loc[rows, "m_increase"] = inc
    d["m_stattariff4"] = f32(tariff)
    return d


def weighted_mean(d, x, w, by):
    """Stata collapse (mean) x [aweight=w], ignoring missing x."""
    ok = d[x].notna()
    num = (d[x].where(ok, 0) * d[w].where(ok, 0)).groupby(
        [d[b] for b in by]).sum()
    den = d[w].where(ok, 0).groupby([d[b] for b in by]).sum()
    return num / den


def to_hs6_month(d):
    """Step 4a: from HS10 to HS6 for each month."""
    # z: tariff increase, zero before the month preceding the effective month
    # (a missing effective month counts as +infinity, so z = 0 there).
    eff = d["m_effective_mdate4"].fillna(np.inf)
    d["z"] = d["m_increase"].where(~(d["mdate"] < eff - 1), 0.0)
    d["w"] = d["w"].fillna(0.0)

    check = d.groupby(["hs6", "mdate"])["w"].transform("sum")
    assert 0.999 <= check[check > 0].mean() <= 1.001

    d = d.rename(columns={"m_stattariff4": "m_tariff_weighted",
                          "m_increase": "m_increase_weighted"})
    g = d.groupby(["hs6", "mdate"])
    d["m_tariff"] = f32(g["m_tariff_weighted"].transform("mean"))
    d["m_increase"] = g["m_increase_weighted"].transform("mean")
    d["m_tariff_max"] = g["m_tariff_weighted"].transform("max")

    # gcollapse ... [aw=w], by(hs6 mdate). Observations with zero weight do
    # not count in any of the statistics.
    by = ["hs6", "mdate"]
    pos = d[d["w"] > 0]
    gp = pos.groupby(by)
    out = pd.DataFrame({
        "m_tariff": weighted_mean(pos, "m_tariff", "w", by),
        "m_tariff_weighted": weighted_mean(pos, "m_tariff_weighted", "w", by),
        "m_increase": weighted_mean(pos, "m_increase", "w", by),
        "m_increase_weighted": weighted_mean(pos, "m_increase_weighted",
                                             "w", by),
        "m_T_prod": gp["m_T"].max(),
        "m_increase_max": gp["z"].max(),
        "m_tariff_max": gp["m_tariff_max"].max(),
        "m_effective_mdate4": gp["m_effective_mdate4"].min(),
    })
    return out.reset_index()


def to_periods(m):
    """Step 4b: average months within the two-year periods."""
    year = 1960 + m["mdate"] // 12
    m["t"] = np.select([year.between(2014, 2015), year.between(2016, 2017),
                        year.between(2018, 2019)], [-1, 0, 1], np.nan)
    g = m.groupby(["hs6", "t"])
    return pd.DataFrame({
        "z_usch": g["m_tariff"].mean(),
        "z_usch_max": g["m_tariff_max"].mean(),
        "z_usch_w": g["m_tariff_weighted"].mean(),
        "dz_usch": g["m_increase"].mean(),
        "dz_usch_w": g["m_increase_weighted"].mean(),
        "dz_usch_max": g["m_increase_max"].max(),
    }).reset_index()


def levels_and_log_changes(p):
    """Steps 5-6: HS12 codes, tariff levels by period, log changes."""
    p = hs17_to_hs12(p)
    g = p.groupby(["hs6", "t"])
    p = pd.DataFrame({
        "z_usch": g["z_usch"].mean(), "z_usch_w": g["z_usch_w"].mean(),
        "dz_usch": g["dz_usch"].mean(), "dz_usch_w": g["dz_usch_w"].mean(),
        "z_usch_max": g["z_usch_max"].max(),
        "dz_usch_max": g["dz_usch_max"].max(),
    }).reset_index().sort_values(["hs6", "t"])

    return tariff_levels(p, "usch", ["z_usch", "z_usch_w", "z_usch_max"],
                         stata_float=True)


def main():
    print("US tariffs on China (z_usch.do)")
    d = read_census_china()
    d = manual_fixes(monthly_panel(d))
    p = levels_and_log_changes(to_periods(to_hs6_month(d)))

    out = PROCESSED_DIR / "z_usch_w.parquet"
    p.to_parquet(out, index=False)
    print(f"  saved {out.name}: {len(p):,} rows "
          f"({p['hs6'].nunique():,} HS6 products x periods)")


if __name__ == "__main__":
    main()
