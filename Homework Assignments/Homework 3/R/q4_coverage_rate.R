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
