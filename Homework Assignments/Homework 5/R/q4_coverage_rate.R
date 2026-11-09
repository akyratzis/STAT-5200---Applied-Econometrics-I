# HW5 Q4(a)-(f): adapted from HW3/R/q4_coverage_rate.R and Lab 3.
# Requires the sandwich package: install.packages("sandwich").
# Uses t(10) errors; adds HC0-HC3 intervals in the existing loop for (e).
# In (e), the population violates OLS3; we retain the same interval formula.
rm(list = ls()); # refresh memory
library("sandwich");
set.seed(1);

beta0 = 1;
beta1 = 1;
beta2 = 0.2;

N = 100;      # observations per data set
M = 10000;    # number of simulated data sets

# ------------------------------------------------------------------
# Part (a): one data set of length N drawn from the population
# ------------------------------------------------------------------
#   y = beta0 + beta1*x + beta2*x^2 + u,  u ~ t(10),  x ~ N(1,4)
x = rnorm(N, mean = 1, sd = sqrt(4));
u = rt(N, df = 10);
y = beta0 + beta1*x + beta2*x^2 + u;

print("Part (a). First five observations of the data set ...");
print(round(head(cbind(y, x), 5), 4));

print("Summary of the data set ...");
print(round(c(mean_y = mean(y), sd_y = sd(y),
              mean_x = mean(x), sd_x = sd(x)), 4));

# ------------------------------------------------------------------
# Part (b): the OLS estimate from this data set
# ------------------------------------------------------------------
x2 = x^2;
fit = lm(y ~ x + x2);
b = coef(fit);

print("Part (b). OLS estimates against the true values ...");
print(round(data.frame(estimate = b,
                       truth = c(beta0, beta1, beta2)), 4));

# ------------------------------------------------------------------
# Part (c): a 95% confidence interval for beta1, and the indicator
# ------------------------------------------------------------------
# Conventional covariance estimate under OLS1, OLS2 and OLS3.
se_b1 = sqrt(vcov(fit)[2,2]);
ci = b[2] + c(-1, 1)*1.96*se_b1;

# The indicator is one when the interval contains the true beta1.
I = as.numeric(ci[1] <= beta1 & beta1 <= ci[2]);

print("Part (c). 95% confidence interval for beta1 ...");
print(round(c(se = se_b1, lower = ci[1], upper = ci[2],
              indicator = I), 4));

# ------------------------------------------------------------------
# Part (d): the empirical coverage rate over M data sets
# ------------------------------------------------------------------
# Parts (a), (b) and (c) repeated on M freshly drawn data sets.
I_all = rep(NA, M);

for (m in 1:M){
  x = rnorm(N, mean = 1, sd = sqrt(4));
  u = rt(N, df = 10);
  y = beta0 + beta1*x + beta2*x^2 + u;
  x2 = x^2;

  fit = lm(y ~ x + x2);
  b = coef(fit);
  ci = b[2] + c(-1, 1)*1.96*sqrt(vcov(fit)[2,2]);
  I_all[m] = as.numeric(ci[1] <= beta1 & beta1 <= ci[2]);
}

print("Part (d). Empirical coverage rate over M data sets ...");
print(c(M = M, N = N));
print(round(mean(I_all), 4));

# ------------------------------------------------------------------
# Part (e): repeat with heteroskedastic errors, keeping conventional SEs
# ------------------------------------------------------------------
#   y = beta0 + beta1*x + beta2*x^2 + (|x|/2)*u
# Continue the random sequence from (d); do not reset the seed.
I_all_het = rep(NA, M);
# Part (f): compare HC methods on exactly the same data sets as (e).
I_all_hc = matrix(NA, M, 4);
colnames(I_all_hc) = c("HC0", "HC1", "HC2", "HC3");
# Store the generated observations without making any additional random draws.
heteroskedastic_samples = vector("list", M);

for (m in 1:M){
  x = rnorm(N, mean = 1, sd = sqrt(4));
  u = rt(N, df = 10);
  y = beta0 + beta1*x + beta2*x^2 + (abs(x)/2)*u;
  x2 = x^2;
  heteroskedastic_samples[[m]] = cbind(y = y, x = x);

  fit = lm(y ~ x + x2);
  b = coef(fit);
  # Deliberately retain the conventional covariance estimate from (c).
  ci = b[2] + c(-1, 1)*1.96*sqrt(vcov(fit)[2,2]);
  I_all_het[m] = as.numeric(ci[1] <= beta1 & beta1 <= ci[2]);

  # Lab 3: construct each vector of heteroskedasticity-consistent SEs.
  se_HC0 = sqrt(diag(vcovHC(fit, type = "HC0")));
  se_HC1 = sqrt(diag(vcovHC(fit, type = "HC1")));
  se_HC2 = sqrt(diag(vcovHC(fit, type = "HC2")));
  se_HC3 = sqrt(diag(vcovHC(fit, type = "HC3")));

  # The second coefficient is beta1, the coefficient on x.
  se_hc = c(se_HC0[2], se_HC1[2], se_HC2[2], se_HC3[2]);
  lower_hc = b[2] - 1.96*se_hc;
  upper_hc = b[2] + 1.96*se_hc;
  I_all_hc[m, ] = as.numeric(lower_hc <= beta1 & beta1 <= upper_hc);
}

print("Part (e). Empirical coverage rate, heteroskedastic model ...");
print(round(mean(I_all_het), 4));

print("Part (f). Coverage on the same heteroskedastic data sets ...");
tab_coverage = data.frame(
  Method = c("Conventional", colnames(I_all_hc)),
  Coverage = round(c(mean(I_all_het), colMeans(I_all_hc)), 4),
  row.names = NULL
);
print(tab_coverage);

# Run this script from the Homework 5 directory. Part (g) reads this cache.
dir.create("Output", showWarnings = FALSE);
saveRDS(list(
  N = N, M = M, seed = 1, beta = c(beta0, beta1, beta2),
  error_df = 10, samples = heteroskedastic_samples,
  conventional_hits = I_all_het, hc_hits = I_all_hc
), file.path("Output", "q4_heteroskedastic_samples.rds"));
