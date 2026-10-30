# Replication: Fajgelbaum et al. (2024)

Replication of the average export responses in Section III of:

> Fajgelbaum, P., Goldberg, P., Kennedy, P., Khandelwal, A., and Taglioni, D. (2024).
> The US–China trade war and global reallocations. *AER: Insights* 6(2):295–312.
> <https://doi.org/10.1257/aeri.20230094>

STAT 5200 — Applied Econometrics I, Fall 2026
Apostolos Kyratzis - 13130833

## What is being replicated

The regression

```
Δ ln X = α + β Δ ln T + ε
```

estimated separately for bystander exports to the United States, to China, and
to the rest of the world, against the US and Chinese trade-war tariffs. This
reproduces the paper's Figure 1 and Appendix Table A.2.

Target estimates (paper's Section III):

| Outcome | Tariff | Post-period β | SE | Pre-period β |
|---|---|---|---|---|
| Exports to US | US on China | 0.31 | 0.10 | −0.19 |
| Exports to China | China on US | 0.01 | 0.19 | 0.07 |
| Exports to RW | US on China | 0.20 | 0.08 | −0.14 |
| Exports to RW | China on US | 0.29 | 0.08 | 0.11 |

Standard errors are clustered by product. The pre-period column (2015–2017)
is the pre-trend against which the post-period (2017–2019) is read.

## Layout

```
R/                 analysis scripts, run in numbered order
data/raw/          downloaded source files (not tracked — see Data below)
data/processed/    analysis-ready files built by the scripts
figures/           generated figures
output/            captured console output
paper/             the paper being replicated
```

## Data

Not tracked in git: the raw extracts are large and are redistributable only
from their original sources. Rebuild them by running the scripts in `R/` in
order, or download directly:

- **UN Comtrade** — bilateral trade in 5,203 HS6 products, aggregated into
  24-month intervals (2014/2015, 2016/2017, 2018/2019). Public API at
  <https://comtradeplus.un.org>.
- **Trade-war tariffs** — US tariffs on China, Chinese tariffs on the US, and
  US tariffs on third countries, from the replication package of Fajgelbaum et
  al. (2020), extended through end-2019.
- **China MFN tariffs** on non-US partners, from Bown, Jung and Zhang (2019).

The sample covers the top exporting countries excluding oil exporters, with
nine sectors: agriculture, apparel, chemicals, materials, machinery, metals,
minerals, transport, miscellaneous.

## Running it

First, put your Census API key in `~/.Renviron` — **outside this repository** —
and restart R:

```
CENSUS_API_KEY=your_key_here
```

Free, instant signup at <https://api.census.gov/data/key_signup.html>. The
scripts read it with `Sys.getenv()` and stop immediately if it is missing;
nothing secret is ever written into the repo.

Install `sandwich` if you do not have it (needed for clustered standard
errors): `install.packages("sandwich")`.

Then run in order from inside `R/`:

```r
source("01_census_pull.R")      # Census API -> data/raw/census, data/processed
```

`01_census_pull.R` caches one CSV per flow, heading and month, so a month
already on disk is never re-requested. The run can be interrupted and resumed
at no cost. Each script starts with `rm(list = ls())`.

## The export-control extension

HS 8486 is machines for manufacturing semiconductor devices — seven HS10 lines,
$15.5bn of US exports in 2019. China was the second-largest destination at
$3.6bn, behind Taiwan and ahead of Korea. The October 2022 export controls hit
exactly this, which gives a sharp dated shock on a product set the tariff
schedule already isolates, with no discretionary "AI basket" to define.

Treated: HS 8486 to China. Controls: the same equipment to Taiwan, Korea, Japan
and Singapore, which were not restricted, and other headings to China. Monthly
data supports an event study with leads and lags, so pre-trends are tested
rather than assumed.

Known problems, to be addressed rather than ignored:

- **Zeros.** A control can drive flows to zero and logs then break. Work at the
  heading level where flows stay positive, and report levels and shares next to
  logs.
- **Anticipation.** Stockpiling before October 2022 will appear as a pre-trend.
  That is a result, not only a nuisance.
- **Quantity coverage** is about 65% for HS 8486, weaker than elsewhere, so
  lean on values rather than unit values for this heading.
- **Confounds:** the CHIPS Act (August 2022), COVID supply chains, and the
  Netherlands and Japan joining controls during 2023.
- **Destination misattribution.** Census records declared country of ultimate
  destination, so transshipment is measured imperfectly — which is both a
  limitation and part of what the design is trying to detect.

## Extension

The project extends this replication by decomposing export value into quantity
and unit value, Δ ln X = Δ ln Q + Δ ln P, to test the downward-sloping supply
mechanism directly rather than inferring it from values alone. See the
proposal in `Homework Assignments/Homework 4/`.

## Notes on the Fajgelbaum replication package

- `data/processed/data5.dta` is the estimation file and is enough on its own to
  reproduce Figure 1 and Appendix Table A.2.
- The headline regression is `reghdfe ... , noab cluster(hs6)`. `noab` means no
  absorbed fixed effects, so it is plain OLS with product-clustered standard
  errors — `lm()` plus `sandwich::vcovCL(cluster = ~hs6)` in R.
- `results/appendix/tab_a2.csv` holds the target coefficients and sample sizes,
  so the replication is checkable to the decimal.
- `build.do` line 44 collapses on value alone, discarding quantity and net
  weight at the first aggregation. That is why the paper never uses prices. The
  source file `global_trade_hs6_ct_consistent_hs12.dta` still has both, with 97%
  net-weight and 91% quantity coverage on positive export flows.
- `data/raw/comtrade/` **is empty** in the distributed package: the per-year
  source files are not included, only the built panel. Extending beyond 2019
  therefore requires a fresh pull.

## Status

Census pull scripts written; no data fetched yet. The Fajgelbaum replication
itself has not been started.
