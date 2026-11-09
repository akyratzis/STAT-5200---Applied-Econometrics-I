# HW5 Q4 simulations

Run these commands from the `Homework 5` directory. The scripts use base R and
the `sandwich` package for the HC0--HC3 calculations in Lab 3.

```r
install.packages("sandwich")  # once, if not already installed
```

```sh
Rscript R/q4_coverage_rate.R > Output/q4_coverage_rate.txt
Rscript R/q4_bootstrap_coverage.R 500
Rscript R/q4_bootstrap_coverage.R 10000
```

- `q4_coverage_rate.R` reproduces (a)--(f), using seed 1, N=100, and M=10,000.
  It saves all 10,000 heteroskedastic datasets and the conventional/HC coverage
  indicators to `Output/q4_heteroskedastic_samples.rds` without changing the
  sequence of random draws or earlier results.
- `q4_bootstrap_methods.R` follows Lab 4's matrix OLS code for pairs, residual,
  and wild bootstrap and leave-one-out jackknife standard errors.
- `q4_bootstrap_coverage.R` uses seed 2 for resampling, B=1,000 for each of the
  three bootstrap methods, and N=100 leave-one-out fits for the jackknife.
  Intervals use the original OLS slope plus/minus 1.96 times the relevant SE.
  Passing M=500 uses the first 500 cached datasets; M=10,000 uses all of them.

The bootstrap script saves a checkpoint every 25 datasets. Running it again
resumes from that checkpoint, preserving the random-number stream. It checks
that the dataset cache, bootstrap-method code, B, and seed match before resuming.
The generated dataset cache and checkpoint are ignored by Git. Delete a stale
checkpoint explicitly before intentionally changing the resampling procedure.

Results are written to `Output/q4_bootstrap_coverage_M500.txt` and
`Output/q4_bootstrap_coverage_M10000.txt`. The script also generates
`Output/q4_bootstrap_table_M10000.tex`, which the report includes directly.
The text output files also show conventional and
HC coverage on the same datasets for verification; the report's part (g) table
focuses on the four requested resampling methods. `Monte_Carlo_SE_pp` measures
simulation uncertainty in the coverage estimate, in percentage points; it is
different from the coefficient SE used to construct each confidence interval.
