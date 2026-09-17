# =============================================================================
# STAT 5200 - Applied Econometrics I
# Homework 1, Question 2: Monte Carlo study of the sample mean
#              (quiz at the end of Lab Notes 01)
#
# Population model:  y = beta0 + beta1 * x + beta2 * x^2 + eps,   x ~ N(1, 4)
#   beta0 = 1, beta1 = 1, beta2 = 0.2
#
# Two error specifications:
#   "t10"   eps ~ t(10)                      (the original lab model)
#   "chi2"  eps  = v - 20, v ~ chi^2(20)     (the model asked for in the quiz)
#
# Both have E[eps] = 0, so in both cases
#   theta_0 = E[y] = beta0 + beta1 * E[x] + beta2 * E[x^2] = 1 + 1 + 0.2 * 5 = 3
# The two differ in Var(eps):  Var(t10) = 10/8 = 1.25,  Var(chi^2(20)) = 40.
# =============================================================================

rm(list = ls())

my_random_seed <- 1
set.seed(my_random_seed)

# Write figures next to the report regardless of the working directory from
# which the script is launched.
fig_dir <- file.path("..", "figures")
if (!dir.exists(fig_dir)) dir.create(fig_dir, recursive = TRUE)

# -- Population parameters -----------------------------------------------------
beta0 <- 1
beta1 <- 1
beta2 <- 0.2

x_mean <- 1
x_var  <- 4

# -----------------------------------------------------------------------------
# Data generating process
# -----------------------------------------------------------------------------
# draw_error(): one realisation of eps under the requested specification.
draw_error <- function(error = c("t10", "chi2")) {
  error <- match.arg(error)
  if (error == "t10") {
    rt(1, df = 10)               # eps ~ t(10)
  } else {
    rchisq(1, df = 20) - 20      # eps = v - 20, v ~ chi^2(20)
  }
}

# generate_data(): an N x 2 matrix of (y, x) pairs sampled from the population.
generate_data <- function(N = 20, error = c("t10", "chi2")) {
  error <- match.arg(error)

  mat_data <- matrix(NA, N, 2)   # N by 2 matrix to store (y, x) by row

  for (i in 1:N) {
    e <- draw_error(error)
    x <- rnorm(1, mean = x_mean, sd = sqrt(x_var))
    y <- beta0 + beta1 * x + beta2 * x^2 + e
    mat_data[i, ] <- c(y, x)
  }

  colnames(mat_data) <- c("y", "x")
  return(mat_data)
}

# -----------------------------------------------------------------------------
# Monte Carlo experiment
# -----------------------------------------------------------------------------
# simulation_sample_mean(): generate M data sets of length N and return the
# M sample means of y as an M x 1 matrix.
simulation_sample_mean <- function(N = 20, M = 1000, error = c("t10", "chi2")) {
  error <- match.arg(error)

  mat_theta_hat <- matrix(NA, M, 1)   # placeholder for the M sample means

  for (m in 1:M) {
    dataset            <- generate_data(N, error)
    mat_theta_hat[m, ] <- mean(dataset[, "y"])
  }

  return(mat_theta_hat)
}

# -----------------------------------------------------------------------------
# Run the experiment for N = 20, 100, 500 under both error specifications
# -----------------------------------------------------------------------------
M       <- 1000
N_grid  <- c(20, 100, 500)
models  <- c("t10", "chi2")

# draws[[model]][[as.character(N)]] holds the M simulated sample means.
draws <- list()

for (model in models) {
  draws[[model]] <- list()
  for (N in N_grid) {
    draws[[model]][[as.character(N)]] <- simulation_sample_mean(N, M, model)
  }
}

# -- Results table -------------------------------------------------------------
results <- data.frame(
  model         = rep(models, each = length(N_grid)),
  N             = rep(N_grid, times = length(models)),
  mean_theta    = NA_real_,
  var_theta     = NA_real_,
  var_sqrtN_theta = NA_real_
)

for (r in seq_len(nrow(results))) {
  th <- draws[[results$model[r]]][[as.character(results$N[r])]]
  results$mean_theta[r]      <- mean(th)
  results$var_theta[r]       <- var(th)
  results$var_sqrtN_theta[r] <- var(sqrt(results$N[r]) * th)
}

