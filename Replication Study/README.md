# Replication: Fajgelbaum et al. (2024)

> Fajgelbaum, P., Goldberg, P., Kennedy, P., Khandelwal, A., and Taglioni, D. (2024).
> The US–China trade war and global reallocations. *AER: Insights* 6(2):295–312.
> <https://doi.org/10.1257/aeri.20230094>

STAT 5200 — Applied Econometrics I, Fall 2026
Apostolos Kyratzis - 13130833

The authors' code is in Stata and their package ships processed data. This
replication rewrites the code in Python and rebuilds every dataset the
results depend on from raw data: the trade-war tariffs from the raw tariff
schedules, and the trade flows from a fresh download of UN Comtrade.

## What is replicated

The paper's average export responses (Section III). For countries other than
the US and China ("bystanders"), export growth of an HS6 product is regressed
on the change in the trade-war tariff on that product:

```
Δ ln X = α + β Δ ln T + ε
```

separately before the war (2015–17, a test for pre-existing trends) and
during the war (2017–19). Standard errors are clustered by product.

| Output | File | Content |
|---|---|---|
| Figure 1 | `Figures/fig_1.pdf` | Bystanders' exports to the US, China and the rest of the world (RW) against US and Chinese tariffs |
| Figure A3 | `Figures/fig_a3.pdf` | China's exports to the US and US exports to China |
| Figure A4 | `Figures/fig_a4.pdf` | Figure 1 with exporter × sector fixed effects |
| Table A2 | `Tables/tab_a2.csv` | Coefficients, standard errors and sample sizes behind Figures 1 and A4 |
| — | `Tables/did_regressions.csv` | All 20 regressions at full precision |

The main model (Figures 2–4) is not part of this replication.

## Results

Table A2, bystander regressions without fixed effects (standard errors in
parentheses; \* 10%, \*\* 5%, \*\*\* 1%):

| Outcome | Tariff | Period | Paper | This replication |
|---|---|---|---|---|
| Exports to US | US on China | 2017–19 | 0.31\*\*\* (0.10) | 0.31\*\*\* (0.10) |
| | | 2015–17 | −0.19\* (0.10) | −0.19\* (0.10) |
| Exports to China | China on US | 2017–19 | 0.01 (0.19) | 0.05 (0.19) |
| | | 2015–17 | 0.07 (0.18) | 0.07 (0.18) |
| Exports to RW | US on China | 2017–19 | 0.20\*\*\* (0.08) | 0.22\*\*\* (0.08) |
| | | 2015–17 | −0.14\* (0.08) | −0.16\*\* (0.08) |
| Exports to RW | China on US | 2017–19 | 0.29\*\*\* (0.08) | 0.25\*\*\* (0.08) |
| | | 2015–17 | 0.11 (0.08) | 0.13\* (0.08) |

- **Exports to the US** are reproduced exactly, as is China's export
  response to US tariffs (Figure A3, Panel A): the US import data has not
  been revised since the authors' download. US exports to China (Figure A3,
  Panel B) change slightly, from −2.98 to −3.00 (0.42).
- **Exports to China and to the rest of the world** differ by up to 0.05.
  Comtrade has revised part of its data since the authors downloaded it
  (about a fifth of the files were republished after 2022, and some
  countries reported their data later), and the rest-of-world outcome adds
  up the imports of about 150 countries, so small revisions in any of them
  move it.
- **The war-period effects hold:** bystanders' exports to the US and to the
  rest of the world rise significantly with the tariffs.
- **The pre-trends are somewhat stronger with today's data:** for exports to
  the rest of the world, the pre-war coefficients are larger in absolute
  value, and against China's tariffs the coefficient becomes significant at
  10% (0.13). The paper's design relies on these pre-war coefficients being
  close to zero.

Before the full rebuild, each step was checked against the authors'
processed files: the rebuilt tariff files match theirs within the precision
of Stata's 4-byte floats; `build.py` run on the authors' trade file
reproduces their `data5` exactly (same 765,835 rows); and the analysis run
on the authors' `data5` reproduces all 20 coefficients, standard errors and
sample sizes in their Stata log and every cell of their Table A2.

