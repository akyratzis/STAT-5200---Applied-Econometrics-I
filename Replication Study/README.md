# Replication: Fajgelbaum et al. (2024)

> Fajgelbaum, P., Goldberg, P., Kennedy, P., Khandelwal, A., and Taglioni, D. (2024).
> The US–China trade war and global reallocations. *AER: Insights* 6(2):295–312.
> <https://doi.org/10.1257/aeri.20230094>

STAT 5200 — Applied Econometrics I, Fall 2026
Apostolos Kyratzis - 13130833

The authors' code is in Stata. This replication rewrites it in Python and
rebuilds the data from the raw sources, rather than starting from the
authors' processed files.

**Status (work in progress)**

| Step | Status |
|---|---|
| 1. Data download | Script ready; full Comtrade download not yet run |
| 2. Data processing: tariffs | **Done.** Identical to the authors' processed files |
| 2. Data processing: trade flows and estimation file | To do |
| 3. Data analysis: Figure 1, Figures A3–A4, Table A2 | To do |

## What is replicated

The paper's average export responses (Section III): for countries other than
the US and China ("bystanders"), the regression

```
Δ ln X = α + β Δ ln T + ε
```

of export growth on the change in the trade-war tariff, by HS6 product,
estimated before the war (2015–2017, a pre-trend test) and during the war
(2017–2019). Standard errors are clustered by product.

| Output | Content |
|---|---|
| Figure 1 | Bystanders' exports to the US, China and the rest of the world against US and Chinese tariffs |
| Figure A3 | Figure 1 with exporter × sector fixed effects |
| Figure A4 | US–China bilateral responses |
| Table A2 | The coefficients, standard errors and sample sizes behind these figures |

Target estimates (paper, Section III):

| Outcome | Tariff | Post-period β | SE | Pre-period β |
|---|---|---|---|---|
| Exports to US | US on China | 0.31 | 0.10 | −0.19 |
| Exports to China | China on US | 0.01 | 0.19 | 0.07 |
| Exports to RW | US on China | 0.20 | 0.08 | −0.14 |
| Exports to RW | China on US | 0.29 | 0.08 | 0.11 |

The main model (Figures 2–4) is not part of this replication.

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
a capital first letter.

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

2. **The authors' replication package** (about 18 GB, needed for two large
   files in step 1). Download it from openICPSR,
   <https://doi.org/10.3886/E194689V1> (free sign-in), and unzip it to
   `~/Downloads/GTW_replication`. To keep it elsewhere, set the environment
   variable `GTW_REPLICATION_DIR` to its folder.

All commands below are run from the `Python/` folder with
`~/.venvs/stat5200/bin/python`.

## 1. Data download

Three sources. Only the small files are stored in this repository.

| Data | Source | Where it is kept | In this repository? |
|---|---|---|---|
| UN Comtrade trade flows, HS 2012, 2014–2019 (957 files, ~14 GB) | **Downloaded fresh** with `comtrade_download.py` | `~/Downloads/Comtrade_raw/` | No (size, and Comtrade terms). The catalogue and download log are, in `Data/Raw/Comtrade/` |
| US Census monthly HS10 imports and exports, with US tariffs (2 files, 13 GB) | Authors' package, `data/raw/census_trade/` | Read in place from the package | No (size) |
| Small raw files: China's tariff lists, crosswalks, country codes (7 files, 49 MB) | Authors' package, `data/raw/` | `Data/Raw/` | Yes |

The authors could not redistribute the raw Comtrade files (their
`data/raw/comtrade/` folder is empty), so the trade flows are downloaded again.

### 1a. Small raw files from the authors' package

Already in `Data/Raw/`, copied unchanged (checked by SHA-256):

| Folder | File | Content |
|---|---|---|
| `AKW/` | `china_imports_from_usa.dta` | China's 2017 imports from the US by HS8 (weights for China's tariffs) |
| `Bown_etal/` | `CHN_TR_onUS_HS10.dta` | China's retaliatory tariffs by product, Bown et al. (2019 exemptions) |
| `Retaliatory_tariffs/` | `retaliatory_tariffs.xlsx`, `retaliatory_tariffs_2019.xlsx` | China's retaliation lists: HS8 product, tariff, effective date |
| `Crosswalk/Crosswalk_consistent_HS6/` | `CompleteCorrelationsOfHS-SITC-BEC_20170606.xlsx` | HS 2017 → HS 2012 product codes |
| `Crosswalk/` | `hs6_broad_sectors.dta` | HS6 product → broad sector |
| `Wb_country_groups/` | `iso_codes.csv` | Comtrade country codes → ISO3 codes and names |

Only the files the replication uses were copied.

### 1b. US Census files

Nothing to do once the authors' package is unzipped (Setup, step 2). The
scripts read `m_flow_hs10_fm.dta` and `x_flow_hs10_fm.dta` from its
`data/raw/census_trade/` folder. Note that the import file is not a pure
Census extract: the authors merged the US tariff schedules into it.

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

