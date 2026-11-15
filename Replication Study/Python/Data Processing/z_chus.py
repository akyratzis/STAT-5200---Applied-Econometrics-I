"""
China's retaliatory tariffs on the US, by HS6 product and two-year period.

Python port of the authors' code/z_chus.do.

Steps
1. Read China's retaliation lists (HS8 product, tariff increase, effective
   date) from three Excel sheets: the 2018 waves, the June 2019 increase and
   the September 2019 increase.
2. Add the 2019 tariff reductions (exemptions) from Bown et al.
3. Average HS8 tariffs up to HS6 for each month, unweighted (z_chus) and
   weighted by China's 2017 imports from the US (z_chus_w, AKW data).
4. Add up the increases month by month over 2018-2019 and average the 24
   months; this is the war-period tariff increase of period t = 1.
5. Convert HS 2017 codes to HS 2012; tariffs are zero before the war, so the
   level in t = 1 equals the increase.
6. dlz_chus = change in log(1 + tariff) between periods (the regressor).

Input : Data/Raw/Retaliatory_tariffs/retaliatory_tariffs.xlsx
        Data/Raw/Retaliatory_tariffs/retaliatory_tariffs_2019.xlsx
        Data/Raw/Bown_etal/CHN_TR_onUS_HS10.dta
        Data/Raw/AKW/china_imports_from_usa.dta
        (z_chus.do reads this file from raw/china_trade_hs8/, but the
        package ships it in raw/AKW/)
        Data/Raw/Crosswalk/.../CompleteCorrelationsOfHS-SITC-BEC_20170606.xlsx
Output: Data/Processed/z_chus_w.parquet, one row per hs6 x t

Stata conventions reproduced here: a missing value counts as larger than any
number in comparisons, and sums treat missing values as zero.
"""

import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from config import (AKW_DIR, BOWN_DIR, PROCESSED_DIR,  # noqa: E402
                    RETALIATORY_DIR)
from tariff_common import f32, hs17_to_hs12, tariff_levels  # noqa: E402


def stata_month(year, month):
    """Stata monthly date tm(YYYYmM): months since January 1960."""
    return (year - 1960) * 12 + (month - 1)


def read_list(file, sheet, remove_dots=False):
    """One retaliation list: HS8 code (number), tariff, effective month."""
    d = pd.read_excel(RETALIATORY_DIR / file, sheet_name=sheet)
    d.columns = [str(c).lower() for c in d.columns]
    d = d[["hs8", "tariff", "effective_date"]].copy()
    hs8 = d["hs8"].astype("string")
    if remove_dots:
        hs8 = hs8.str.replace(".", "", regex=False)
    d["hs8"] = pd.to_numeric(hs8, errors="coerce")   # destring, force
    d["tariff"] = pd.to_numeric(d["tariff"], errors="coerce")
    d = d.dropna(subset=["hs8"])
    date = pd.to_datetime(d["effective_date"])
    d["mdate"] = stata_month(date.dt.year, date.dt.month)
    return d.drop(columns="effective_date")


def retaliation_lists():
    """Step 1: the three lists, with HS8 as an 8-character code."""
    d = pd.concat([
        read_list("retaliatory_tariffs.xlsx", "china"),
        read_list("retaliatory_tariffs_2019.xlsx", "china", remove_dots=True),
        read_list("retaliatory_tariffs.xlsx", "china_may2019"),
    ])
    # tostring hs8, then add the leading zero lost by the number format.
    s = d["hs8"].astype("int64").astype(str)
    d["hs8"] = s.where(s.str.len() != 7, "0" + s)
    print(f"  retaliation lists: {len(d):,} HS8 x wave rows; months "
          f"{sorted(d['mdate'].unique())}")
    return d


def exemptions():
    """Step 2: tariffs that fell back to zero in 2019 (Bown et al.).

    Missing values count as larger than any number, as in Stata.
    """
    b = pd.read_stata(BOWN_DIR / "CHN_TR_onUS_HS10.dta",
                      convert_categoricals=False)
    b["hs08"] = b["hs10"].str[:8]
    reta = [c for c in b.columns
            if c.startswith(("reta_2018", "reta_2019"))]
    b = b.groupby("hs08")[reta].mean().reset_index()
    b = b[b["hs08"] != ""]
    b[reta] = b[reta].astype("float32")    # collapse keeps float storage

    def gt0(c):
        return b[c].isna() | (b[c] > 0)

    later_zero = (b[["reta_2019Jan01", "reta_2019Jun01", "reta_2019Sep01",
                     "reta_2019Sep17", "reta_2019Dec26"]] == 0).any(axis=1)
    b = b[gt0("reta_2018Sep24") & later_zero]
    b = b[b[reta].fillna(0).sum(axis=1) != 0]

    dec19 = gt0("reta_2019Sep17") & (b["reta_2019Dec26"] == 0)
    out = pd.DataFrame({
        "hs8": b["hs08"],
        "mdate": np.where(dec19, stata_month(2019, 12),
                          stata_month(2019, 1)),
        "tariff": np.where(dec19,
                           -b["reta_2019Sep17"].astype("float64") / 100,
                           -b["reta_2018Sep24"].astype("float64") / 100),
    })
    print(f"  exemptions (Bown et al.): {len(out):,} HS8 products")
    return out


