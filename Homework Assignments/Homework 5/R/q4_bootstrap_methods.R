# Lab 4, pp. 3-4: matrix OLS, three bootstrap SEs, and jackknife SE.
# X contains an intercept, x, and x^2. Each result includes all K coefficients.
lab4_resampling_se = function(y, X, B = 1000){
  N = nrow(X);
  K = ncol(X);
  b_ols = solve(t(X) %*% X) %*% (t(X) %*% y);
  uhat_ols = y - X %*% b_ols;
  Xb_ols = X %*% b_ols;

  # Nonparametric pairs bootstrap: resample the same rows of y and X.
  mat_b_pb = matrix(NA, B, K);
  for (b in 1:B){
    index_b = sample.int(N, size = N, replace = TRUE);
    y_b = y[index_b, , drop = FALSE];
    X_b = X[index_b, , drop = FALSE];
    beta_b = solve(t(X_b) %*% X_b) %*% (t(X_b) %*% y_b);
    mat_b_pb[b, ] = beta_b;
  }
  se_b_pb = apply(mat_b_pb, 2, sd);

  # Nonparametric residual bootstrap: keep X fixed, resample residuals.
  mat_b_rb = matrix(NA, B, K);
  for (b in 1:B){
    index_b = sample.int(N, size = N, replace = TRUE);
    u_b = uhat_ols[index_b, , drop = FALSE];
    y_b = Xb_ols + u_b;
    beta_b = solve(t(X) %*% X) %*% (t(X) %*% y_b);
    mat_b_rb[b, ] = beta_b;
  }
  se_b_rb = apply(mat_b_rb, 2, sd);

  # Wild bootstrap: multiply each observation's residual by a random sign.
  mat_b_wb = matrix(NA, B, K);
  for (b in 1:B){
    u_b = sign(matrix(runif(N, -1, 1))) * uhat_ols;
    y_b = Xb_ols + u_b;
    beta_b = solve(t(X) %*% X) %*% (t(X) %*% y_b);
    mat_b_wb[b, ] = beta_b;
  }
  se_b_wb = apply(mat_b_wb, 2, sd);

  # Jackknife: N leave-one-out regressions, with Lab 4's variance scaling.
  mat_b_jk = matrix(NA, N, K);
  for (b in 1:N){
    y_b = y[-b, , drop = FALSE];
    X_b = X[-b, , drop = FALSE];
    beta_b = solve(t(X_b) %*% X_b) %*% (t(X_b) %*% y_b);
    mat_b_jk[b, ] = beta_b;
  }
  bbar = apply(mat_b_jk, 2, mean);
  se_b_jk = sqrt((N-1)/N * apply(
    (mat_b_jk - matrix(1, N, 1) %*% bbar)^2, 2, sum));

  list(coefficients = b_ols, se = cbind(
    Pairs = se_b_pb, Residual = se_b_rb, Wild = se_b_wb,
    Jackknife = se_b_jk));
}
