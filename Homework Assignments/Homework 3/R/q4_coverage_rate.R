rm(list = ls()); # refresh memory
set.seed(1);

beta0 = 1;
beta1 = 1;
beta2 = 0.2;

N = 100;      # observations per data set
M = 10000;    # number of simulated data sets

# ------------------------------------------------------------------
# Part 1: one data set of length N drawn from the population
# ------------------------------------------------------------------
#   y = beta0 + beta1*x + beta2*x^2 + u,  u ~ t(7),  x ~ N(1,4)
x = rnorm(N, mean = 1, sd = sqrt(4));
u = rt(N, df = 7);
y = beta0 + beta1*x + beta2*x^2 + u;

print("Part 1. First five observations of the data set ...");
print(round(head(cbind(y, x), 5), 4));

print("Summary of the data set ...");
print(round(c(mean_y = mean(y), sd_y = sd(y),
              mean_x = mean(x), sd_x = sd(x)), 4));

# ------------------------------------------------------------------
# Part 2: the OLS estimate from this data set
# ------------------------------------------------------------------
x2 = x^2;
fit = lm(y ~ x + x2);
b = coef(fit);

print("Part 2. OLS estimates against the true values ...");
print(round(data.frame(estimate = b,
                       truth = c(beta0, beta1, beta2)), 4));

# ------------------------------------------------------------------
# Part 3: a 95% confidence interval for beta1, and the indicator
# ------------------------------------------------------------------
# Q2 assumes OLS1 and OLS2 only, so the consistent estimator of
# Avar(b) is the sandwich
#
#   (X'X)^(-1) [ sum_i uhat_i^2 x_i'x_i ] (X'X)^(-1).
#
# The classical estimator, which additionally needs homoskedasticity,
# is computed alongside it for comparison.
X = cbind(1, x, x2);
uhat = resid(fit);

V_sandwich = solve(t(X) %*% X) %*% (t(X) %*% diag(uhat^2) %*% X) %*%
  solve(t(X) %*% X);
V_classical = vcov(fit);

se_sandwich = sqrt(V_sandwich[2,2]);
se_classical = sqrt(V_classical[2,2]);

ci_sandwich = b[2] + c(-1, 1)*1.96*se_sandwich;
ci_classical = b[2] + c(-1, 1)*1.96*se_classical;

# The indicator is one when the interval contains the true beta1.
I_sandwich = as.numeric(ci_sandwich[1] <= beta1 & beta1 <= ci_sandwich[2]);
I_classical = as.numeric(ci_classical[1] <= beta1 & beta1 <= ci_classical[2]);

print("Part 3. 95% confidence intervals for beta1 ...");
print(round(data.frame(
  se = c(se_sandwich, se_classical),
  lower = c(ci_sandwich[1], ci_classical[1]),
  upper = c(ci_sandwich[2], ci_classical[2]),
  indicator = c(I_sandwich, I_classical),
  row.names = c("sandwich", "classical")), 4));
