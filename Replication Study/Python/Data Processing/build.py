"""
Estimation file data5: exporter x HS6 product x period panel of export
values and growth to the US, China and the rest of the world, with the
trade-war tariffs.

Python port of the authors' code/build.do, up to `save data5` (line 533).

Steps
1. Trade flows 2014-2019 (comtrade.py), world totals excluded, reporters
   present in 2014 only. Each row is an importer's (reporter's) imports from
   an exporter (partner).
2. Destinations: reporter US (rep 1), China (rep 2), all others (rep 3).
   Sum import values by exporter, destination, HS6 and two-year period
   (t = -1: 2014-15, 0: 2016-17, 1: 2018-19).
3. Exporters: ISO3 codes and names (iso_codes.csv) with the authors' fixes
   (Romania, Sudan, Mayotte, Switzerland, Monaco, Hong Kong, Taiwan); drop
   14 oil exporters and areas without an ISO3 code.
4. Merge the tariffs z_usch_w and z_chus_w (z_usch.py, z_chus.py).
5. Logs, log changes between periods and lags; HS2, HS4 and sectors
   (hs6_broad_sectors.dta, collapsed to 9 sectors).
6. Wide variables: for each exporter, product and period, exports to the US
   (v_us, lv_us, dlv_us), to China (_ch), to the rest of the world (_rw),
   US imports from China (_usch), China's imports from the US (_chus), and
   total exports (v_wd), with lags. One row per exporter x product x period.
7. Rank exporters by pre-war exports, drop HS6 999999 (not specified), keep
   the top 50 exporters (top50).

Not built here (not used by Figure 1, Figures A3-A4 or Table A2, and they
do not change which rows are kept): China's tariffs on other countries
(z_chrw), US tariffs by country (z_usi), the export-share weights sw_* and
the extra destinations (India, Hong Kong, China plus Hong Kong, rest of
world without Hong Kong).

Stata conventions reproduced: log(0) is missing; `generate` and `egen`
store 4-byte floats; l. and d. use the previous period of the same panel
unit and are missing if that row is absent; `duplicates drop` keeps the
first row in the current sort order; `egen mode` is missing when there is
more than one mode.

Input : Data/Processed/global_trade_hs6_ct_consistent_hs12_<year>.parquet
        Data/Processed/z_usch_w.parquet, z_chus_w.parquet
        Data/Raw/Wb_country_groups/iso_codes.csv
        Data/Raw/Crosswalk/hs6_broad_sectors.dta
Output: Data/Processed/data5.parquet, top50.parquet
"""

import sys
import time
from pathlib import Path

import numpy as np
import pandas as pd
import pyreadstat

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from config import CROSSWALK_DIR, PROCESSED_DIR, WB_COUNTRY_DIR  # noqa: E402

YEARS = range(2014, 2020)
USA, CHN, WORLD = 842, 156, 0
OIL_EXPORTERS = ["SAU", "RUS", "IRQ", "ARE", "NGA", "QAT", "NOR", "KAZ",
                 "KWT", "IRN", "AGO", "DZA", "OMN", "VEN"]


def f32(s):
    """Stata float storage (generate/egen default)."""
    return s.astype("float32")


# ---------------------------------------------------------------------------
# Panel helpers: Stata's l. and d. operators
# ---------------------------------------------------------------------------
class Panel:
    """Rows of d indexed by unit (ids) and period t, as after tsset."""

    def __init__(self, d, ids):
        key = d[ids + ["t"]].reset_index(drop=True)
        order = key.sort_values(ids + ["t"]).index.to_numpy()
        k = key.iloc[order]
        same_unit = np.ones(len(k), bool)
        for c in ids:
            v = k[c].to_numpy()
            same_unit &= np.r_[False, v[1:] == v[:-1]]
        tv = k["t"].to_numpy()
        consecutive = same_unit & np.r_[False, tv[1:] == tv[:-1] + 1]
        prev = np.full(len(d), -1)
        prev[order[1:][consecutive[1:]]] = order[:-1][consecutive[1:]]
        self.prev = prev

    def lag(self, s):
        """l.s: value in period t-1 of the same unit; missing if absent."""
        v = s.to_numpy(dtype="float64")
        out = np.where(self.prev >= 0, v[np.maximum(self.prev, 0)], np.nan)
        return pd.Series(out, index=s.index)

    def diff(self, s):
        """d.s = s - l.s."""
        return s.astype("float64") - self.lag(s)


