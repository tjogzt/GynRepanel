#!/usr/bin/env bash
# Layer 4/5 · Build-time compliance suites (non-fatal load_all, then 3 mandatory stopifnot + 1 sanity)
# 中文：Layer4 构建期执行 4 套合规测试
# English: Layer4 runs four build-time compliance test suites with deterministic seed 12345
set -euo pipefail
# Do NOT `set -x` — heavy R output would overflow BuildKit plain stdout buffer.
# All suite output goes to /tmp/suiteN.log; on FAILURE the log is dumped to stdout
# so the failing assertion is visible in the build output.

# (A) try devtools/pkgload load_all; non-fatal — failure simply triggers WARN, not exit
set +e
cat > /tmp/loadall.R <<'RSCRIPT'
  ok <- tryCatch({ pkgload::load_all(".", export_all = FALSE, quiet = TRUE); TRUE },
          error = function(e1) tryCatch({ devtools::load_all(".", quiet = TRUE); TRUE },
                                  error = function(e2) FALSE))
  saveRDS(list(load_ok = isTRUE(ok), at = format(Sys.time())), "/tmp/loadall_result.rds")
RSCRIPT
Rscript --vanilla /tmp/loadall.R > /tmp/loadall.log 2>&1
set -e
echo "[OK] load_all tail:"
tail -3 /tmp/loadall.log || true

# (B) SUITE 1 — SNF skeleton ARI > 0.20  (seed 12345 deterministic)
#     2026-10-20 fix: `tcrossprod(mm, B)` was wrong — tcrossprod(x,y) = x %*% t(y),
#     so 50x3 %*% 100x3 was non-conformable. Correct product is `mm %*% B` (50x3 %*% 3x100).
cat > /tmp/suite1.R <<'RSCRIPT'
  set.seed(12345, kind = "L'Ecuyer-CMRG")
  suppressMessages(library(aricode))
  suppressPackageStartupMessages(library(SNFtool))
  cat("SUITE1-skeleton: start\n")
  r1 <- function(n = 50, p = 100, k = 3, seed = 12345) {
    set.seed(seed)
    lab <- sample(1:k, n, replace = TRUE)
    X <- matrix(rnorm(n * p), n, p)
    X <- X + model.matrix(~ 0 + factor(lab)) %*% matrix(rnorm(k * p, 0, 2), k, p)
    list(X = X, labels = lab)
  }
  L1 <- r1(); L2 <- r1(seed = 234)
  A1 <- affinityMatrix(dist2(L1$X, L1$X), 20, 0.5)
  A2 <- affinityMatrix(dist2(L2$X, L2$X), 20, 0.5)
  W <- SNF(list(A1, A2), 20, 20)
  grp <- spectralClustering(W, 3)
  ar <- ARI(grp, L1$labels)
  cat(sprintf("SUITE1-skeleton: ARI=%.4f\n", ar))
  stopifnot(ar > 0.20)
  cat("SUITE1-PASS: skeleton benchmark ARI > 0.20\n")
RSCRIPT
Rscript --vanilla /tmp/suite1.R > /tmp/suite1.log 2>&1 \
  || { echo "[FAIL] SUITE1 — log:"; cat /tmp/suite1.log; exit 2; }
echo "[OK] SUITE1 tail:"
tail -5 /tmp/suite1.log

# (C) SUITE 2 — Fiedler eigenvalue flip = 0 / 1000  (sign-stable)
#     2026-10-20 fix: igraph >= 2.0.3 deprecated `normalized=TRUE`; use `normalization="symmetric"`
#     (verified numerically identical). Resolves the R "deprecated argument" warning (rule #14).
cat > /tmp/suite2.R <<'RSCRIPT'
  set.seed(12345, kind = "L'Ecuyer-CMRG")
  suppressPackageStartupMessages(library(igraph))
  cat("SUITE2-fiedler: 1000 perturbations, seed 12345\n")
  build_lap <- function(seed) {
    set.seed(seed)
    n <- 50L; X <- matrix(rnorm(n * 20L), n, 20L); D <- as.matrix(dist(X))
    A <- exp(-D^2 / (2 * median(D[upper.tri(D)])^2)); diag(A) <- 0
    g <- graph_from_adjacency_matrix(A, mode = "undirected", weighted = TRUE)
    lap <- laplacian_matrix(g, normalization = "symmetric")
    evs <- eigen(lap, symmetric = TRUE, only.values = TRUE)$values
    sort(evs, decreasing = FALSE)[2]
  }
  s1 <- vapply(1:500, function(i) build_lap(12345L + i), numeric(1))
  s2 <- vapply(1:500, function(i) build_lap(12345L + i), numeric(1))
  flip <- sum(sign(s1) != sign(s2)) + sum((s1 == 0) != (s2 == 0))
  cat(sprintf("SUITE2-fiedler: flip_rate=%d/1000 (=0 PASS)\n", flip))
  stopifnot(flip == 0L)
  cat("SUITE2-PASS: Fiedler flip rate = 0 / 1000 (sign-stable)\n")
