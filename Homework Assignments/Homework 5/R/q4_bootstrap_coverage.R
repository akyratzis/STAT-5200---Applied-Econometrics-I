# Run from Homework 5: Rscript R/q4_bootstrap_coverage.R 10000
# Pass 500 for the pilot; the saved checkpoint resumes completed datasets.
source(file.path("R", "q4_bootstrap_methods.R"));
args = commandArgs(trailingOnly = TRUE);
M_boot = if (length(args)) as.integer(args[1]) else 10000L;
B = 1000L;
bootstrap_seed = 2L;
cache_path = file.path("Output", "q4_heteroskedastic_samples.rds");
checkpoint_path = file.path("Output", "q4_bootstrap_checkpoint.rds");
if (!file.exists(cache_path)) stop("Run R/q4_coverage_rate.R first.");
cache = readRDS(cache_path);
stopifnot(length(M_boot) == 1, !is.na(M_boot), M_boot >= 1,
          M_boot <= cache$M, cache$N == 100, cache$error_df == 10);
methods = c("Pairs", "Residual", "Wild", "Jackknife");
cache_hash = unname(tools::md5sum(cache_path));
method_hash = unname(tools::md5sum(file.path("R", "q4_bootstrap_methods.R")));

if (file.exists(checkpoint_path)){
  state = readRDS(checkpoint_path);
  stopifnot(identical(state$cache_hash, cache_hash),
            identical(state$method_hash, method_hash),
            state$B == B, state$seed == bootstrap_seed);
  assign(".Random.seed", state$rng, envir = .GlobalEnv);
} else {
  set.seed(bootstrap_seed);
  state = list(completed = 0L, B = B, seed = bootstrap_seed,
    cache_hash = cache_hash, method_hash = method_hash,
    hits = matrix(NA, cache$M, 4, dimnames = list(NULL, methods)),
    se = matrix(NA, cache$M, 4, dimnames = list(NULL, methods)));
}

started = proc.time()[[3]];
if (state$completed < M_boot){
  for (m in seq.int(state$completed + 1L, M_boot)){
    dat = cache$samples[[m]];
    y = dat[, "y", drop = FALSE];
    x = dat[, "x"];
    X = cbind(1, x, x^2);
    result = lab4_resampling_se(y, X, B);
    se_b1 = result$se[2, ];
    lower = result$coefficients[2] - 1.96*se_b1;
    upper = result$coefficients[2] + 1.96*se_b1;
    state$se[m, ] = se_b1;
    state$hits[m, ] = as.numeric(lower <= cache$beta[2] &
                                cache$beta[2] <= upper);
    state$completed = m;
    if (m %% 25L == 0L || m == M_boot){
      state$rng = .Random.seed;
      saveRDS(state, checkpoint_path);
      cat(sprintf("Completed %d/%d datasets; elapsed %.1f seconds\n",
                  m, M_boot, proc.time()[[3]] - started));
      flush.console();
    }
  }
}

rows = seq_len(M_boot);
hits = cbind(Conventional = cache$conventional_hits[rows],
             cache$hc_hits[rows, , drop = FALSE],
             state$hits[rows, , drop = FALSE]);
stopifnot(!anyNA(hits));
coverage = colMeans(hits);
tab = data.frame(Method = colnames(hits),
  Covered = as.integer(colSums(hits)), M = M_boot,
  Coverage_percent = 100*coverage,
  Monte_Carlo_SE_pp = round(100*sqrt(coverage*(1-coverage)/M_boot), 2),
  row.names = NULL);
cat(sprintf("\nN = %d; M = %d; B = %d; bootstrap seed = %d\n",
            cache$N, M_boot, B, bootstrap_seed));
print(tab, row.names = FALSE);
output_path = file.path("Output", sprintf("q4_bootstrap_coverage_M%d.txt", M_boot));
writeLines(c(sprintf("N = %d; M = %d; B = %d; bootstrap seed = %d",
                    cache$N, M_boot, B, bootstrap_seed),
             capture.output(print(tab, row.names = FALSE))), output_path);

# Generate the report's four-method table from the calculated results.
resampling_coverage = coverage[methods];
table_rows = sprintf("%s & %.2f\\%% \\\\",
  c("Pairs bootstrap", "Residual bootstrap", "Wild bootstrap", "Jackknife"),
  100*resampling_coverage);
writeLines(c("\\begin{tabular}{lr}", "\\toprule",
  "Method & Empirical coverage \\\\", "\\midrule", table_rows,
  "\\bottomrule", "\\end{tabular}"),
  file.path("Output", sprintf("q4_bootstrap_table_M%d.tex", M_boot)));
