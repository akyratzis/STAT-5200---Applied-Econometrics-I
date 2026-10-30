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

Scripts are numbered and run in order from inside `R/`:

```r
source("01_build_comtrade.R")   # raw extract  -> data/processed
source("02_build_tariffs.R")    # tariff files -> data/processed
source("03_estimate.R")         # regressions  -> output, figures
```

Each script starts with `rm(list = ls())` and sets a seed where anything is
random, so results are reproducible from a clean session.

## Extension

The project extends this replication by decomposing export value into quantity
and unit value, Δ ln X = Δ ln Q + Δ ln P, to test the downward-sloping supply
mechanism directly rather than inferring it from values alone. See the
proposal in `Homework Assignments/Homework 4/`.

## Status

Scaffold only — no data pulled and no scripts written yet.