def stata_mode(codes, groups):
    """egen mode(x), by(groups): missing if the most common value is tied."""
    d = pd.DataFrame({"x": codes, "g": groups}).dropna(subset=["x"])
    counts = d.groupby(["g", "x"]).size().reset_index(name="n")
    top = counts[counts["n"] == counts.groupby("g")["n"].transform("max")]
    mode = top[~top["g"].duplicated(keep=False)].set_index("g")["x"]
    return pd.Series(groups).map(mode).to_numpy()


# ---------------------------------------------------------------------------
# Steps
# ---------------------------------------------------------------------------
def read_trade():
    """Step 1: year, reporter, partner, hs6, import value."""
    cols = ["year", "reporter", "partner", "hs6", "import_value"]
    start = time.time()
    d = pd.concat([pd.read_parquet(
        PROCESSED_DIR / f"global_trade_hs6_ct_consistent_hs12_{y}.parquet",
        columns=cols) for y in YEARS], ignore_index=True)
    print(f"  trade flows: {len(d):,} rows ({time.time() - start:.0f} s)")
    d = d[d["year"].between(2014, 2019)
          & (d["partner"] != WORLD) & (d["reporter"] != WORLD)]
    reporters_2014 = d.loc[d["year"] == 2014, "reporter"].unique()
    return d[d["reporter"].isin(reporters_2014)]


def destinations_and_periods(d):
    """Step 2: sum by exporter, destination group, HS6 and period."""
    d = d.assign(rep=np.select([d["reporter"] == USA, d["reporter"] == CHN],
                               [1, 2], 3).astype("int8"))
    d = d[d["partner"] != d["reporter"]]
    d = d.assign(t=np.select([d["year"] <= 2015, d["year"] <= 2017], [-1, 0],
                             1).astype("int8"))
    d.loc[d["partner"] == 736, "partner"] = 729          # Sudan
    # gcollapse (sum): missing values count as zero.
    return (d.groupby(["partner", "rep", "hs6", "t"], as_index=False)
             ["import_value"].sum(min_count=0)
             .rename(columns={"import_value": "v"}))


def iso_table():
    """iso_codes.csv as build.do prepares it (missing ISO3 is "NULL")."""
    iso = pd.read_csv(WB_COUNTRY_DIR / "iso_codes.csv", encoding="latin-1",
                      keep_default_na=False, dtype=str,
                      usecols=["iso3digitalpha", "ctycode",
                               "ctyfullnameenglish", "endvalidyear"])
    iso = iso.rename(columns={"iso3digitalpha": "iso3", "ctycode": "iso_code",
                              "ctyfullnameenglish": "cty_name"})
    iso["iso_code"] = iso["iso_code"].astype(int)
    iso["endvalidyear"] = pd.to_numeric(iso["endvalidyear"])
    names = {"USA": "UNITED STATES", "CHN": "CHINA", "HKG": "HONG KONG"}
    iso["cty_name"] = iso["iso3"].map(names).fillna(iso["cty_name"])
    blm = pd.DataFrame({"iso3": ["BLM"], "iso_code": [652],
                        "cty_name": ["Saint Barthelemy"],
                        "endvalidyear": [np.nan]})
    iso = pd.concat([iso, blm], ignore_index=True)
    assert not iso["iso_code"].duplicated().any()
    return iso


