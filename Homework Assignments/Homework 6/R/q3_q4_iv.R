#!/usr/bin/env Rscript
# Reproduce HW6 Q3-Q4 with base R. No packages or network access required.
# Run: Rscript 'Homework Assignments/Homework 6/R/q3_q4_iv.R'

script_path <- function() {
  arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(arg) != 1L) stop("Run this script using Rscript.")
  path <- sub("^--file=", "", arg)
  # Rscript encodes spaces in --file as ~+~ on this platform.
  if (!file.exists(path)) path <- gsub("~+~", " ", path, fixed = TRUE)
  normalizePath(path, mustWork = TRUE)
}

# QR projection avoids explicitly constructing the N x N projection matrix.
fit_iv <- function(y, x, z) {
  n <- nrow(x)
  k <- ncol(x)
  if (length(y) != n || nrow(z) != n || n <= k) {
    stop("Incompatible model dimensions or insufficient observations.")
  }
  if (qr(z)$rank != ncol(z)) stop("Instrument matrix is rank deficient.")
  x_hat <- qr.fitted(qr(z), x)
  if (qr(x_hat)$rank != k) stop("Projected regressors are rank deficient.")
  beta <- drop(qr.solve(x_hat, y))
  names(beta) <- colnames(x)
  residual <- drop(y - x %*% beta)
  bread <- chol2inv(chol(crossprod(x_hat)))
  sigma2 <- sum(residual^2) / (n - k)
  vcov_const <- sigma2 * bread
  scores <- sweep(x_hat, 1L, residual, "*")
  vcov_hc1 <- (n / (n - k)) * bread %*% crossprod(scores) %*% bread
  list(beta = beta, se = sqrt(diag(vcov_const)),
       se_hc1 = sqrt(diag(vcov_hc1)), residual = residual,
       sigma2 = sigma2)
}

