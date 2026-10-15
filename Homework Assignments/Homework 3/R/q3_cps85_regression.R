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
# Part 1: estimating the wage equation
# ------------------------------------------------------------------
exper2 = exper^2;   # squared experience, for the concavity in exper

model1 = lm(formula = logwage ~ educ + exper + exper2);

print("Part 1. OLS estimates of the wage equation ...");
print(summary(model1));

# The coefficients and their estimated covariance matrix. vcov() is
# sigma2hat * (X'X)^(-1), the same matrix the lab notes build by hand.
b = coef(model1);
V = vcov(model1);

# Theory says the earnings profile is concave in experience, peaking
# at exper = -beta2/(2*beta3).
print("Experience at which log(wage) peaks ...");
print(round(-b[3]/(2*b[4]), 2));

# ------------------------------------------------------------------
# Part 2: normal quantile plot of the residuals
# ------------------------------------------------------------------
uhat = resid(model1);

fig_dir = file.path("..", "figures");
if (!dir.exists(fig_dir)) dir.create(fig_dir, recursive = TRUE);

pdf(file.path(fig_dir, "q3_qqplot.pdf"), width = 5.5, height = 4.4);
par(mar = c(4.2, 4.4, 3.0, 1.0));
qqnorm(uhat, main = "Normal Q-Q plot of the OLS residuals",
       pch = 20, cex = 0.6);
qqline(uhat, lwd = 2, lty = 2, col = "grey40");
dev.off();

# Two summaries of the shape, to put numbers on what the plot shows.
m2 = mean((uhat - mean(uhat))^2);
m3 = mean((uhat - mean(uhat))^3);
m4 = mean((uhat - mean(uhat))^4);

print("Part 2. Shape of the residual distribution ...");
print(c(skewness = round(m3/m2^1.5, 4),
        kurtosis = round(m4/m2^2, 4)));

# ------------------------------------------------------------------
# Parts 3 to 5 and 7: the return to education, theta
# ------------------------------------------------------------------
# Raising educ by one year lowers exper by one year, since exper is
# defined as age minus educ minus six. The combined effect is
#
#   theta = 100*[exp(beta1 - beta2 + (1 - 2*exper)*beta3) - 1].
#
# Writing the exponent as c'beta with c = (0, 1, -1, 1 - 2*exper)',
# the delta method gives the standard error as
#
#   se(theta_hat) = 100*exp(c'b) * sqrt(c' V c).
exper_grid = seq(0, 55, by = 5);

theta_grid = rep(NA, length(exper_grid));
se_grid = rep(NA, length(exper_grid));

for (j in 1:length(exper_grid)){
  cv = c(0, 1, -1, 1 - 2*exper_grid[j]);
  theta_grid[j] = 100 * (exp(sum(cv*b)) - 1);
  grad = 100 * exp(sum(cv*b)) * cv;
  se_grid[j] = sqrt(t(grad) %*% V %*% grad);
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

# For comparison: the return one would report from the education
# coefficient alone, forgetting that experience moves too.
print("Return from the education coefficient alone ...");
print(round(100*(exp(b[2]) - 1), 4));

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
