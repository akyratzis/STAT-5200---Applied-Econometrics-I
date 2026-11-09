# HW6 Q3–Q4

Run with base R, from any working directory:

```sh
Rscript '/absolute/path/to/Homework 6/R/q3_q4_iv.R'
```

From the course repository root:

```sh
Rscript 'Homework Assignments/Homework 6/R/q3_q4_iv.R'
```

The script resolves paths relative to its own location, reads the bundled
`Data/mroz.csv`, and writes to `Output/`. It does not install packages, access
the network, change the working directory, or modify the input data.

## Sample and methods

- Start with 753 women; retain 428 working women with positive wages and
  complete data for all specifications, using one common sample.
- Construct natural log wage and squared experience explicitly.
- Fit OLS, one-instrument IV, and three-instrument 2SLS. Include the intercept
  and exogenous controls in every instrument matrix.
- Use QR projections instead of constructing the full projection matrix.
  Calculate conventional and HC1 standard errors using structural residuals.
- Use `qnorm(0.975)` for all asymptotic 95% confidence intervals. The primary
  report comparison uses conventional SEs; HC1 intervals are also saved.
- Reproduce Q4 with two `lm()` calls and compare every coefficient and SE.
- Calculate the partial first-stage F test for the three excluded instruments.
  This is the conventional homoscedastic F statistic, not a robust diagnostic.

## Outputs and checks

- `q3_education_comparison.csv`: coefficients, both SE types, confidence
  intervals, and conventional interval widths.
- `q4_two_stage_comparison.csv`: all coefficients and naive/correct SEs.
- `q3_q4_results.txt`: readable results, source/input checksum, numerical
  validation results, and R session information.

Checks require the 428-observation sample, reproduce Lab 7's education
coefficients/three-instrument SEs and first-stage F to rounding tolerance,
verify that the general IV implementation reduces to `lm()` when Z = X,
and verify coefficient equality between manual two-stage `lm()` and 2SLS.
Tiny differences from printed Lab 7 values reflect rounding/data precision.

The report embeds the numerical results to remain self-contained when uploaded
to Overleaf. If inputs or specifications change, rerun this script and update
those embedded numbers together. Q1 and Q5 remain unanswered.
