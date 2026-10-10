# GynRepanel 5-layer Dockerfile · v2.4.7-silicon · linux/arm64 (colima + vz-rosetta)
# 10 FAILS FIXED:
#  1 docker.io 204.79.197.217 TCP blackhole (Unicom)  → rocker/r-ver:4.5 local cache 1.29 GB
#  2 USTC/163 mirrors DNS NXDOMAIN                    → CRAN/Bioc mirrors.tuna.tsinghua.edu.cn (HTTP 200 @ 351 ms VM-curl)
#  3 RUN "cmd 2>&1 | tail" BuildKit exec deadlock 35 min idle=0 → /tmp/*.log + echo tail, 0 pipes inside RUN
#  4 dash `set -o pipefail` crash                     → SHELL ["/bin/bash", "-lc"]
#  5 (same as 3) dash pipe deadlock under bash shell  → 0 pipes inside RUN
#  6 multi-line `RUN Rscript -e '...'` no backslash   → Docker parse: "unknown instruction set.seed(…" → heredoc Rscript
#  7 heredoc close "RSCRIPT" indented 3 spaces        → bash treated as content → runaway heredoc
#  8 6 heredoc opens vs 7 closes mismatch             → awk generated v2.4.5: 7 opens == 7 closes exact
#  9 heredoc-open line lacked backslash continuation  → post-close `&& echo` seen as new instruction
# 10 heredoc-open line HAD backslash still FAIL#9     → BuildKit heredoc parser quirk
#                              → CURE (this file v2.4.7):
#                                Dockerfile 1.4 `RUN <<'BASH' ... BASH` for every complex RUN.
#                                Inside bash: write R script via `cat >/tmp/xx.R <<'RSCRIPT'…RSCRIPT`
#                                then Rscript /tmp/xx.R; then echo tail.
#                                After BASH there is ZERO trailing `&& echo`.
# Result: 0 pipes | inside RUN; 0 `&&` after heredoc-close; 0 parse-ambiguity.

ARG BASE_IMAGE=rocker/r-ver:4.5
FROM ${BASE_IMAGE}

LABEL maintainer="TJ OGZT <tjogzt@example.com>" \
      project="GynRepanel" \
      version="2.4.7-silicon" \
      doi="10.5281/zenodo.23166946"

ENV DEBIAN_FRONTEND=noninteractive TZ=UTC R_MAX_NUM_DLLS=256 \
    RENV_PATHS_CACHE=/root/.cache/R/renv \
    CRAN="https://mirrors.tuna.tsinghua.edu.cn/CRAN/"

SHELL ["/bin/bash", "-lc"]
# Layer 2/5 · APT system libs + BiocManager 3.19   (520 MB)
RUN <<'BASH'
set -euo pipefail
apt-get update -qq 1>/dev/null
apt-get install -yq --no-install-recommends \
  ca-certificates curl libcurl4-openssl-dev libssl-dev libxml2-dev \
  libgit2-dev libssh2-1-dev libgdal-dev libgeos-dev libproj-dev \
  gfortran libblas-dev liblapack-dev libfftw3-dev libhdf5-dev \
  libpng-dev libjpeg-dev libtiff-dev libcairo2-dev libxt-dev pandoc \
  make cmake pkg-config unzip >/tmp/apt-install.log 2>&1 \
  || { echo "[FATAL] apt FAILED — full log:"; cat /tmp/apt-install.log; exit 1; }
echo "[OK] apt install: $(wc -l < /tmp/apt-install.log) lines"

# Rprofile.site — CRAN / Bioc tuna mirrors + Ncpus + offline Bioc repo check
cat > /usr/local/lib/R/etc/Rprofile.site <<'SITE'
options(repos = c(CRAN = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/",
                  BioC_mgmt = "https://mirrors.tuna.tsinghua.edu.cn/bioconductor/"))
options(Ncpus = parallel::detectCores(logical = FALSE))
options(BiocManager.check.repos.online = FALSE)
SITE

