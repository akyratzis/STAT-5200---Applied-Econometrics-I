# ==================================================================
# STAT 5200 - Applied Econometrics I
# Homework 3, Question 3: the CPS85 wage equation
#
# Follows Lab Notes 02, using the same data set:
#
#   log(wage_i) = beta0 + beta1*educ_i + beta2*exper_i
#                 + beta3*exper_i^2 + u_i
#
# The model is the lab's one without the gender and marital status
# variables, so x_i has K = 4 columns including the intercept.
# ==================================================================

rm(list = ls()); # refresh memory

# ------------------------------------------------------------------
# The data
# ------------------------------------------------------------------
# CPS85.txt is instructor-distributed course material and is not
# tracked in the repository, so it is read from its original place
# relative to this script's directory (Homework 3/R).
data_path = file.path("..", "..", "..", "Datasets & Labs", "Lab 2",
                      "CPS85.txt");

# The file is comma separated with a header row: 531 observations on
# logwage, educ, exper, fe, married, age, south, nonwh, hisp, union.
# Note that the dependent variable is already on the log scale, so no
# further transformation of the wage is needed.
cps85 = read.csv(data_path);
attach(cps85);

print("Data ...");
print(c(observations = nrow(cps85), variables = ncol(cps85)));

# ------------------------------------------------------------------
# OLS by our own calculation, as in the lab notes
# ------------------------------------------------------------------
# Returns everything the later parts need: the coefficients, the
# estimated asymptotic covariance matrix of beta_hat, and the usual
# table of estimates, standard errors, t statistics and p-values.
ols = function(y, X){
  N = nrow(X);
  K = ncol(X);
  b = solve(t(X) %*% X) %*% (t(X) %*% y);        # OLS estimator
  uhat = y - X %*% b;                            # residuals
  sig2hat = (1/(N-K)) * sum(uhat^2);             # estimator of Var(u)
  Vhat = sig2hat * solve((1/N) * t(X) %*% X);    # Avar of sqrt(N)(b-beta)
  Vhat_ols = Vhat/N;                             # Avar of b
  se = sqrt(diag(Vhat_ols));
  tstat = b/se;
  pval = pt(-abs(tstat), N-K)*2;
  tab = cbind(b, se, tstat, pval);
  colnames(tab) = c("Estimate", "SE", "t value", "P(>|t|)");
  return(list(b = b, se = se, uhat = uhat, sig2hat = sig2hat,
              Vhat_ols = Vhat_ols, tab = tab, N = N, K = K));
}

# ------------------------------------------------------------------
# Part 1: estimating the wage equation
# ------------------------------------------------------------------
exper2 = exper^2;   # squared experience, for the concavity in exper

N = length(logwage);
intercept = matrix(1, N, 1);
X = as.matrix(cbind(intercept, educ, exper, exper2));
colnames(X) = c("intercept", "educ", "exper", "exper2");
y = as.matrix(logwage);

fit = ols(y, X);

print("Part 1. OLS estimates of the wage equation ...");
print(round(fit$tab, 6));

cat(sprintf("Residual standard error: %.4f on %d df\n",
            sqrt(fit$sig2hat), fit$N - fit$K));

# Cross-check against R's own routine. The estimates and the classical
# standard errors should agree to the printed precision.
model1 = lm(formula = logwage ~ educ + exper + exper2);
print("The same model through lm(), as a check ...");
print(summary(model1));

# ------------------------------------------------------------------
# Part 2: normal quantile plot of the residuals
# ------------------------------------------------------------------
fig_dir = file.path("..", "figures");
if (!dir.exists(fig_dir)) dir.create(fig_dir, recursive = TRUE);

pdf(file.path(fig_dir, "q3_qqplot.pdf"), width = 5.5, height = 4.4);
par(mar = c(4.2, 4.4, 3.0, 1.0));
qqnorm(fit$uhat, main = "Normal Q-Q plot of the OLS residuals",
       pch = 20, cex = 0.6);
qqline(fit$uhat, lwd = 2, lty = 2, col = "grey40");
dev.off();