main <- function() {
  hw_dir <- dirname(dirname(script_path()))
  output_dir <- file.path(hw_dir, "Output")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  input_path <- file.path(hw_dir, "Data", "mroz.csv")
  raw <- read.csv(input_path)
  required <- c("inlf", "wage", "educ", "exper", "age", "kidslt6",
                "kidsge6", "motheduc", "fatheduc", "huseduc")
  if (!all(required %in% names(raw))) stop("Missing required data columns.")
  # Apply one complete-case rule to the largest specification, before fitting.
  keep <- complete.cases(raw[, required]) & raw$inlf == 1 & raw$wage > 0
  d <- raw[which(keep), required]
  if (!all(is.finite(as.matrix(d)))) stop("Nonfinite analysis data.")
  d$logwage <- log(d$wage)
  d$exper2 <- d$exper^2
  ols <- lm(logwage ~ exper + exper2 + age + kidslt6 + kidsge6 + educ,
            data = d, na.action = na.fail)
  x <- model.matrix(ols)
  y <- d$logwage
  z_one <- model.matrix(~ exper + exper2 + age + kidslt6 + kidsge6 +
                          motheduc, data = d)
  z_three <- model.matrix(~ exper + exper2 + age + kidslt6 + kidsge6 +
                            motheduc + fatheduc + huseduc, data = d)
  iv_one <- fit_iv(y, x, z_one)
  iv_three <- fit_iv(y, x, z_three)
  ols_check <- fit_iv(y, x, x)
  # Q4: reproduce the two lm() calls with explicitly scoped data.
  first <- lm(educ ~ exper + exper2 + age + kidslt6 + kidsge6 +
                motheduc + fatheduc + huseduc, data = d, na.action = na.fail)
  d$educ_hat <- fitted(first)
  second <- lm(logwage ~ exper + exper2 + age + kidslt6 + kidsge6 +
                 educ_hat, data = d, na.action = na.fail)
  reduced <- lm(educ ~ exper + exper2 + age + kidslt6 + kidsge6,
                data = d, na.action = na.fail)
  first_f <- anova(reduced, first)$F[2L]

  # Meaningful checks: Lab 7 benchmarks and two independent fitting methods.
  stopifnot(nrow(d) == 428L,
            max(abs(coef(ols) - ols_check$beta)) < 1e-10,
            max(abs(sqrt(diag(vcov(ols))) - ols_check$se)) < 1e-10,
            max(abs(coef(second) - iv_three$beta)) < 1e-10,
            abs(coef(ols)["educ"] - 0.1078320) < 1e-7,
            abs(iv_one$beta["educ"] - 0.0465283257) < 1e-7,
            abs(iv_three$beta["educ"] - 0.0791330188) < 1e-7,
            abs(iv_three$se[7L] - 0.0224050892) < 1e-7,
            abs(iv_three$se_hc1[7L] - 0.0222762273) < 1e-7,
            abs(first_f - 99.9375302625) < 1e-7)

  comparison <- data.frame(
    model = c("OLS", "IV: mother", "2SLS: three IVs"),
    estimate = c(coef(ols)["educ"], iv_one$beta["educ"],
                 iv_three$beta["educ"]),
    se_conventional = c(sqrt(vcov(ols)["educ", "educ"]),
                        iv_one$se[7L], iv_three$se[7L]),
    se_hc1 = c(ols_check$se_hc1[7L], iv_one$se_hc1[7L],
               iv_three$se_hc1[7L]), row.names = NULL)
  # Asymptotic normal intervals; use the same critical value for all models.
  critical <- qnorm(0.975)
  comparison$ci_lower <- comparison$estimate - critical * comparison$se_conventional
  comparison$ci_upper <- comparison$estimate + critical * comparison$se_conventional
  comparison$ci_width <- comparison$ci_upper - comparison$ci_lower
  comparison$hc1_lower <- comparison$estimate - critical * comparison$se_hc1
  comparison$hc1_upper <- comparison$estimate + critical * comparison$se_hc1
  q4 <- data.frame(
    term = names(iv_three$beta),
    manual_lm_estimate = unname(coef(second)),
    correct_2sls_estimate = unname(iv_three$beta),
    naive_lm_se = sqrt(diag(vcov(second))),
    correct_2sls_se = iv_three$se,
    correct_2sls_hc1_se = iv_three$se_hc1, row.names = NULL)
  write.csv(comparison, file.path(output_dir, "q3_education_comparison.csv"),
            row.names = FALSE)
  write.csv(q4, file.path(output_dir, "q4_two_stage_comparison.csv"),
            row.names = FALSE)
  lines <- capture.output({
    cat("HW6 Q3-Q4: Mroz wage equation\n")
    cat("Source: https://www.stata.com/data/jwooldridge/eacsap/mroz.dta\n")
    cat("Input MD5:", unname(tools::md5sum(input_path)), "\n")
    cat("Raw observations:", nrow(raw), "; analysis sample:", nrow(d), "\n")
    cat("Confidence intervals: normal critical value =", critical,
        "; conventional SEs, with HC1 sensitivity intervals.\n\n")
    print(comparison, digits = 10, row.names = FALSE)
    cat("\nFirst-stage partial F (3 excluded IVs):", first_f, "\n")
    cat("\nQ4 comparison:\n")
    print(q4, digits = 10, row.names = FALSE)
    cat("\nMaximum coefficient discrepancy:",
        max(abs(coef(second) - iv_three$beta)), "\n")
    cat("Naive second-stage residual variance:", sigma(second)^2, "\n")
    cat("Correct structural residual variance:", iv_three$sigma2, "\n")
    cat("\nAll numerical validation checks passed.\n\n")
    print(sessionInfo())
  })
  lines <- sub("[[:blank:]]+$", "", lines)
  writeLines(lines, file.path(output_dir, "q3_q4_results.txt"))
  cat(lines, sep = "\n")
}

main()
