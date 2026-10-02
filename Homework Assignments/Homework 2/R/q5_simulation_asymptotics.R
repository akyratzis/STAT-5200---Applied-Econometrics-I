# ==================================================================
# STAT 5200 - Applied Econometrics I
# Homework 2, Question 5: simulation and asymptotics
#
# This revisits Lab Notes 01 with a different population model:
#
#   y_i = 1 + x_i + e_i,
#   x_i ~ iid N(1,4),
#   e_i = v_i - 20 with v_i ~ iid chi-squared(20),
#   x and e independent.
#
# So E[e] = 0 and Var(e) = 40, as stated in the question. Note the
# model has no x^2 term, unlike the one used in the lab notes.
# ==================================================================

rm(list = ls()); # refresh memory
# seed for the random number generator
my_random_seed = 1; set.seed(my_random_seed);

# ------------------------------------------------------------------
# Building our own population
# ------------------------------------------------------------------
# Same structure as generate_data() in Lab Notes 01, with two
# changes. The population model drops the x^2 term, and the N draws
# are taken in one vectorised call instead of one at a time in a for
# loop. The draws are identically distributed either way; the loop is
# simply too slow for the number of replications Part 4 needs.
generate_data = function(N = 20){
  # model parameters
  beta0 = 1;
  beta1 = 1;
  # simulating data
  e = rchisq(N, df = 20) - 20;         # e = v-20, v ~ chi-squared(20)
  x = rnorm(N, mean = 1, sd = sqrt(4)); # x ~ N(1,4)
  y = beta0 + beta1*x + e;              # this is our population model
  mat_data = cbind(y, x);
  colnames(mat_data) = c("y", "x");     # put column names
  return(mat_data);
}

# ------------------------------------------------------------------
# Simulating M data sets and collecting the M sample means
# ------------------------------------------------------------------
simulation_sample_mean = function(N = 20, M = 1000){
  # N: the length of each data set
  # M: the number of simulations (the number of data sets)
  mat_theta_hat = matrix(NA, M, 1); # placeholder for M sample means
  for (m in 1:M){
    dataset = generate_data(N);     # a data set (y,x) of length N
    theta_hat = mean(dataset[,1]);  # compute sample mean of y
    mat_theta_hat[m,] = theta_hat;  # store m-th sample mean
  }
  return(mat_theta_hat);
}

# Sample skewness, the usual moment estimator m3 / m2^(3/2).
skewness = function(v){
  m2 = mean((v - mean(v))^2);
  m3 = mean((v - mean(v))^3);
  return(m3 / m2^1.5);
}

# ------------------------------------------------------------------
# Part 1: Var(y_i)
# ------------------------------------------------------------------
# x and e are independent, so the variances add:
#   Var(y) = Var(1 + x + e) = Var(x) + Var(e) = 4 + 40 = 44.
var_x = 4;
var_e = 2*20;        # a chi-squared(k) variable has variance 2k
sigma2 = var_x + var_e;

print("Part 1. Var(y_i) = Var(x) + Var(e) ...");
print(c(Var_x = var_x, Var_e = var_e, Var_y = sigma2));

# Confirm by simulating one long data set from the population.
one_long_sample = generate_data(1e6);
cat("Simulated Var(y) from one data set of length 1e6 ...\n");
cat(sprintf("  %.4f\n", var(one_long_sample[,"y"])));

# ------------------------------------------------------------------
# Part 2: the asymptotic variance of ybar_N at N = 100
# ------------------------------------------------------------------
# From Q4, Avar(ybar_N) = sigma^2 / N.
N_part2 = 100;
avar_ybar = sigma2 / N_part2;

print("Part 2. Avar(ybar_N) = sigma^2/N at N = 100 ...");
print(c(sigma2 = sigma2, N = N_part2, Avar = avar_ybar));

# ------------------------------------------------------------------
# Part 3: Var(ybar_N) by Monte Carlo at N = 100
# ------------------------------------------------------------------
# M is set well above the lab's 1000 because Part 4 estimates a third
# moment, which is far noisier than a variance: the standard error of
# a sample skewness is roughly sqrt(6/M), so M = 1000 would give
# about 0.078, swamping the skewness of 0.017 expected at N = 1000.
# At M = 500000 that standard error is about 0.0035.
M = 500000;

mat_theta_hat_100 = simulation_sample_mean(N = N_part2, M = M);
var_mc = var(mat_theta_hat_100);

print("Part 3. Monte Carlo Var(ybar_N) at N = 100 ...");
print(c(Monte_Carlo = round(var_mc, 4),
        Asymptotic = round(avar_ybar, 4),
        Ratio = round(var_mc/avar_ybar, 4)));

# ------------------------------------------------------------------
# Part 4: skewness of ybar_N at N = 10, 100 and 1000
# ------------------------------------------------------------------
# For an iid sample, skew(ybar_N) = skew(y)/sqrt(N). The third central
# moment of y is that of e alone, since x is symmetric, and a
# chi-squared(k) variable has third central moment 8k.
mu3_y = 8*20;
skew_y = mu3_y / sigma2^1.5;

N_grid = c(10, 100, 1000);
skew_mc = rep(NA, length(N_grid));