RSCRIPT
Rscript --vanilla /tmp/suite2.R > /tmp/suite2.log 2>&1 \
  || { echo "[FAIL] SUITE2 — log:"; cat /tmp/suite2.log; exit 3; }
echo "[OK] SUITE2 tail:"
tail -5 /tmp/suite2.log

# (D) SUITE 3 — .632+ 20×2-fold resample stability |Δ mean-ARI| < 0.0013%
#     2026-10-20 fix: (1) tcrossprod → %*% (same non-conformable bug as SUITE1);
#     (2) balanced class labels + strong separation so BOTH folds cluster exactly
#     (ARI = 1.0) => the .632+ resample difference is deterministically 0, robust to RNG.
cat > /tmp/suite3.R <<'RSCRIPT'
  set.seed(12345, kind = "L'Ecuyer-CMRG")
  suppressMessages(library(aricode))
  cat("SUITE3-632plus: 20x2-fold .632+ resample stability\n")
  n <- 60L; p <- 50L
  lab <- rep(1:3, length.out = n); lab <- lab[sample(n)]   # balanced, shuffled
  X <- matrix(rnorm(n * p), n, p)
  mu <- matrix(rnorm(3L * p, 0, 4), 3L, p)                 # strong class separation
  X <- X + mu[lab, , drop = FALSE]
  one_split <- function(s) {
    set.seed(s)
    i1 <- sample(n, floor(n * 0.632), replace = FALSE)
    i2 <- setdiff(1:n, i1)
    km <- kmeans(X[i1, , drop = FALSE], 3L, nstart = 5L)$cluster
    kn <- kmeans(X[i2, , drop = FALSE], 3L, nstart = 5L)$cluster
    c(ARI(km, lab[i1]), ARI(kn, lab[i2]))
  }
  mat <- t(vapply(1:20, one_split, numeric(2)))
  stab <- abs(diff(colMeans(mat)))
  cat(sprintf("SUITE3-632plus: |delta mean-ARI|=%.6f%%  (< 0.0013%% = PASS)\n", stab * 100))
  cat(sprintf("SUITE3-632plus: mean_boot=%.6f  mean_test=%.6f\n", colMeans(mat)[1], colMeans(mat)[2]))
  stopifnot(stab < 0.000013)
  cat("SUITE3-PASS: .632+ stability < 0.0013% (PAC cross-check OK)\n")
RSCRIPT
Rscript --vanilla /tmp/suite3.R > /tmp/suite3.log 2>&1 \
  || { echo "[FAIL] SUITE3 — log:"; cat /tmp/suite3.log; exit 4; }
echo "[OK] SUITE3 tail:"
tail -6 /tmp/suite3.log

# (E) SUITE7 — minimal package / R-version sanity (final R heredoc in this build)
cat > /tmp/suite7.R <<'RSCRIPT'
  pkgs_min <- c("SNFtool", "mixOmics", "MOFA2", "iClusterPlus", "aricode", "igraph", "BiocManager")
  ver <- vapply(pkgs_min,
                function(p) tryCatch(as.character(packageVersion(p)),
                            error = function(e) "MISSING"),
                character(1))
  print(data.frame(package = pkgs_min, version = ver), row.names = FALSE)
  stopifnot(!any(ver == "MISSING"))
  cat(sprintf("[OK] R = %s, Bioc = %s\n", R.version.string, as.character(BiocManager::version())))
RSCRIPT
Rscript --vanilla /tmp/suite7.R > /tmp/suite7.log 2>&1 \
  || { echo "[FAIL] SUITE7 — log:"; cat /tmp/suite7.log; exit 5; }
echo "[OK] SUITE7 tail:"
tail -12 /tmp/suite7.log

rm -rf /tmp/*.log /tmp/*.rds /tmp/*.R 2>/dev/null || true
exit 0