## Folder layout

```
Replication Study/
├── README.md
├── requirements.txt             pinned Python packages
├── Paper - The US-China ... .pdf
├── Python/
│   ├── config.py                all file locations
│   ├── comtrade_download.py     step 1: downloads the UN Comtrade data
│   ├── Data Processing/         step 2: raw data -> Data/Processed
│   └── Data Analysis/           step 3: Data/Processed -> Figures, Tables
├── Data/
│   ├── Raw/                     raw inputs (see step 1)
│   └── Processed/               datasets built in step 2
├── Figures/
└── Tables/
```

Folder names under `Data/Raw/` follow the authors' `data/raw/` folders, with
a capital first letter. Every Python script ports one of the authors'
do-files and says which at the top.

## Setup (once)

1. **Python 3.12 and the pinned packages.** The environment lives outside this
   folder, because the folder is synced by iCloud. With
   [uv](https://docs.astral.sh/uv/):

   ```bash
   uv python install 3.12
   uv venv --python 3.12 ~/.venvs/stat5200
   VIRTUAL_ENV=~/.venvs/stat5200 uv pip install -r requirements.txt
   ```

   Any Python 3.12 works instead: `python3.12 -m venv ~/.venvs/stat5200`, then
   `~/.venvs/stat5200/bin/python -m pip install -r requirements.txt`.

2. **The authors' replication package** (about 18 GB; only two of its files
   are used, in step 1b). Download it from openICPSR,
   <https://doi.org/10.3886/E194689V1> (free sign-in), and unzip it to
   `~/Downloads/GTW_replication`. To keep it elsewhere, set the environment
   variable `GTW_REPLICATION_DIR` to its folder.

All commands below are run from the `Python/` folder.

## 1. Data download

| Data | Source | Where it is kept | In this repository? |
|---|---|---|---|
| UN Comtrade trade flows, HS 2012, 2014–2019 (957 files, 14.6 GB) | **Downloaded fresh** with `comtrade_download.py` | `~/Downloads/Comtrade_raw/` | No (size, and Comtrade terms). The catalogue and download log are, in `Data/Raw/Comtrade/` |
| US Census monthly HS10 imports and exports, with US tariffs (2 files, 13 GB) | Authors' package, `data/raw/census_trade/` | Read in place from the package | No (size) |
| Small raw files: China's tariff lists, crosswalks, country codes (7 files, 49 MB) | Authors' package, `data/raw/` | `Data/Raw/` | Yes |

The authors could not redistribute the raw Comtrade files (their
`data/raw/comtrade/` folder is empty), so the trade flows are downloaded again.

### 1a. Small raw files from the authors' package

Already in `Data/Raw/`, copied unchanged:

| Folder | File | Content |
|---|---|---|
| `AKW/` | `china_imports_from_usa.dta` | China's 2017 imports from the US by HS8 (weights for China's tariffs) |
| `Bown_etal/` | `CHN_TR_onUS_HS10.dta` | China's retaliatory tariffs by product, Bown et al. (2019 exemptions) |
| `Retaliatory_tariffs/` | `retaliatory_tariffs.xlsx`, `retaliatory_tariffs_2019.xlsx` | China's retaliation lists: HS8 product, tariff, effective date |
| `Crosswalk/Crosswalk_consistent_HS6/` | `CompleteCorrelationsOfHS-SITC-BEC_20170606.xlsx` | HS 2017 → HS 2012 product codes |
| `Crosswalk/` | `hs6_broad_sectors.dta` | HS6 product → broad sector |
| `Wb_country_groups/` | `iso_codes.csv` | Comtrade country codes → ISO3 codes and names |

### 1b. US Census files

Nothing to do once the authors' package is unzipped (Setup, step 2): the
scripts read `m_flow_hs10_fm.dta` and `x_flow_hs10_fm.dta` from its
`data/raw/census_trade/` folder. The import file is not a pure Census
extract: the authors merged the US tariff schedules into it.

### 1c. UN Comtrade data

