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
se_b1 = sqrt(vcov(fit)[2,2]);
ci = b[2] + c(-1, 1)*1.96*se_b1;

# The indicator is one when the interval contains the true beta1.
I = as.numeric(ci[1] <= beta1 & beta1 <= ci[2]);

print("Part 3. 95% confidence interval for beta1 ...");
print(round(c(se = se_b1, lower = ci[1], upper = ci[2], indicator = I), 4));

# ------------------------------------------------------------------
# Part 4: the empirical coverage rate over M data sets
# ------------------------------------------------------------------
# Parts 1, 2 and 3 repeated on M freshly drawn data sets.
I_all = rep(NA, M);

for (m in 1:M){
  x = rnorm(N, mean = 1, sd = sqrt(4));
  u = rt(N, df = 7);
  y = beta0 + beta1*x + beta2*x^2 + u;
  x2 = x^2;

  fit = lm(y ~ x + x2);
  b = coef(fit);
  ci = b[2] + c(-1, 1)*1.96*sqrt(vcov(fit)[2,2]);
  I_all[m] = as.numeric(ci[1] <= beta1 & beta1 <= ci[2]);
}

print("Part 4. Empirical coverage rate over M data sets ...");
print(c(M = M, N = N));
print(round(mean(I_all), 4));

# ------------------------------------------------------------------
# Part 5: the same exercise with a heteroskedastic error
# ------------------------------------------------------------------
#   y = beta0 + beta1*x + beta2*x^2 + (|x|/2)*u
I_all_het = rep(NA, M);

for (m in 1:M){
  x = rnorm(N, mean = 1, sd = sqrt(4));
  u = rt(N, df = 7);
  y = beta0 + beta1*x + beta2*x^2 + (abs(x)/2)*u;
  x2 = x^2;

  fit = lm(y ~ x + x2);
  b = coef(fit);
  ci = b[2] + c(-1, 1)*1.96*sqrt(vcov(fit)[2,2]);
  I_all_het[m] = as.numeric(ci[1] <= beta1 & beta1 <= ci[2]);
}

print("Part 5. Empirical coverage rate, heteroskedastic model ...");
print(round(mean(I_all_het), 4));