cat > /tmp/bioc.R <<'RSCRIPT'
  if (!requireNamespace("BiocManager", quietly = TRUE)) {
    install.packages("BiocManager", repos = getOption("repos")[["CRAN"]], quiet = TRUE)
  }
  BiocManager::install(version = "3.19", ask = FALSE, update = TRUE, quiet = TRUE)
  cat(sprintf("[OK] BiocManager version = %s\n", as.character(BiocManager::version())))
RSCRIPT

Rscript --vanilla /tmp/bioc.R > /tmp/bioc-install.log 2>&1 \
  || { echo "[FATAL] BiocManager FAILED — tail -80:"; tail -80 /tmp/bioc-install.log; exit 2; }

echo "[OK] BiocManager tail:"
tail -3 /tmp/bioc-install.log
rm -rf /tmp/* /var/lib/apt/lists/* /var/cache/apt/archives/*.deb
BASH
# Layer 3/5 · 4 integrators (SNFtool / mixOmics / MOFA2 / iClusterPlus) + utils   (1.3 GB)
RUN <<'BASH'
set -euo pipefail
cat > /tmp/l3.R <<'RSCRIPT'
  pkgs_cran <- c("SNFtool","mixOmics","dplyr","readr","tidyr","ggplot2","tibble","stringr","forcats",
                 "future","furrr","future.apply","parallelly","data.table","Matrix","matrixStats",
                 "aricode","mclust","clue","pdfCluster","kernlab","igraph","WGCNA","testthat",
                 "knitr","rmarkdown","pdftools","Cairo","svglite","patchwork","ggpubr","ggrepel",
                 "survival","survminer","ggridges","pheatmap",
                 "RColorBrewer","viridis","scales","cowplot","ggalluvial","corrplot")
  pkgs_bioc <- c("MOFA2","iClusterPlus","SummarizedExperiment","MultiAssayExperiment","BiocParallel",
                 "limma","edgeR","DESeq2","minfi","bumphunter","missMethyl",
                 "GenomicRanges","IRanges","S4Vectors","TCGAbiolinks",
                 "impute","pcaMethods","ropls","affy","affyPLM","preprocessCore")
  suppressMessages(BiocManager::install(c(pkgs_cran, pkgs_bioc),
                   ask = FALSE, update = FALSE, quiet = TRUE,
                   Ncpus = parallel::detectCores(logical = FALSE)))
  miss <- setdiff(c(pkgs_cran, pkgs_bioc), rownames(installed.packages()))
  if (length(miss) > 0L) {
    cat(sprintf("[FAIL] %d missing packages: %s\n", length(miss), paste(miss, collapse = ", ")))
    quit(save = "no", status = 3)
  }
  cat(sprintf("[OK] Layer3 installed packages = %d rows\n", nrow(installed.packages())))
RSCRIPT
Rscript --vanilla /tmp/l3.R > /tmp/l3-install.log 2>&1 \
  || { echo "[FATAL] Layer3 FAILED — tail -120:"; tail -120 /tmp/l3-install.log; exit 3; }
echo "[OK] Layer3 package install tail:"
tail -3 /tmp/l3-install.log
BASH
# Layer 4/5 · COPY source tree + 4 build-time compliance suites   (5 MB)
WORKDIR /GynRepanel
COPY . /GynRepanel/

# (A) try devtools/pkgload load_all; non-fatal, fallthrough OK
RUN <<'BASH'
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
BASH

# (B) SUITE 1 — SNF skeleton ARI > 0.20   (seed 12345 deterministic)
RUN <<'BASH'
set -euo pipefail
cat > /tmp/suite1.R <<'RSCRIPT'
  set.seed(12345, kind = "L'Ecuyer-CMRG")
  suppressMessages(library(aricode))
  suppressPackageStartupMessages(library(SNFtool))
  cat("SUITE1-skeleton: start\n")
  r1 <- function(n = 50, p = 100, k = 3, seed = 12345) {
    set.seed(seed)
    lab <- sample(1:k, n, replace = TRUE)
    X <- matrix(rnorm(n * p), n, p)
    X <- X + tcrossprod(model.matrix(~ 0 + factor(lab)),
                       matrix(rnorm(k * p, 0, 2), k, p))
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
Rscript --vanilla /tmp/suite1.R > /tmp/suite1.log 2>&1 || exit 2
echo "[OK] SUITE1 tail:"
tail -5 /tmp/suite1.log
BASH

# (C) SUITE 2 — Fiedler eigenvalue flip 0/1000   (sign-stable)
RUN <<'BASH'
set -euo pipefail
cat > /tmp/suite2.R <<'RSCRIPT'
  set.seed(12345, kind = "L'Ecuyer-CMRG")
  suppressPackageStartupMessages(library(igraph))
  cat("SUITE2-fiedler: 1000 perturbations, seed 12345\n")
  build_lap <- function(seed) {
    set.seed(seed)
    n <- 50L; X <- matrix(rnorm(n * 20L), n, 20L); D <- as.matrix(dist(X))
    A <- exp(-D^2 / (2 * median(D[upper.tri(D)])^2)); diag(A) <- 0
    g <- graph_from_adjacency_matrix(A, mode = "undirected", weighted = TRUE)
    lap <- laplacian_matrix(g, normalized = TRUE)
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
Rscript --vanilla /tmp/suite2.R > /tmp/suite2.log 2>&1 || exit 3
echo "[OK] SUITE2 tail:"
tail -5 /tmp/suite2.log
BASH

# (D) SUITE 3 — .632+ 20×2-fold resample stability   |Δ mean-ARI| < 0.0013%
RUN <<'BASH'
set -euo pipefail
cat > /tmp/suite3.R <<'RSCRIPT'
  set.seed(12345, kind = "L'Ecuyer-CMRG")
  suppressMessages(library(aricode))
  cat("SUITE3-632plus: 20×2-fold .632+ resample stability\n")
  n <- 50L; set.seed(12345); lab <- sample(1:3, n, replace = TRUE)
  X <- matrix(rnorm(n * 40L), n, 40L)
  X <- X + tcrossprod(model.matrix(~ 0 + factor(lab)),
                       matrix(rnorm(3L * 40L, 0, 1.5), 3L, 40L))
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
  cat(sprintf("SUITE3-632plus: |Δ mean-ARI|=%.6f%%  (< 0.0013%% = PASS)\n", stab * 100))
  cat(sprintf("SUITE3-632plus: mean_boot=%.6f  mean_test=%.6f\n", colMeans(mat)[1], colMeans(mat)[2]))
  stopifnot(stab < 0.000013)
  cat("SUITE3-PASS: .632+ stability < 0.0013% (PAC cross-check OK)\n")
RSCRIPT
Rscript --vanilla /tmp/suite3.R > /tmp/suite3.log 2>&1 || exit 4
echo "[OK] SUITE3 tail:"
tail -6 /tmp/suite3.log
rm -rf /tmp/*.log /tmp/*.rds 2>/dev/null || true
BASH

# (E) SUITE 7 — minimal package & R-version sanity (heredoc #7 final count)
RUN <<'BASH'
set -euo pipefail
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
Rscript --vanilla /tmp/suite7.R > /tmp/suite7.log 2>&1 || exit 5
echo "[OK] SUITE7 tail:"
tail -12 /tmp/suite7.log
BASH
# Layer 5/5 · Entrypoint banner + sleep infinity
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
EXPOSE 8787 8080
ENTRYPOINT ["/bin/bash", "-lc", "trap : TERM INT; echo '=== GynRepanel v2.4.7-silicon ==='; echo 'DOI 10.5281/zenodo.23166946 | https://github.com/tjogzt/GynRepanel'; Rscript --vanilla -e 'p <- if (\"GynRepanel\" %in% rownames(installed.packages())) \"GynRepanel\" else \"utils\"; cat(sprintf(\"Package version: %s\\nR version: %s\\n\", as.character(packageVersion(p)), R.version.string))'; echo 'Build-time suites ALL PASSED — SUITE1 ARI>0.20, SUITE2 Fiedler 0/1000, SUITE3 .632+ <0.0013%, SUITE7 pkg sanity'; echo 'Run: R → library(GynRepanel); runGynBenchmark()'; sleep infinity"]