def hs6_monthly(d):
    """Step 3: HS6 x month tariffs, unweighted and import-weighted."""
    akw = pd.read_stata(AKW_DIR / "china_imports_from_usa.dta")
    assert not akw["hs8"].duplicated().any()
    d = d.merge(akw, on="hs8", how="left")            # drop if _m == 2
    d["hs6"] = d["hs8"].str[:6]

    tot = (akw.assign(hs6=akw["hs8"].str[:6])
              .groupby("hs6")["value"].sum().rename("tot_hs6"))
    d = d.merge(tot, on="hs6", how="left")
    sh = (d["value"] / d["tot_hs6"]).where(d["tot_hs6"] != 0)
    d["tariff_w"] = sh.fillna(0) * d["tariff"]
    d["tariff_m"] = f32(d.groupby(["hs6", "mdate"])["tariff"]
                         .transform("max"))

    g = d.groupby(["hs6", "mdate"])
    return pd.DataFrame({
        "z_chus_w": g["tariff_w"].sum(min_count=0),   # missing count as 0
        "z_chus_max": g["tariff_m"].max(),
        "z_chus": g["tariff"].mean(),
    }).reset_index()


def two_year_average(m):
    """Step 4: cumulative tariff by month, averaged over 2018m1-2019m12."""
    months = range(stata_month(2018, 1), stata_month(2019, 12) + 1)
    template = pd.MultiIndex.from_product([m["hs6"].unique(), months],
                                          names=["hs6", "mdate"])
    keys = template.union(pd.MultiIndex.from_frame(m[["hs6", "mdate"]]))
    # fillin hs6 mdate: every product in every month that appears.
    full = pd.MultiIndex.from_product(
        [keys.get_level_values("hs6").unique(),
         np.sort(keys.get_level_values("mdate").unique())],
        names=["hs6", "mdate"])
    p = m.set_index(["hs6", "mdate"]).reindex(full).sort_index()

    zs = ["z_chus", "z_chus_w", "z_chus_max"]
    p[zs] = p[zs].fillna(0).groupby(level="hs6").cumsum()   # running sum
    p = p.groupby(level="hs6")[zs].mean()
    p = p.rename(columns={"z_chus": "z_chus_2yr", "z_chus_w": "z_chus_w_2yr",
                          "z_chus_max": "z_chus_max_2yr"})

    for z in p.columns:            # tiny rounding errors set to zero
        p[z] = p[z].mask(p[z].between(-0.000001, 0.00001), 0.0)
        assert (p[z] >= 0).all()
    return p.reset_index()


def periods(p):
    """Steps 5-6: HS12 codes, periods -1/0/1, levels and log changes."""
    p["hs6"] = p["hs6"].astype("int64")
    p = hs17_to_hs12(p)
    g = p.groupby("hs6")
    p = pd.DataFrame({
        "z_chus_w": g["z_chus_w_2yr"].mean(),
        "z_chus": g["z_chus_2yr"].mean(),
        "z_chus_max_2yr": f32(g["z_chus_max_2yr"].max()),
    }).reset_index()

    # Period 1 holds the war-period values; periods -1 and 0 are zero.
    p = pd.concat([p.assign(t=1),
                   p.assign(t=0, z_chus_w=0.0, z_chus=0.0, z_chus_max_2yr=0.0),
                   p.assign(t=-1, z_chus_w=0.0, z_chus=0.0,
                            z_chus_max_2yr=0.0)])
    zs = ["z_chus_w", "z_chus", "z_chus_max_2yr"]
    for z in zs:
        p["d" + z] = f32(p[z])                     # g dz = z (a float)
    return tariff_levels(p, "chus", zs, stata_float=False)


def main():
    print("China's tariffs on the US (z_chus.do)")
    d = pd.concat([retaliation_lists(), exemptions()], ignore_index=True)
    p = periods(two_year_average(hs6_monthly(d)))
    p = p[["hs6", "t", "z_chus_w", "z_chus", "z_chus_max_2yr", "dz_chus_w",
           "dz_chus", "dz_chus_max_2yr", "dlz_chus", "dlz_chus_w"]]

    out = PROCESSED_DIR / "z_chus_w.parquet"
    p.to_parquet(out, index=False)
    print(f"  saved {out.name}: {len(p):,} rows "
          f"({p['hs6'].nunique():,} HS6 products x periods)")


if __name__ == "__main__":
    main()