def exporters(d):
    """Step 3: exporter codes, names and sample restrictions."""
    d.loc[d["partner"] == 946, "partner"] = 642          # Romania
    d = d[d["partner"] != 175]                           # Mayotte
    d = d.merge(iso_table(), left_on="partner", right_on="iso_code",
                how="left", validate="m:1")
    assert d["iso3"].notna().all(), "exporter code missing in iso_codes.csv"
    d = d.drop(columns="iso_code").rename(columns={"iso3": "cty_iso3"})
    d["partner_iso3"] = d["cty_iso3"].where(d["cty_iso3"] != "NULL", "")

    d["partner_name"] = d["cty_name"].str.upper()
    d.loc[d["partner"] == 757, ["partner_name", "cty_name"]] = "SWITZERLAND"
    d.loc[d["partner_name"] == "MONACO", "cty_iso3"] = "MCO"
    d.loc[d["cty_iso3"] == "HKG", "partner_name"] = "HONG KONG"
    taiwan = d["partner"] == 490
    d.loc[taiwan, ["cty_iso3", "partner_iso3"]] = "TWN"
    d.loc[taiwan, ["partner_name", "cty_name"]] = "TAIWAN"

    d = d[~d["cty_iso3"].str.contains("|".join(OIL_EXPORTERS))]
    return d[d["cty_iso3"] != "NULL"]


def merge_tariffs(d):
    """Step 4: US tariffs on China and China's tariffs on the US."""
    for name in ["z_usch_w", "z_chus_w"]:
        z = pd.read_parquet(PROCESSED_DIR / f"{name}.parquet")
        d = d.merge(z, on=["hs6", "t"], how="left", validate="m:1")
    return d


def logs_and_sectors(d):
    """Step 5: log changes, HS2/HS4 and the 9 sectors."""
    d["lv"] = f32(np.log(d["v"].where(d["v"] > 0)))
    p1 = Panel(d, ["partner", "rep", "hs6"])
    d["dlv"] = f32(p1.diff(d["lv"]))
    d["dlv_lag"] = f32(p1.lag(d["dlv"]))
    zs = [c for c in d.columns if c.startswith(("z_", "dz_"))]
    d[zs] = d[zs].fillna(0)                               # mvencode z_* dz_*

    d["hs2"] = d["hs6"] // 10000
    d["hs4"] = d["hs6"] // 100

    sectors, meta = pyreadstat.read_dta(
        str(CROSSWALK_DIR / "hs6_broad_sectors.dta"))
    labels = meta.variable_value_labels["hsind"]
    d = d.merge(sectors, on="hs6", how="left", validate="m:1")
    for level in ("hs4", "hs2"):
        d["hsind"] = d["hsind"].fillna(
            pd.Series(stata_mode(d["hsind"], d[level]), index=d.index))
    ind = d["hsind"].map(labels)
    ind = ind.replace({"Footwear": "Leathers", "Stone and Glass": "StoneGlass",
                       "Wood Products": "WoodProducts",
                       "Animal Products": "AnimalProducts"})
    ind = ind.replace({"Leathers": "Apparel", "Textiles": "Apparel",
                       "AnimalProducts": "Agriculture",
                       "Foodstuffs": "Agriculture",
                       "Vegetables": "Agriculture",
                       "Plastics": "Materials", "WoodProducts": "Materials",
                       "StoneGlass": "Materials"})
    d["ind9_str"] = ind
    d["ind9"] = encode(ind)
    d["country"] = encode(d["partner_name"])
    return d


def encode(s):
    """Stata encode: codes 1, 2, ... in alphabetical order of the text."""
    levels = sorted(s.dropna().unique())
    return s.map({v: i + 1 for i, v in enumerate(levels)}).astype("float64")


