# ==================================================================
# STAT 5200 - Applied Econometrics I
# Homework 3, Question 4: Monte Carlo simulation and coverage rate
#
# Population model:
#
#   y = beta0 + beta1*x + beta2*x^2 + u,
#   beta0 = 1, beta1 = 1, beta2 = 0.2,
#   u ~ t(7),  x ~ N(1,4),  N = 100.
#
# For each of M = 10,000 data sets we estimate beta by OLS, build a
# 95% confidence interval for beta1 from the asymptotic distribution
# derived in Q2(2), and record whether it contains the true beta1.
# The average of that indicator is the empirical coverage rate.
#
# Part 5 repeats the exercise with the error scaled by |x|/2, which
# makes the model heteroskedastic.
# ==================================================================

rm(list = ls()); # refresh memory
# seed for the random number generator
my_random_seed = 1; set.seed(my_random_seed);

# model parameters
beta0 = 1;
beta1 = 1;
beta2 = 0.2;

N = 100;      # observations per data set
M = 10000;    # number of simulated data sets
