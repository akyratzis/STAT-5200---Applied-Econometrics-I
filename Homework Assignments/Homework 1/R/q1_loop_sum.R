# =============================================================================
# STAT 5200 - Applied Econometrics I
# Homework 1, Question 1.3: accumulate a matrix sum with a for loop
#
#            100
#      X =   sum   D_k,     D_k = [ k      k + 1 ]
#            k=1                  [ k^2    k / 2 ]
# =============================================================================

rm(list = ls())

K <- 100

# Initialise the accumulator at the zero matrix, then add one D_k per iteration.
X <- matrix(0, nrow = 2, ncol = 2)

for (k in 1:K) {
  D_k <- matrix(c(k,     k + 1,
                  k^2,   k / 2), nrow = 2, ncol = 2, byrow = TRUE)
  X <- X + D_k
}

cat("X = sum_{k=1}^{", K, "} D_k =\n", sep = "")
print(X)

# -- Check against the closed-form expressions ---------------------------------
# sum k     = K(K+1)/2
# sum (k+1) = K(K+1)/2 + K
# sum k^2   = K(K+1)(2K+1)/6
# sum k/2   = K(K+1)/4
X_closed <- matrix(c(K * (K + 1) / 2,             K * (K + 1) / 2 + K,
                     K * (K + 1) * (2 * K + 1) / 6, K * (K + 1) / 4),
                   nrow = 2, ncol = 2, byrow = TRUE)

cat("\nClosed-form value =\n")
print(X_closed)

stopifnot(all.equal(X, X_closed))
cat("\nLoop and closed-form results agree.\n")
