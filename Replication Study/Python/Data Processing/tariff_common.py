"""
Steps shared by z_usch.py (US tariffs on China) and z_chus.py (China's
tariffs on the US).

1. hs17_to_hs12: convert HS 2017 product codes to HS 2012, as both Stata
   scripts do with `joinby hs6 using <crosswalk>, unmatched(master)`.
2. tariff_levels: the common ending of both scripts, which sets the tariff
   level in each period and computes the change in log(1 + tariff).
"""

import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from config import CROSSWALK_DIR  # noqa: E402

CROSSWALK_FILE = (CROSSWALK_DIR / "Crosswalk_consistent_HS6"
                  / "CompleteCorrelationsOfHS-SITC-BEC_20170606.xlsx")


def f32(s):
    """Store as a Stata float (4 bytes), as `generate` does by default."""
    return s.astype("float32")


def hs17_to_hs12(d):
    """Replace HS 2017 codes in column hs6 by their HS 2012 equivalents.

    A code found in the crosswalk becomes one row per matching HS 2012 code;
    a code not in the crosswalk is kept unchanged.
    """
    x = pd.read_excel(CROSSWALK_FILE, dtype=str, usecols=["HS17", "HS12"])
    x = x[x["HS12"] != "NULL"]
    x = x.apply(pd.to_numeric, errors="coerce").dropna()
    x = x.astype("int64").drop_duplicates().rename(columns={"HS17": "hs6"})

    d = d.merge(x, on="hs6", how="left")
    d["hs6"] = d.pop("HS12").fillna(d["hs6"]).astype("int64")
    return d


def tariff_levels(p, name, zs, stata_float):
    """Tariff level in each period and the change in log(1 + tariff).

    p has one row per hs6 x t (t = -1, 0, 1), level columns zs and their
    changes "d" + z. Reproduces, after `tsset hs6 t`:
        by hs6: carryforward z_*
        replace dz* = 0 if t<1
        foreach z: replace z = l.z if t>=0
                   replace z = l.z + dz if t>=0
        dlz = d.log(1+z), missing set to 0
    Stata's `replace` works row by row, so period 1 uses the period-0 value
    just computed: z(0) = z(-1) and z(1) = z(-1) + dz(1). l. and d. refer to
    period t-1 of the same product and are missing if that row is absent.
    stata_float: True if the levels are stored as 4-byte floats in Stata.
    """
    store = f32 if stata_float else (lambda s: s.astype("float64"))
    p = p.sort_values(["hs6", "t"]).reset_index(drop=True)
    p[zs] = p.groupby("hs6")[zs].ffill()
    p.loc[p["t"] < 1, ["d" + z for z in zs]] = 0.0

    # Full product x period grid, so that "period t-1" is a simple shift;
    # rows absent from the data are marked and removed at the end.
    grid = pd.MultiIndex.from_product([p["hs6"].unique(), [-1, 0, 1]],
                                      names=["hs6", "t"])
    p = p.assign(present=True).set_index(["hs6", "t"]).reindex(grid)
    p["present"] = p["present"].fillna(False).astype(bool)
    t_of_row = p.index.get_level_values("t")

    def lag(s):
        return s.groupby(level="hs6").shift()

    for z in zs:
        for t in (0, 1):                       # replace z = l.z if t>=0
            rows = t_of_row == t
            p.loc[rows, z] = lag(p[z])[rows]
        for t in (0, 1):                       # replace z = l.z + dz if t>=0
            rows = t_of_row == t
            p.loc[rows, z] = store(lag(p[z]) + p["d" + z])[rows]
        p.loc[~p["present"], z] = np.nan

    for z in [f"z_{name}", f"z_{name}_w"]:
        lz = f32(np.log1p(p[z].astype("float64")))
        p["dl" + z] = f32(lz - lag(lz)).fillna(0.0)   # mvencode dlz*, mv(0)

    p = p[p.pop("present")].reset_index()
    return p.astype({"hs6": "int32", "t": "int8"})
