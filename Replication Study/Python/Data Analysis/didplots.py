"""
Figure 1, Figures A3-A4 and Table A2: export growth against tariff changes,
before and during the trade war.

Python port of the authors' code/didplots.do.

Every regression has one outcome and one tariff, estimated separately for
the pre-war period (t = 0, 2015-17) and the war period (t = 1, 2017-19):

    dlv = a + b * dlz + e

dlv is the log change in an exporter's exports of an HS6 product, dlz the
change in log(1 + tariff). In the pre-war regression dlz is the product's
war-period tariff change, so b tests for pre-existing trends.

  Figure 1   bystanders (all exporters except the US and China); standard
             errors clustered by HS6 product
  Figure A3  as Figure 1, with exporter x sector fixed effects
  Figure A4  China's exports to the US and US exports to China (no clusters)
  Table A2   the 16 bystander regressions behind Figures 1 and A3

The package saves Figures A3 and A4 as appendix/fig_a2.pdf and fig_a3.pdf;
here they are named by the paper's numbering.

Input : Data/Processed/data5.parquet (from Data Processing/build.py)
Output: Figures/fig_1.pdf, fig_a3.pdf, fig_a4.pdf
        Tables/tab_a2.csv          Table A2 as in the paper
        Tables/did_regressions.csv all 20 regressions, full precision

Stata -> Python
  reghdfe y x, noab [cluster(hs6)]   ols(d, y, x, cluster="hs6")
  reghdfe y x, a(cs) cluster(hs6)    ols(d, y, x, fe="cs", cluster="hs6"):
                                     drops singletons, demeans within cs,
                                     reghdfe's small-sample correction
  binscatter y x, by(t) [absorb(cs)] binscatter(): 20 bins per period cut
                                     as Stata's xtile does, bin means, OLS
                                     line; absorb() residualizes y and x on
                                     the fixed effects over the whole sample
"""

import sys
from pathlib import Path

import matplotlib
import numpy as np
import pandas as pd

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.ticker import FuncFormatter, MaxNLocator  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from config import FIGURES_DIR, PROCESSED_DIR, TABLES_DIR  # noqa: E402

N_BINS = 20                               # binscatter default
PERIODS = {0: "2015-17", 1: "2017-19"}
GRAY, NAVY = "#a0a0a0", "#1a476f"         # Stata gs10 and navy


# ---------------------------------------------------------------------------
# Data: didplots.do lines 18-45
# ---------------------------------------------------------------------------
def load_data():
    cols = ["cty_iso3", "hs6", "t", "ind9", "dlz_usch", "dlz_chus",
            "dlv_us", "dlv_ch", "dlv_rw"]
    d = pd.read_parquet(PROCESSED_DIR / "data5.parquet", columns=cols)

    # The pre-period regression uses the war-period tariff change:
    # replace dlz = max(dlz) by hs6.
    for v in ["dlz_usch", "dlz_chus"]:
        d[v] = d.groupby("hs6")[v].transform("max")

    d["usch"] = d["cty_iso3"].isin(["USA", "CHN"])
    d["cs"] = d.groupby(["cty_iso3", "ind9"]).ngroup()   # exporter x sector
    return d


# ---------------------------------------------------------------------------
# Regression: reghdfe
# ---------------------------------------------------------------------------
def ols(d, y, x, fe=None, cluster=None):
    """Slope of y on x, as reghdfe reports it. Returns b, se, N."""
    cols = [y, x] + [c for c in (fe, cluster) if c]
    s = d[cols].dropna()
    k = 2                                   # slope and constant
    if fe:
        s = s[s.groupby(fe)[y].transform("size") > 1]       # singletons
        yv = s[y] - s.groupby(fe)[y].transform("mean")
        xv = s[x] - s.groupby(fe)[x].transform("mean")
        k = 1 + s[fe].nunique()             # slope and absorbed levels
    else:
        yv = s[y] - s[y].mean()
        xv = s[x] - s[x].mean()
    yv, xv = yv.to_numpy(float), xv.to_numpy(float)
    n = len(s)
    sxx = xv @ xv
    b = (xv @ yv) / sxx
    e = yv - b * xv
    if cluster:
        score = pd.Series(xv * e).groupby(s[cluster].to_numpy()).sum()
        g = len(score)
        q = g / (g - 1) * (n - 1) / (n - k)
        var = q * (score ** 2).sum() / sxx ** 2
    else:
        var = (e @ e) / (n - k) / sxx
    return b, np.sqrt(var), n