4. **Download everything** (about 14 GB; roughly 1–2 hours on a normal
   connection):

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
revises its data, so these records identify exactly which version was used.
About a fifth of the files were republished after the authors' download in
2022, so the rebuilt trade flows are expected to be very close to, but not
identical with, the authors'.

## 2. Data processing

Python ports of the authors' data-processing do-files, one script per
do-file, each saving one dataset to `Data/Processed/` (Parquet format). Run
them in this order:

| # | Script (`Python/Data Processing/`) | Ports | Inputs | Output (`Data/Processed/`) | Status |
|---|---|---|---|---|---|
| 1 | `china_weight.py` | `china_weight.do` | Census imports and exports | `china_weight_hs6.parquet`: each HS10 product's 2015–17 share of US trade with China within its HS6 | Done |
| 2 | `z_usch.py` | `z_usch.do` | Census imports, step 1, HS crosswalk | `z_usch_w.parquet`: US tariffs on China, by HS6 and period; regressor `dlz_usch` | Done |
| 3 | `z_chus.py` | `z_chus.do` | Retaliation lists, Bown et al., AKW, HS crosswalk | `z_chus_w.parquet`: China's tariffs on the US, by HS6 and period; regressor `dlz_chus` | Done |
| 4 | `comtrade.py` | `comtrade.do` | Comtrade download, country codes | Trade flows by reporter, partner, HS6 and year | To do |
| 5 | `build.py` | `build.do` (up to `data5`) | Steps 2–4, sector crosswalk, country codes | `data5`: the estimation file | To do |

`tariff_common.py` holds two steps shared by `z_usch.py` and `z_chus.py`:
the HS 2017 → HS 2012 conversion and the tariff level and log change by
period.

```bash
~/.venvs/stat5200/bin/python "Data Processing/china_weight.py"
~/.venvs/stat5200/bin/python "Data Processing/z_usch.py"
~/.venvs/stat5200/bin/python "Data Processing/z_chus.py"
```

Each takes about half a minute; steps 1 and 2 spend most of it reading the
Census files.

**Periods.** Years are grouped into two-year periods: t = −1 (2014–15),
t = 0 (2016–17) and t = 1 (2018–19). The tariff change `dlz` is the change in
log(1 + tariff) between periods; it is zero before the war.

**Verification.** Steps 1–3 were compared row by row with the authors'
processed files (`china_weight_hs6.dta`, `z_usch_w.dta`, `z_chus_w.dta`):
same rows, and every column equal within 3e-8 (the precision of Stata's
4-byte floats). The one exception is described in the notes below; it does
not affect any regression.

## 3. Data analysis and figures

To do. The scripts in `Python/Data Analysis/` will port the authors'
`didplots.do`, reading the estimation file `data5` from step 2. Every
regression has one outcome and one tariff:

| Variable | Meaning | Built from |
|---|---|---|
| `dlv_us`, `dlv_ch`, `dlv_rw` | Log change in exporter i's exports of product h to the US, China, rest of world | Comtrade (step 2, scripts 4–5) |
| `dlz_usch` | Change in log(1 + US tariff on China) | `z_usch_w` (step 2, script 2) |
| `dlz_chus` | Change in log(1 + China's tariff on the US) | `z_chus_w` (step 2, script 3) |
| `cty_iso3` × `ind9` | Exporter × sector fixed effects (Figure A3) | Country codes, sector crosswalk |
| `hs6` | Clusters for standard errors | — |

Sample: the top 50 exporters, excluding the US, China and 14 oil exporters.
Outputs will be saved to `Figures/` and `Tables/`.

## Notes on the authors' replication package

- **Missing raw data.** `data/raw/comtrade/` is empty, so the trade flows
  cannot be rebuilt from the package alone (hence step 1c).
- **Path error.** `z_chus.do` reads `raw/china_trade_hs8/china_imports_from_usa.dta`,
  but the package ships this file in `raw/AKW/`, so the do-file does not run
  as delivered. Our `config.py` points to the right folder.
- **Weighted log changes.** In the authors' `z_usch_w.dta` and `z_chus_w.dta`,
  `dlz_usch_w` and `dlz_chus_w` are copies of the unweighted `dlz_usch` and
  `dlz_chus`, and do not follow from the files' own `z_usch_w` and `z_chus_w`
  columns as the code computes them. They were probably saved by an earlier
  version of the code. Our scripts follow the code as written. No analysis
  script uses these two variables.
- **Excel dates.** `z_chus.do` parses the retaliation lists' effective dates
  as text, which depends on the cell formats. Our script reads the dates
  directly; the result matches the authors' file exactly.
- **Values only.** `build.do` keeps only trade values when it aggregates
  Comtrade, discarding quantities.