def wide_variables(d):
    """Step 6: exports by destination as columns, one row per exporter."""
    p2 = Panel(d, ["partner_name", "rep", "hs6"])
    groups = {
        "usch": ((d["rep"] == 1) & (d["partner_name"] == "CHINA"),
                 ["hs6", "t"]),
        "us": ((d["rep"] == 1) & (d["partner_name"] != "WORLD"),
               ["partner_name", "hs6", "t"]),
        "chus": ((d["rep"] == 2) & (d["partner_name"] == "UNITED STATES"),
                 ["hs6", "t"]),
        "ch": ((d["rep"] == 2) & (d["partner_name"] != "WORLD"),
               ["partner_name", "hs6", "t"]),
        "rw": ((d["rep"] == 3) & (d["partner_name"] != "WORLD"),
               ["partner_name", "hs6", "t"]),
    }
    for v in ["v", "lv", "dlv"]:
        for dest, (cond, by) in groups.items():
            x = f32(d[v].where(cond))
            col = f"{v}_{dest}"
            d[col] = f32(x.groupby([d[b] for b in by]).transform("mean"))
            z = f32(p2.lag(d[col]))
            d[col + "_lag"] = f32(z.groupby([d[b] for b in by])
                                  .transform("mean"))

    by = [d["partner"], d["hs6"], d["t"]]
    d["v_wd"] = d["v"].groupby(by).transform("sum")
    d["lv_wd"] = f32(np.log(d["v_wd"].where(d["v_wd"] > 0)))
    d["dlv_wd"] = f32(f32(p2.diff(d["lv_wd"])).groupby(by).transform("mean"))
    d["dlv_wd_lag"] = f32(f32(p2.lag(d["dlv_wd"])).groupby(by)
                          .transform("mean"))
    d["v_wd_lag"] = f32(f32(p2.lag(d["v_wd"])).groupby(by).transform("mean"))

    dlz = [c for c in d.columns if c.startswith("dlz")]
    d.loc[d["t"] == 1, dlz] = d.loc[d["t"] == 1, dlz].fillna(0)

    # duplicates drop partner hs6 t: keep the first row in the order of
    # tsset id t, where id = group(partner_name rep hs6).
    d = (d.sort_values(["partner_name", "rep", "hs6", "t"])
          .drop_duplicates(["partner", "hs6", "t"], keep="first")
          .drop(columns="rep"))
    d = d.sort_values(["partner", "hs6", "t"]).reset_index(drop=True)
    d["id"] = d.groupby(["partner", "hs6"]).ngroup() + 1
    return d


def final_sample(d):
    """Steps 6 (end) and 7: names, ranking, top 50 exporters."""
    zs = [c for c in d.columns if c.startswith(("dz_", "dlz_"))]
    d.loc[d["t"] < 1, zs] = 0.0
    d["partner_name"] = d["partner_name"].replace(
        {"BOLIVARIAN REPUBLIC OF VENEZUELA": "VENEZUELA",
         "TAIWAN, PROVINCE OF CHINA": "TAIWAN"}).str.replace(" ", "")
    d = d.drop(columns=["v", "lv", "dlv", "cty_name"])

    pre = d[d["t"] < 1].groupby(["partner", "partner_name"])["v_wd"].sum()
    rank = (pre.sort_values(ascending=False).reset_index()
               .assign(rank=lambda x: np.arange(1, len(x) + 1)))
    d = d.merge(rank[["partner", "rank"]], on="partner", how="left")
    d = d[~(d["rank"].isna() & (d["partner_iso3"] == "ANT"))]
    assert not d.duplicated(["hs6", "partner", "t"]).any()

    d.loc[d["cty_iso3"] == "KOR", "partner_name"] = "SOUTHKOREA"
    d["lv_wd_lag"] = f32(Panel(d, ["id"]).lag(d["lv_wd"]))
    d = d[d["hs6"] != 999999]

    top50 = (d.groupby("cty_iso3")["v_wd"].sum().sort_values(ascending=False)
              .head(50).index.to_frame(index=False))
    d = d.merge(top50, on="cty_iso3", how="inner")
    return d.reset_index(drop=True), top50


def main():
    print("Estimation file (build.do)")
    start = time.time()
    d = destinations_and_periods(read_trade())
    print(f"  exporter x destination x HS6 x period: {len(d):,} rows")
    d = merge_tariffs(exporters(d))
    d = wide_variables(logs_and_sectors(d))
    d, top50 = final_sample(d)

    d.to_parquet(PROCESSED_DIR / "data5.parquet", index=False)
    top50.to_parquet(PROCESSED_DIR / "top50.parquet", index=False)
    print(f"  saved data5.parquet: {len(d):,} rows, "
          f"{d['cty_iso3'].nunique()} exporters, {d['hs6'].nunique():,} "
          f"HS6 products ({time.time() - start:.0f} s)")


if __name__ == "__main__":
    main()