# Two summaries of the shape, to put numbers on what the plot shows.
skewness = function(v){
  m2 = mean((v - mean(v))^2);
  m3 = mean((v - mean(v))^3);
  return(m3 / m2^1.5);
}
kurtosis = function(v){
  m2 = mean((v - mean(v))^2);
  m4 = mean((v - mean(v))^4);
  return(m4 / m2^2);
}

print("Part 2. Shape of the residual distribution ...");
print(c(skewness = round(skewness(fit$uhat), 4),
        kurtosis = round(kurtosis(fit$uhat), 4)));

# ------------------------------------------------------------------
# Parts 3 and 4: the return to education, theta
# ------------------------------------------------------------------
# Raising educ by one year lowers exper by one year, since exper is
# defined as age minus educ minus six. The combined effect is
#
#   theta = 100*[exp(beta1 - beta2 + (1 - 2*exper)*beta3) - 1],
#
# which is a smooth function of beta alone. The plug-in estimator
# replaces beta by beta_hat.
#
# Write the exponent as c(exper)'beta with
#
#   c(exper) = (0, 1, -1, 1 - 2*exper)',
#
# which is what the delta method in part 6 needs.
c_vec = function(exper_value){
  return(matrix(c(0, 1, -1, 1 - 2*exper_value), ncol = 1));
}

theta_hat = function(b, exper_value){
  cv = c_vec(exper_value);
  return(100 * (exp(t(cv) %*% b) - 1));
}

# Standard error of theta_hat by the delta method. With
# g(beta) = 100*[exp(c'beta) - 1] the gradient is
# 100*exp(c'beta)*c, so
#
#   se(theta_hat) = 100*exp(c'b) * sqrt(c' Avar(b) c).
se_theta_hat = function(b, Vhat_ols, exper_value){
  cv = c_vec(exper_value);
  grad = 100 * as.numeric(exp(t(cv) %*% b)) * cv;
  return(sqrt(t(grad) %*% Vhat_ols %*% grad));
}

# ------------------------------------------------------------------
# Parts 5 and 7: theta_hat across experience, with standard errors
# and 95 per cent confidence intervals
# ------------------------------------------------------------------
exper_grid = seq(0, 55, by = 5);

theta_grid = rep(NA, length(exper_grid));
se_grid = rep(NA, length(exper_grid));

for (j in 1:length(exper_grid)){
  theta_grid[j] = theta_hat(fit$b, exper_grid[j]);
  se_grid[j] = se_theta_hat(fit$b, fit$Vhat_ols, exper_grid[j]);
}

lci = theta_grid - 1.96*se_grid;   # 95% confidence interval
uci = theta_grid + 1.96*se_grid;

tab_theta = data.frame(exper = exper_grid,
                       theta_hat = round(theta_grid, 4),
                       se = round(se_grid, 4),
                       lower = round(lci, 4),
                       upper = round(uci, 4));

print("Parts 5 and 7. theta_hat across experience ...");
print(tab_theta, row.names = FALSE);

# ------------------------------------------------------------------
# Figure: theta_hat against experience, with the confidence band
# ------------------------------------------------------------------
pdf(file.path(fig_dir, "q3_theta_by_exper.pdf"),
    width = 5.8, height = 4.4);
par(mar = c(4.2, 4.4, 1.0, 1.0));

plot(exper_grid, theta_grid, type = "b", pch = 19,
     ylim = range(c(lci, uci)),
     xlab = "years of experience",
     ylab = expression("estimated return to education, " * hat(theta) * " (%)"));
lines(exper_grid, lci, lty = 2, col = "grey40");
lines(exper_grid, uci, lty = 2, col = "grey40");
abline(h = 0, lwd = 1, col = "grey70");
legend("topright", bty = "n",
       legend = c(expression(hat(theta)), "95% confidence interval"),
       pch = c(19, NA), lty = c(1, 2),
       col = c("black", "grey40"));

dev.off();

print("Figures written to ...");
print(normalizePath(fig_dir));

detach(cps85);