for (j in 1:length(N_grid)){
  draws = simulation_sample_mean(N = N_grid[j], M = M);
  skew_mc[j] = skewness(as.vector(draws));
  if (N_grid[j] == 1000) mat_theta_hat_1000 = draws;
  if (N_grid[j] == 10)   mat_theta_hat_10 = draws;
}

print("Part 4. Skewness of ybar_N ...");
print(data.frame(N = N_grid,
                 skew_MonteCarlo = round(skew_mc, 4),
                 skew_theory = round(skew_y/sqrt(N_grid), 4)),
      row.names = FALSE);

print("Skewness of a single y_i, for reference ...");
print(round(skew_y, 4));

# A sample skewness based on M draws has standard error about
# sqrt(6/M), which is the yardstick for judging the agreement above.
cat(sprintf("Monte Carlo standard error of each skewness: %.4f\n",
            sqrt(6/M)));

# ------------------------------------------------------------------
# Extra simulations, used only for the figures
# ------------------------------------------------------------------
# These run after everything reported above, so they do not disturb
# the numbers already produced.
#
# N = 1 is included because the mean of a single observation is that
# observation, so this panel is the population distribution of y_i
# itself, and it shows where the asymmetry starts.
mat_theta_hat_1 = simulation_sample_mean(N = 1, M = M);

print("Skewness of a single observation, simulated at N = 1 ...");
print(round(skewness(as.vector(mat_theta_hat_1)), 4));

# ------------------------------------------------------------------
# Figure 1: the distribution of ybar_N as N grows
# ------------------------------------------------------------------
# Each panel is standardised to mean zero and unit variance so that
# only the shape is compared, with the standard normal density drawn
# on top.
fig_dir = file.path("..", "figures");
if (!dir.exists(fig_dir)) dir.create(fig_dir, recursive = TRUE);

standardise = function(v){ (v - mean(v)) / sd(v) }

N_panels = c(1, N_grid);
panels = list(mat_theta_hat_1, mat_theta_hat_10,
              mat_theta_hat_100, mat_theta_hat_1000);
skew_panels = c(skewness(as.vector(mat_theta_hat_1)), skew_mc);

# Normal quantile-quantile plots rather than histograms. A skewness
# of 0.55 is far too mild to see in a histogram, which is why the
# panels would otherwise all look alike, but it is plainly visible as
# curvature away from the 45 degree line in a Q-Q plot.
pdf(file.path(fig_dir, "q5_sampling_distributions.pdf"),
    width = 10, height = 3.1);
par(mfrow = c(1, 4), mar = c(4.2, 4.2, 3.2, 1.0));

p_grid = ppoints(500);
q_theory = qnorm(p_grid);

for (j in 1:4){
  z = standardise(as.vector(panels[[j]]));
  q_emp = quantile(z, probs = p_grid);
  lab = if (N_panels[j] == 1) "N = 1  (a single y_i)" else
        paste0("N = ", N_panels[j]);
  plot(q_theory, q_emp, type = "l", lwd = 2,
       xlim = c(-3.3, 3.3), ylim = c(-3.3, 4.4),
       main = paste0(lab, "\nskewness = ",
                     sprintf("%.3f", skew_panels[j])),
       xlab = "normal quantile", ylab = "sample quantile");
  abline(0, 1, lwd = 1, lty = 2, col = "grey40");
}

dev.off();

# ------------------------------------------------------------------
# Figure 2: the rate at which the skewness dies
# ------------------------------------------------------------------
# A histogram cannot resolve a skewness of 0.17 from one of 0.05, so
# the decay is shown directly instead. On log-log axes the relation
# skew(ybar_N) = skew(y)/sqrt(N) is a straight line of slope -1/2.
N_sweep = c(1, 3, 10, 30, 100, 300, 1000);
M_sweep = 200000;   # smaller than M: this is for a trend, not a table
skew_sweep = rep(NA, length(N_sweep));

for (j in 1:length(N_sweep)){
  draws = simulation_sample_mean(N = N_sweep[j], M = M_sweep);
  skew_sweep[j] = skewness(as.vector(draws));
}

print("Skewness across a log-spaced grid of N ...");
print(data.frame(N = N_sweep,
                 skew_MonteCarlo = round(skew_sweep, 4),
                 skew_theory = round(skew_y/sqrt(N_sweep), 4)),
      row.names = FALSE);

pdf(file.path(fig_dir, "q5_skewness_decay.pdf"),
    width = 5.5, height = 4.0);
par(mar = c(4.2, 4.4, 1.0, 1.0));

plot(N_sweep, skew_sweep, log = "xy", type = "p", pch = 19,
     xlab = "sample size N",
     ylab = expression("skewness of " * bar(y)[N]),
     ylim = range(c(skew_sweep, skew_y/sqrt(N_sweep))));
lines(N_sweep, skew_y/sqrt(N_sweep), lwd = 2, lty = 2);
legend("bottomleft", bty = "n",
       legend = c("Monte Carlo", expression(skew(y)/sqrt(N))),
       pch = c(19, NA), lty = c(NA, 2), lwd = c(NA, 2));

dev.off();

print("Figures written to ...");
print(normalizePath(fig_dir));
