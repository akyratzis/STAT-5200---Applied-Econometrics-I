# STAT 5200 - Applied Econometrics I
# Homework 1, Question 1.3

X <- matrix(0, nrow = 2, ncol = 2)

for (k in 1:100) {
  D_k <- matrix(c(k, k + 1, k^2, k / 2), nrow = 2, byrow = TRUE)
  X <- X + D_k
}

print(X)
