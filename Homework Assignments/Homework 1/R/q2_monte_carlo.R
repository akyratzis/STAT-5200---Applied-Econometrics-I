# ==================================================================
# STAT 5200 - Applied Econometrics I
# Homework 1, Question 2: Monte Carlo study of the sample mean
#              (quiz at the end of Lab Notes 01)
#
# This follows the code of Lab Notes 01. The data generating
# function is duplicated so that the error term can be either
#   e ~ t(10)                        (the original lab model)
#   e = v - 20, v ~ chi-squared(20)  (the model asked for in the quiz)
# Both errors have mean zero, so E[y] = 3 in either case.
# ==================================================================

rm(list = ls()); # refresh memory
# seed for the random number generator
my_random_seed = 1; set.seed(my_random_seed);

# ------------------------------------------------------------------
# Building our own population
# ------------------------------------------------------------------
generate_data_t_error = function(N = 20){
  # model parameters
  beta0 = 1;
  beta1 = 1;
  beta2 = 0.2;
  # simulating data
  mat_data = matrix(NA, N, 2); # N by 2 matrix to store (y,x) by row
  for (i in 1:N){
    e = rt(1, df=10); # e ~ t distribution with degrees of freedom 10
    x = rnorm(1, mean=1, sd = sqrt(4)); # x~N(1,4)
    y = beta0 + beta1*x + beta2*x^2 + e; # this is our population model
    mat_data[i,] = c(y,x);
  }
  colnames(mat_data) = c("y", "x"); # put column names
  return(mat_data);
}

# Identical to generate_data_t_error(), except that the error term is
# drawn from a chi-squared distribution recentred at zero.
generate_data_x_squared_error = function(N = 20){
  # model parameters
  beta0 = 1;
  beta1 = 1;
  beta2 = 0.2;
  # simulating data
  mat_data = matrix(NA, N, 2); # N by 2 matrix to store (y,x) by row
  for (i in 1:N){
    e = rchisq(1, df=20) - 20; # e = v-20, v ~ chi-squared with df 20
    x = rnorm(1, mean=1, sd = sqrt(4)); # x~N(1,4)
    y = beta0 + beta1*x + beta2*x^2 + e; # this is our population model
    mat_data[i,] = c(y,x);
  }
  colnames(mat_data) = c("y", "x"); # put column names
  return(mat_data);
}

# ------------------------------------------------------------------
# Generating one data set from each population
# ------------------------------------------------------------------
N = 20; # length of the data
data1 = generate_data_t_error(N);
data2 = generate_data_x_squared_error(N);

# Sample mean of y
theta_hat_t_error = mean(data1[,1]);
theta_hat_x_squared_error = mean(data2[,1]);

print("Sample mean of y from one data set of length 20 ...");
print(c(t_error = theta_hat_t_error,
        x_squared_error = theta_hat_x_squared_error));

# ------------------------------------------------------------------
# Simulating M data sets and collecting the M sample means
# ------------------------------------------------------------------
simulation_sample_mean_t_error = function(N=20, M=1000){
  # A function that generates M data sets (length of N), computes
  # the sample mean of each
  # N: the length of each data set
  # M: the number of simulations (the number of data sets)
  mat_theta_hat = matrix(NA, M, 1); # placeholder for M sample means
  for (m in 1:M){
    dataset = generate_data_t_error(N); # a data set (y,x) of length N
    theta_hat = mean(dataset[,1]); # compute sample mean of y
    mat_theta_hat[m,] = theta_hat; # store m-th sample mean
  }
  return(mat_theta_hat);
}

simulation_sample_mean_x_squared_error = function(N=20, M=1000){
  # As above, but drawing from the chi-squared error population
  mat_theta_hat = matrix(NA, M, 1); # placeholder for M sample means
  for (m in 1:M){
    dataset = generate_data_x_squared_error(N);
    theta_hat = mean(dataset[,1]); # compute sample mean of y
    mat_theta_hat[m,] = theta_hat; # store m-th sample mean
  }
  return(mat_theta_hat);
}

# ------------------------------------------------------------------
# One results matrix per error distribution
#   rows:    the M simulated sample means
#   columns: the length N of the data set
# ------------------------------------------------------------------
M = 1000; # the number of simulations
N_grid = c(20, 100, 500); # the lengths of the data sets

mat_theta_hat_t_error = cbind(
  simulation_sample_mean_t_error(N = N_grid[1], M),
  simulation_sample_mean_t_error(N = N_grid[2], M),
  simulation_sample_mean_t_error(N = N_grid[3], M));

mat_theta_hat_x_squared_error = cbind(
  simulation_sample_mean_x_squared_error(N = N_grid[1], M),
  simulation_sample_mean_x_squared_error(N = N_grid[2], M),
  simulation_sample_mean_x_squared_error(N = N_grid[3], M));

col_labels = c("N=20", "N=100", "N=500");
colnames(mat_theta_hat_t_error) = col_labels;
colnames(mat_theta_hat_x_squared_error) = col_labels;

# The sample mean should be centred on E[y] = 3 in both populations.
print("Mean of the sample means, e ~ t(10) ...");
print(apply(mat_theta_hat_t_error, 2, mean));