# ---------------------------------------------------------------------------
# Binned scatter plot: binscatter
# ---------------------------------------------------------------------------
def xtile_bins(x, n_bins=N_BINS):
    """Bin numbers as Stata's xtile assigns them (pctile cut points).

    Cut point i: with P = n * i / n_bins, the mean of the P-th and (P+1)-th
    smallest values if P is a whole number, otherwise the ceil(P)-th. A value
    goes to the first bin whose cut point is >= the value; tied cut points
    leave some bins empty.
    """
    v = np.sort(x)
    n = len(v)
    cuts = []
    for i in range(1, n_bins):
        p = n * i / n_bins
        j = int(np.floor(p))
        cuts.append((v[j - 1] + v[j]) / 2 if p == j else v[int(np.ceil(p)) - 1])
    return np.searchsorted(np.array(cuts), x, side="left")


def binscatter(d, y, x, fe=None):
    """Bin means and fitted line for each period, as binscatter by(t).

    The bins are cut once on both periods together and the means taken
    within each period; this reproduces the points in the authors' figures
    exactly (bins cut separately by period do not). The line is the OLS fit
    within each period, drawn across the range of its bin means.
    """
    s = d[[y, x, "t"] + ([fe] if fe else [])].dropna()
    s = s[s["t"].isin(PERIODS)].copy()
    if fe:      # absorb(): residuals on the fixed effects plus the mean
        for v in (y, x):
            s[v] = s[v] - s.groupby(fe)[v].transform("mean") + s[v].mean()
    s["bin"] = xtile_bins(s[x].to_numpy())
    out = {}
    for t in PERIODS:
        g = s[s["t"] == t]
        means = g.groupby("bin")[[x, y]].mean()
        slope, intercept = np.polyfit(g[x], g[y], 1)
        out[t] = (means, slope, intercept, means[x].min(), means[x].max())
    return out


def stata_number(v, _pos=None):
    """Axis labels as Stata writes them: .05 and -.1, not 0.05 and -0.1."""
    text = f"{v:g}"
    return text.replace("0.", ".", 1) if abs(v) < 1 else text


def draw_panel(ax, d, spec, fe, letter):
    pts = binscatter(d, spec["y"], spec["x"], fe)
    for t, color, marker, face in [(0, GRAY, "o", "none"),
                                   (1, NAVY, "o", NAVY)]:
        means, slope, intercept, lo, hi = pts[t]
        ax.scatter(means[spec["x"]], means[spec["y"]], s=14, marker=marker,
                   facecolors=face, edgecolors=color, linewidths=0.9,
                   label=PERIODS[t], zorder=3)
        ax.plot([lo, hi], [intercept + slope * lo, intercept + slope * hi],
                color=color, linewidth=1.1, zorder=2)

    ax.set_title(f"$\\bf{{Panel\\ {letter}}}$\n{spec['title']}",
                 color="#1a2a5a", fontsize=10, pad=20)
    ax.set_xlabel(spec["xlabel"], fontsize=9)
    ax.set_ylabel(spec["ylabel"], fontsize=9)
    for axis in (ax.xaxis, ax.yaxis):
        axis.set_major_locator(MaxNLocator(5, steps=[1, 2, 2.5, 5, 10]))
        axis.set_major_formatter(FuncFormatter(stata_number))
    ax.tick_params(labelsize=8.5)
    ax.grid(True, linestyle=":", linewidth=0.6, color="#bbbbbb")
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    ax.legend(loc="lower center", bbox_to_anchor=(0.5, 1.0), ncol=2,
              frameon=False, fontsize=9, handletextpad=0.2)
    b0, se0 = spec["res"][(0, fe is not None)][:2]
    b1, se1 = spec["res"][(1, fe is not None)][:2]
    ax.text(0, -0.2, f"Pre-period: β={b0:.2f} ({se0:.2f}). "
                     f"Post-period: β={b1:.2f} ({se1:.2f}).",
            transform=ax.transAxes, fontsize=7.5, va="top")


# ---------------------------------------------------------------------------
# The regressions in didplots.do
# ---------------------------------------------------------------------------
# name: (outcome, tariff, sample, plot labels)
REGRESSIONS = {
    "usch":      ("dlv_us", "dlz_usch", "CHN",
                  "China's Export Value to US", "Δln X(US,CH)", "Δ ln T(US,CH)"),
    "chus":      ("dlv_ch", "dlz_chus", "USA",
                  "US Export Value to China", "Δln X(CH,US)", "Δ ln T(CH,US)"),
    "rwus_usch": ("dlv_us", "dlz_usch", "bystanders",
                  "Bystanders' Export Value to US", "Δln X(US,i)",
                  "Δ ln T(US,CH)"),
    "rwch_chus": ("dlv_ch", "dlz_chus", "bystanders",
                  "Bystanders' Export Value to China", "Δln X(CH,i)",
                  "Δ ln T(CH,US)"),
    "rwrw_usch": ("dlv_rw", "dlz_usch", "bystanders",
                  "Bystanders' Export Value to RW", "Δln X(RW,i)",
                  "Δ ln T(US,CH)"),
    "rwrw_chus": ("dlv_rw", "dlz_chus", "bystanders",
                  "Bystanders' Export Value to RW", "Δln X(RW,i)",
                  "Δ ln T(CH,US)"),
}
BYSTANDER = ["rwus_usch", "rwch_chus", "rwrw_usch", "rwrw_chus"]


