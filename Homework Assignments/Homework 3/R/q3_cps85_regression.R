# ==================================================================
# STAT 5200 - Applied Econometrics I
# Homework 3, Question 3: the CPS85 wage equation
#
# Follows Lab Notes 02, using the same data set:
#
#   log(wage_i) = beta0 + beta1*educ_i + beta2*exper_i
#                 + beta3*exper_i^2 + u_i
#
# The questions asked are
#   (1) estimate the model by OLS,
#   (2) a normal quantile plot of the residuals,
#   (3) to (5) the return to education theta, its estimator, and its
#       value across exper = 0, 5, ..., 55,
#   (6) how standard errors and confidence intervals would be built,
#   (7) those standard errors and intervals (optional).
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
dat = read.csv(data_path);