print("Mean of the sample means, e = v-20 ...");
print(apply(mat_theta_hat_x_squared_error, 2, mean));

# ------------------------------------------------------------------
# Thought experiment 1
#   Var(theta_hat) should fall roughly by a factor of 5 each time we
#   multiply N by 5.
# ------------------------------------------------------------------
print("Variance of the sample mean, e ~ t(10) ...");
print(apply(mat_theta_hat_t_error, 2, var));

print("Variance of the sample mean, e = v-20 ...");
print(apply(mat_theta_hat_x_squared_error, 2, var));

# ------------------------------------------------------------------
# Thought experiment 2
#   Var(sqrt(N)*theta_hat) should be roughly the same for every N.
# ------------------------------------------------------------------
print("Variance of sqrt(N)*theta_hat, e ~ t(10) ...");
print(c("N=20"  = var(sqrt(20) *mat_theta_hat_t_error[,1]),
        "N=100" = var(sqrt(100)*mat_theta_hat_t_error[,2]),
        "N=500" = var(sqrt(500)*mat_theta_hat_t_error[,3])));

print("Variance of sqrt(N)*theta_hat, e = v-20 ...");
print(c("N=20"  = var(sqrt(20) *mat_theta_hat_x_squared_error[,1]),
        "N=100" = var(sqrt(100)*mat_theta_hat_x_squared_error[,2]),
        "N=500" = var(sqrt(500)*mat_theta_hat_x_squared_error[,3])));

# ------------------------------------------------------------------
# Histograms of sqrt(N)*theta_hat when N = 500
# ------------------------------------------------------------------
fig_dir = file.path("..", "figures");
if (!dir.exists(fig_dir)) dir.create(fig_dir, recursive = TRUE);

sqrtN_theta_hat_t = sqrt(500) * mat_theta_hat_t_error[,"N=500"];
sqrtN_theta_hat_x2 = sqrt(500) *
  mat_theta_hat_x_squared_error[,"N=500"];

# A common horizontal axis makes the difference in spread visible.
xlim_common = range(c(sqrtN_theta_hat_t, sqrtN_theta_hat_x2));

pdf(file.path(fig_dir, "q2_hist_raw.pdf"), width = 9, height = 4.2);
par(mfrow = c(1, 2), mar = c(4.2, 4.2, 3.0, 1.0));

hist(sqrtN_theta_hat_t, breaks = 30, xlim = xlim_common,
     main = "Original model: e ~ t(10)",
     xlab = "sqrt(N)*theta_hat, N = 500",
     col = "grey85", border = "white");
abline(v = sqrt(500)*3, lwd = 2, lty = 2);

hist(sqrtN_theta_hat_x2, breaks = 30, xlim = xlim_common,
     main = "Quiz model: e = v-20, v ~ chi-squared(20)",
     xlab = "sqrt(N)*theta_hat, N = 500",
     col = "grey85", border = "white");
abline(v = sqrt(500)*3, lwd = 2, lty = 2);

dev.off();

print("Figure written to ...");
print(normalizePath(fig_dir));

# ------------------------------------------------------------------
# Writing the results table as a LaTeX fragment
#   The report reads this file with \input, so the numbers in the
#   report are always the numbers this script last produced and never
#   have to be copied across by hand.
#
#   The whole tabular environment is written here, not just the rows.
#   LaTeX's \input{file} expands to \@@input file \relax, and that
#   trailing \relax would land immediately after the last \\ of the
#   fragment, breaking the \cr-then-\noalign sequence that \bottomrule
#   needs and giving "Misplaced \noalign". Emitting the complete
#   tabular puts the \relax after \end{tabular}, where it is harmless.
# ------------------------------------------------------------------
table_rows = function(row_label, mat){
  means = apply(mat, 2, mean);
  vars  = apply(mat, 2, var);
  vars_scaled = c(var(sqrt(20) *mat[,1]),
                  var(sqrt(100)*mat[,2]),
                  var(sqrt(500)*mat[,3]));
  c(row_label,
    sprintf("  & %d & %.3f & %.4f & %.3f \\\\",
            N_grid, means, vars, vars_scaled));
}

table_header = paste0(
  "Error specification & $N$ & mean$(\\hat\\theta)$ & ",
  "$\\operatorname{Var}(\\hat\\theta)$ & ",
  "$\\operatorname{Var}(\\sqrt{N}\\hat\\theta)$ \\\\");

latex_table = c(
  "\\begin{tabular}{llrrr}",
  "\\toprule",
  table_header,
  "\\midrule",
  table_rows("$\\varepsilon \\sim t_{10}$ (original)",
             mat_theta_hat_t_error),
  "\\addlinespace",
  table_rows(paste0("$\\varepsilon = v - 20$, ",
                    "$v \\sim \\chi^2(20)$ (quiz)"),
             mat_theta_hat_x_squared_error),
  "\\bottomrule",
  "\\end{tabular}");

out_dir = file.path("..", "output");
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE);
writeLines(latex_table, file.path(out_dir, "q2_table.tex"));

print("Table fragment written to ...");
print(normalizePath(file.path(out_dir, "q2_table.tex")));