The HS 2012 version of the data for 2017–2019 is published only through the
**premium Bulk API** (most countries reported in HS 2017 from 2017, and
Comtrade's conversion to HS 2012 is available only in bulk "Plus" files).
Premium access is available through Penn.

1. **Get an API key.** Sign in to UN Comtrade (<https://comtradeplus.un.org>)
   through your institution's premium access, open the API portal
   (<https://comtradedeveloper.un.org>), and copy the subscription key of the
   premium subscription from your profile.
2. **Store the key outside the repository**, never in a script. On a Mac,
   add this line to the file `~/.zshenv` (create it if needed), then make the
   file readable only by you and open a new terminal:

   ```bash
   export COMTRADE_API_KEY=your_key
   ```

   ```bash
   chmod 600 ~/.zshenv
   ```

   The script reads the key from this environment variable, sends it only to
   `comtradeapi.un.org`, and never prints or saves it.
3. **Check access** (lists the files, downloads nothing):

   ```bash
   ~/.venvs/stat5200/bin/python comtrade_download.py --catalogue-only
   ```

4. **Download everything** (14.6 GB; about 75 minutes on a fast connection):

   ```bash
   ~/.venvs/stat5200/bin/python comtrade_download.py
   ```

   The files go to `~/Downloads/Comtrade_raw/<year>/` (to use another folder,
   set `COMTRADE_DATA_DIR`). The run can be stopped with Ctrl+C and resumed
   with the same command: finished files are skipped. Each file is checked to
   be a complete gzip file before it is kept.

The script writes `Data/Raw/Comtrade/catalogue.csv` (every file available,
with publication dates) and `Data/Raw/Comtrade/download_log.csv` (when each
file was downloaded, its publication date, size and SHA-256). Comtrade
revises its data, so these records identify exactly which version was used:
the files used here were downloaded on 15 November 2026 (UTC).

## 2. Data processing

Python ports of the authors' data-processing do-files. Each script saves its
dataset to `Data/Processed/` (Parquet format). Run them in this order:

| # | Script (`Python/Data Processing/`) | Ports | Inputs | Output (`Data/Processed/`) | Time |
|---|---|---|---|---|---|
| 1 | `china_weight.py` | `china_weight.do` | Census imports and exports | `china_weight_hs6.parquet`: each HS10 product's 2015–17 share of US trade with China within its HS6 | 25 s |
| 2 | `z_usch.py` | `z_usch.do` | Census imports, step 1, HS crosswalk | `z_usch_w.parquet`: US tariffs on China by HS6 and period | 15 s |
| 3 | `z_chus.py` | `z_chus.do` | Retaliation lists, Bown et al., AKW, HS crosswalk | `z_chus_w.parquet`: China's tariffs on the US by HS6 and period | 5 s |
| 4 | `comtrade.py` | `comtrade.do` | Comtrade download, country codes | `global_trade_hs6_ct_consistent_hs12_<year>.parquet`: bilateral trade by HS6, one file per year | 6 min |
| 5 | `build.py` | `build.do` (up to `data5`) | Steps 2–4, sector crosswalk, country codes | `data5.parquet`: the estimation file; `top50.parquet`: the 50 exporters in the sample | 20 s |

```bash
~/.venvs/stat5200/bin/python "Data Processing/china_weight.py"
~/.venvs/stat5200/bin/python "Data Processing/z_usch.py"
~/.venvs/stat5200/bin/python "Data Processing/z_chus.py"
~/.venvs/stat5200/bin/python "Data Processing/comtrade.py"
~/.venvs/stat5200/bin/python "Data Processing/build.py"
```

`tariff_common.py` holds two steps shared by `z_usch.py` and `z_chus.py`
(the HS 2017 → HS 2012 conversion, and tariff levels and log changes by
period); it is not run on its own.

The yearly trade files (about 270 MB each) exceed GitHub's file limit and are
not in the repository; `comtrade.py` rebuilds them. `data5.parquet` (about
70 MB) is not included either: it exceeds Overleaf's 50 MB limit, which would
block the repository's Overleaf sync, and `build.py` rebuilds it. All other
processed files are included.

**Periods.** Years are grouped into two-year periods: t = −1 (2014–15),
t = 0 (2016–17) and t = 1 (2018–19). Tariff changes `dlz` and export changes
`dlv` are changes in logs between consecutive periods.

**Trade flows (`comtrade.py`).** The Comtrade "Plus" files hold total trade
and the same trade broken down by customs procedure and transport mode. The
script keeps the totals (all procedures, all modes, imports and exports,
6-digit products), drops the regional aggregates EU and ASEAN, and uses the
authors' country codes (only Italy differs: 380 in the Plus files, 381 in
the authors' data). Values are in millions of US dollars. As in the paper,
exports are measured from the importers' records.

**Estimation file (`build.py`).** For each exporter, HS6 product and period:
exports to the US, to China and to the rest of the world, their log changes,
and the two tariffs; restricted to the top 50 exporters by total exports,
excluding 14 oil exporters. Columns of the authors' `data5` that no
replicated result uses are not built: China's tariffs on other countries
(`z_chrw`), US tariffs by country (`z_usi`), export-share weights (`sw_*`)
and four extra destinations (India, Hong Kong and two combinations).

## 3. Data analysis and figures

```bash
~/.venvs/stat5200/bin/python "Data Analysis/didplots.py"
```

`didplots.py` ports the authors' `didplots.do` (5 seconds). It reads
`data5.parquet` and writes the figures and tables listed under *What is
replicated*. Every regression has one outcome and one tariff:

| Variable | Meaning |
|---|---|
| `dlv_us`, `dlv_ch`, `dlv_rw` | Log change in exporter i's exports of product h to the US, China, rest of world |
| `dlz_usch` | Change in log(1 + US tariff on China) |
| `dlz_chus` | Change in log(1 + China's tariff on the US) |
| `cty_iso3` × `ind9` | Exporter × sector fixed effects (Figure A4) |
| `hs6` | Clusters for standard errors |

In the pre-war regressions, the tariff variable is the product's war-period
tariff change, so the coefficient tests whether products later hit by
tariffs were already growing differently.

| Stata (`didplots.do`) | Python (`didplots.py`) |
|---|---|
| `reghdfe y x, noab cluster(hs6)` | `ols(d, y, x, cluster="hs6")` |
| `reghdfe y x, a(cs) cluster(hs6)` | `ols(d, y, x, fe="cs", cluster="hs6")`: drops singletons, demeans within exporter × sector, applies reghdfe's small-sample correction |
| `binscatter y x, by(t) [absorb(cs)]` | `binscatter()`: 20 bins cut as Stata's `xtile` does, bin means by period, OLS line |

The figures are numbered as in the paper, which cites Figure A.3 for US–China
bilateral trade and Figure A.4 for the fixed-effects robustness check. The
authors' package saves Figure A4 as `appendix/fig_a2.pdf` and Figure A3 as
`appendix/fig_a3.pdf`.

## Notes on the authors' replication package

- **Missing raw data.** `data/raw/comtrade/` is empty, so the trade flows
  cannot be rebuilt from the package alone (hence step 1c).
- **Path error.** `z_chus.do` reads `raw/china_trade_hs8/china_imports_from_usa.dta`,
  but the package ships this file in `raw/AKW/`, so the do-file does not run
  as delivered. Our `config.py` points to the right folder.
- **Weighted log changes.** In the authors' `z_usch_w.dta` and `z_chus_w.dta`,
  `dlz_usch_w` and `dlz_chus_w` are copies of the unweighted `dlz_usch` and
  `dlz_chus`, and do not follow from the files' own `z_usch_w` and `z_chus_w`
  columns as the code computes them; they were probably saved by an earlier
  version of the code. Our scripts follow the code as written. No replicated
  result uses these two variables.
- **Excel dates.** `z_chus.do` parses the retaliation lists' effective dates
  as text, which depends on the cell formats. Our script reads the dates
  directly.
- **Figure numbering.** See section 3.
- **Values only.** `build.do` keeps only trade values when it aggregates
  Comtrade, discarding quantities.