def run_regressions(d):
    """All 20 regressions of didplots.do; returns specs and a results table."""
    specs, rows = {}, []
    for name, (y, x, sample, title, ylab, xlab) in REGRESSIONS.items():
        sub = d[~d["usch"]] if sample == "bystanders" else \
            d[d["cty_iso3"] == sample]
        bystander = sample == "bystanders"
        res = {}
        for t in (0, 1):
            for fe in ((False, True) if bystander else (False,)):
                b, se, n = ols(sub[sub["t"] == t], y, x,
                               fe="cs" if fe else None,
                               cluster="hs6" if bystander else None)
                res[(t, fe)] = (b, se, n)
                rows.append({"regression": f"{name}_t{t}_fe{int(fe)}",
                             "outcome": y, "tariff": x, "period": t,
                             "exporter_sector_fe": fe, "coef": b, "se": se,
                             "N": n})
        specs[name] = {"data": sub, "y": y, "x": x, "title": title,
                       "ylabel": ylab, "xlabel": xlab, "res": res}
    return specs, pd.DataFrame(rows)


def stars(b, se):
    """esttab stars: * 10%, ** 5%, *** 1% (two-sided, normal)."""
    from scipy.stats import norm
    p = 2 * norm.sf(abs(b / se))
    return "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""


def table_a2(results):
    """Table A2 in the layout of the authors' tab_a2.csv."""
    lines = []
    for t in (0, 1):
        for fe in (False, True):
            r = results[(results["period"] == t)
                        & (results["exporter_sector_fe"] == fe)]
            r = r.set_index(r["regression"].str.rsplit("_t", n=1).str[0])
            r = r.loc[BYSTANDER]
            lines.append(["", "(1)", "(2)", "(3)", "(4)"])
            for tariff, label in [("dlz_usch", "T_USCH"),
                                  ("dlz_chus", "T_CHUS")]:
                coef, se = [label], [""]
                for _, row in r.iterrows():
                    if row["tariff"] == tariff:
                        coef.append(f"{row['coef']:.2f}"
                                    f"{stars(row['coef'], row['se'])}")
                        se.append(f"({row['se']:.2f})")
                    else:
                        coef.append("")
                        se.append("")
                lines += [coef, se]
            lines.append(["Exporter x Sector FE"] + ["Yes" if fe else "No"] * 4)
            lines.append(["N"] + [str(n) for n in r["N"]])
    return pd.DataFrame(lines)


def main():
    d = load_data()
    print(f"data5: {len(d):,} rows")
    specs, results = run_regressions(d)

    FIGURES_DIR.mkdir(exist_ok=True)
    TABLES_DIR.mkdir(exist_ok=True)
    results.to_csv(TABLES_DIR / "did_regressions.csv", index=False,
                   float_format="%.8g")
    table_a2(results).to_csv(TABLES_DIR / "tab_a2.csv", index=False,
                             header=False)

    figures = [("fig_1", BYSTANDER, None, (7.5, 10)),
               ("fig_a3", BYSTANDER, "cs", (7.5, 10)),
               ("fig_a4", ["usch", "chus"], None, (10, 5))]
    for name, panels, fe, size in figures:
        rows = 2 if len(panels) == 4 else 1
        fig, axes = plt.subplots(rows, 2, figsize=size)
        for ax, panel, letter in zip(np.ravel(axes), panels, "ABCD"):
            draw_panel(ax, specs[panel]["data"], specs[panel], fe, letter)
        fig.tight_layout(h_pad=3.5, w_pad=2)
        fig.savefig(FIGURES_DIR / f"{name}.pdf")
        plt.close(fig)

    show = results.copy()
    show["coef"] = show["coef"].round(4)
    show["se"] = show["se"].round(4)
    print(show[["regression", "coef", "se", "N"]].to_string(index=False))
    print(f"\nSaved fig_1, fig_a3, fig_a4.pdf to {FIGURES_DIR.name}/ "
          f"and tab_a2, did_regressions.csv to {TABLES_DIR.name}/")


if __name__ == "__main__":
    main()
