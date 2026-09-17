# STAT 5200 - Applied Econometrics I
# Homework 1, Question 1.2

# (a) the two matrices
A <- matrix(c(5, 2,
              2, 1), nrow = 2, byrow = TRUE)

B <- matrix(c(5, 2,
              2, 5), nrow = 2, byrow = TRUE)

print(A)
print(B)

# (b) C = A^{-1} B
C <- solve(A) %*% B
print(C)

# (c) transpose of C
print(t(C))

# (d) matrix product versus element-wise product
print(A %*% B)
print(A * B)
