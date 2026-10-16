rm(list = ls()); # refresh memory

cps85 = read.csv(file.path("..", "..", "..", "Datasets & Labs", "Lab 2",
                           "CPS85.txt"));
attach(cps85);

# ------------------------------------------------------------------
# Part 1: estimating the wage equation
# ------------------------------------------------------------------
exper2 = exper^2;

model1 = lm(formula = logwage ~ educ + exper + exper2);

print("Part 1. OLS estimates of the wage equation ...");
print(summary(model1));

b = coef(model1);
V = vcov(model1);   # estimated covariance matrix of b, for the delta method

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

# ------------------------------------------------------------------
# Parts 3 to 5: the return to education, theta
# ------------------------------------------------------------------
#   theta = 100*[exp(beta1 - beta2 + (1 - 2*exper)*beta3) - 1]
#
# where b[2], b[3], b[4] are beta1, beta2, beta3.
exper_grid = seq(0, 55, by = 5);
theta_grid = rep(NA, length(exper_grid));

for (j in 1:length(exper_grid)){
  theta_grid[j] = 100 * (exp(b[2] - b[3]
                             + (1 - 2*exper_grid[j])*b[4]) - 1);
}

print("Part 5. theta_hat across experience ...");
print(data.frame(exper = exper_grid, theta_hat = round(theta_grid, 4)),
      row.names = FALSE);

# For comparison: the return one would report from the education
# coefficient alone, forgetting that experience moves too.
print("Return from the education coefficient alone ...");
print(round(100*(exp(b[2]) - 1), 4));

# ------------------------------------------------------------------
# Figure: theta_hat against experience
# ------------------------------------------------------------------
pdf(file.path(fig_dir, "q3_theta_by_exper.pdf"),
    width = 5.8, height = 4.4);
par(mar = c(4.2, 4.4, 1.0, 1.0));
plot(exper_grid, theta_grid, type = "b", pch = 19,
     xlab = "years of experience",
     ylab = expression("estimated return to education, " * hat(theta) * " (%)"));
dev.off();

# ------------------------------------------------------------------
# Part 7 (optional): standard errors and confidence intervals
# ------------------------------------------------------------------
# By the delta method, with theta = 100*[exp(c'beta) - 1] and
# c = (0, 1, -1, 1 - 2*exper)', the gradient is 100*exp(c'b)*c and
#
#   se(theta_hat) = sqrt(grad' V grad).
se_grid = rep(NA, length(exper_grid));

for (j in 1:length(exper_grid)){
  cv = c(0, 1, -1, 1 - 2*exper_grid[j]);
  grad = 100 * exp(sum(cv*b)) * cv;
  se_grid[j] = sqrt(t(grad) %*% V %*% grad);
}

lci = theta_grid - 1.96*se_grid;   # 95% confidence interval
uci = theta_grid + 1.96*se_grid;

print("Part 7. Standard errors and 95% confidence intervals ...");
print(data.frame(exper = exper_grid,
                 theta_hat = round(theta_grid, 4),
                 se = round(se_grid, 4),
                 lower = round(lci, 4),
                 upper = round(uci, 4)), row.names = FALSE);

# ------------------------------------------------------------------
# Figure: theta_hat with the confidence band
# ------------------------------------------------------------------
pdf(file.path(fig_dir, "q3_theta_ci.pdf"), width = 5.8, height = 4.4);
par(mar = c(4.2, 4.4, 1.0, 1.0));
plot(exper_grid, theta_grid, type = "b", pch = 19,
     ylim = range(c(lci, uci)),
     xlab = "years of experience",
     ylab = expression("estimated return to education, " * hat(theta) * " (%)"));
lines(exper_grid, lci, lty = 2, col = "grey40");
lines(exper_grid, uci, lty = 2, col = "grey40");
legend("topright", bty = "n",
       legend = c(expression(hat(theta)), "95% confidence interval"),
       pch = c(19, NA), lty = c(1, 2),
       col = c("black", "grey40"));
dev.off();

print("Figures written to ...");
print(normalizePath(fig_dir));

detach(cps85);
