# =============================================================================
# STAT 5200 - Applied Econometrics I
# Homework 1, Question 1.2: matrix algebra in R
#
# (a) build the matrices A and B
# (b) compute C = A^{-1} B
# (c) print the transpose of C
# (d) contrast A %*% B with A * B
# =============================================================================

rm(list = ls())

# -- (a) the two matrices ------------------------------------------------------
# matrix() fills column by column by default; byrow = TRUE lets us type the
# entries in the same order in which they are written in the problem set.
A <- matrix(c(5, 2,
              2, 1), nrow = 2, ncol = 2, byrow = TRUE)

B <- matrix(c(5, 2,
              2, 5), nrow = 2, ncol = 2, byrow = TRUE)

cat("A =\n"); print(A)
cat("\nB =\n"); print(B)

# -- (b) C = A^{-1} B ----------------------------------------------------------
# A is invertible because det(A) = 5 * 1 - 2 * 2 = 1 != 0.
cat("\ndet(A) =", det(A), "\n")

A_inv <- solve(A)          # solve(A) returns the inverse of A
C     <- A_inv %*% B       # %*% is matrix multiplication

# solve(A, B) computes A^{-1} B directly and is numerically preferable to
# forming the inverse explicitly; we verify that the two agree.
stopifnot(all.equal(C, solve(A, B)))

cat("\nA^{-1} =\n"); print(A_inv)
cat("\nC = A^{-1} B =\n"); print(C)

# -- (c) transpose of C --------------------------------------------------------
cat("\nt(C) =\n"); print(t(C))

# -- (d) A %*% B versus A * B --------------------------------------------------
# %*% is the matrix product: (A %*% B)[i, j] = sum_k A[i, k] * B[k, j].
# *   is the Hadamard (element-wise) product: (A * B)[i, j] = A[i, j] * B[i, j].
cat("\nA %*% B (matrix product) =\n");       print(A %*% B)
cat("\nA * B (element-wise product) =\n");   print(A * B)

# The two coincide only in special cases; here they differ.
cat("\nIdentical?", identical(A %*% B, A * B), "\n")

# Element-wise multiplication also recycles, so it is defined for conformable
# but non-square shapes where %*% would fail (and vice versa).
cat("\nA * B computed by hand, entry (1,1):", A[1, 1] * B[1, 1], "\n")
cat("A %*% B computed by hand, entry (1,1):",
    A[1, 1] * B[1, 1] + A[1, 2] * B[2, 1], "\n")