cat("\nMonte Carlo results (M =", M, "replications, theta_0 = 3)\n\n")
print(results, digits = 4, row.names = FALSE)

# -- Theoretical benchmark for Var(sqrt(N) * theta_hat) = Var(y) ---------------
# For x ~ N(1, 4):  Var(x) = 4, Var(x^2) = 48, Cov(x, x^2) = 8, so
#   Var(beta1 x + beta2 x^2) = 4 + 0.2^2 * 48 + 2 * 0.2 * 8 = 9.12.
var_x_part <- beta1^2 * x_var + beta2^2 * 48 + 2 * beta1 * beta2 * 8
var_eps    <- c(t10 = 10 / 8, chi2 = 2 * 20)

cat("\nTheoretical Var(y) = Var(beta1 x + beta2 x^2) + Var(eps):\n")
print(round(var_x_part + var_eps, 4))

# -----------------------------------------------------------------------------
# Histograms of sqrt(N) * theta_hat at N = 500
# -----------------------------------------------------------------------------
N_plot   <- 500
th_t10   <- sqrt(N_plot) * draws[["t10"]][[as.character(N_plot)]]
th_chi2  <- sqrt(N_plot) * draws[["chi2"]][[as.character(N_plot)]]

theta_0  <- beta0 + beta1 * x_mean + beta2 * (x_var + x_mean^2)   # = 3

# (i) Raw scale: a common x-axis makes the difference in spread visible.
xlim_raw <- range(c(th_t10, th_chi2))

pdf(file.path(fig_dir, "q2_hist_raw.pdf"), width = 9, height = 4.2)
par(mfrow = c(1, 2), mar = c(4.2, 4.2, 3.0, 1.0))

hist(th_t10, breaks = 30, freq = FALSE, xlim = xlim_raw,
     main = expression("Original model:" ~ epsilon ~ "~" ~ t[10]),
     xlab = expression(sqrt(N) * hat(theta)), col = "grey85", border = "white")
abline(v = sqrt(N_plot) * theta_0, lwd = 2, lty = 2)

hist(th_chi2, breaks = 30, freq = FALSE, xlim = xlim_raw,
     main = expression("Quiz model:" ~ epsilon == v - 20 * "," ~ v ~ "~" ~ chi[20]^2),
     xlab = expression(sqrt(N) * hat(theta)), col = "grey85", border = "white")
abline(v = sqrt(N_plot) * theta_0, lwd = 2, lty = 2)

dev.off()

# (ii) Standardised scale: subtract sqrt(N) * theta_0 and divide by the Monte
# Carlo standard deviation, then overlay the standard normal density. This is
# the comparison that isolates the *shape* of the sampling distribution.
std <- function(v) as.vector((v - mean(v)) / sd(v))

pdf(file.path(fig_dir, "q2_hist_standardised.pdf"), width = 9, height = 4.2)
par(mfrow = c(1, 2), mar = c(4.2, 4.2, 3.0, 1.0))

for (j in seq_along(models)) {
  z <- std(sqrt(N_plot) * draws[[models[j]]][[as.character(N_plot)]])
  hist(z, breaks = 30, freq = FALSE, xlim = c(-4, 4),
       main = if (models[j] == "t10") expression(epsilon ~ "~" ~ t[10])
              else expression(epsilon == v - 20 * "," ~ v ~ "~" ~ chi[20]^2),
       xlab = "standardised value", col = "grey85", border = "white")
  curve(dnorm, from = -4, to = 4, add = TRUE, lwd = 2)
}

dev.off()

cat("\nSkewness of sqrt(N) * theta_hat at N = 500",
    "(0 for a symmetric distribution):\n")
skewness <- function(v) mean((v - mean(v))^3) / sd(v)^3
cat("  t10 error :", round(skewness(as.vector(th_t10)), 4), "\n")
cat("  chi2 error:", round(skewness(as.vector(th_chi2)), 4), "\n")

cat("\nFigures written to", normalizePath(fig_dir), "\n")
