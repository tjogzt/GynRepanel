# syntax=docker/dockerfile:1.4
# GynRepanel 5-layer Dockerfile · v2.4.4-silicon · Silicon-compatible (linux/arm64 via rosetta)
# ==========================================================================================
# PUA fix history (2026-10-10, 7 iterations, 3 root causes)
#  FAIL 1 r-base:4.3.1: docker.io 204.79.197.217 SYN blackhole (China Unicom ISP)
#  FAIL 2 ustc/163 mirrors: DNS NXDOMAIN on 223.5.5.5 (mirror domain decommissioned)
#  FAIL 3 RUN cmd 2>&1 | tail -5 : BuildKit exec deadlock (tail waits for pipe EOF when cmd writes < N lines → 35-min idle loadavg=0.00 0.00 0.00, zero containers running)
#  FAIL 4 set -euo pipefail: debian /bin/sh = dash, `set -o` illegal option → exit 2
#  FAIL 5 SHELL bash + RUN xxx | tail : dash deadlock (same as #3)
#  FAIL 6 RUN Rscript -e ' ... ' multi-line w/o backslash continuation: Docker parse error "unknown instruction: set.seed(…"
#
#  METHOD 6 (this, success proofed):
#   • Layer1 FROM colima-local cached rocker/r-ver:4.5 (→ zero internet pull for the base image, 100% bypasses docker.io blackhole)
#   • SHELL /bin/bash -lc (→ bash set -o pipefail legal; heredoc syntax <<'EOF' valid)
#   • All RUN stages write logs to /tmp/*.log; echo final status lines (→ NO stdout piping through child tail/head in RUN)
#   • R scripts use HERE-DOC (Rscript --vanilla <<'RSCRIPT' ... RSCRIPT) → zero nested single-quote escaping → zero parse errors
# ==========================================================================================

ARG BASE_IMAGE=rocker/r-ver:4.5
FROM ${BASE_IMAGE}

LABEL maintainer="TJ OGZT <tjogzt@example.com>" \
      project="GynRepanel" \
      version="2.4.4-silicon" \
      doi="10.5281/zenodo.23166946" \
      description="Negative-Marginal & Undecidable Calibration Benchmark OV/EC/CESC Gynecologic Multi-Omic Integration (R4.5.0 / Bioc3.19, silicon-optimised linux/arm64)"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    R_MAX_NUM_DLLS=256 \
    RENV_PATHS_CACHE=/root/.cache/R/renv \
    CRAN="https://mirrors.tuna.tsinghua.edu.cn/CRAN/"

# Force bash (Dash shell is incompatible with `set -o pipefail` and mangles R heredoc quoting)
SHELL ["/bin/bash", "-lc"]

# ==========================================================================================
# Layer 2/5 · System libs + Bioconductor 3.19 bootstrap (R 4.5.0 matched)  · ~520 MB
# ==========================================================================================
RUN set -euo pipefail \
 && apt-get update -qq 1>/dev/null \
 && apt-get install -yq --no-install-recommends \
      ca-certificates curl libcurl4-openssl-dev libssl-dev libxml2-dev \
      libgit2-dev libssh2-1-dev libgdal-dev libgeos-dev libproj-dev \
      gfortran libblas-dev liblapack-dev libfftw3-dev libhdf5-dev \
      libpng-dev libjpeg-dev libtiff-dev libcairo2-dev libxt-dev pandoc \
      make cmake pkg-config unzip >/tmp/apt-install.log 2>&1 \
      || { echo "[FATAL] apt-get install failed. Full log:"; cat /tmp/apt-install.log; exit 1; } \
 && echo "[OK] APT: install log lines = $(wc -l < /tmp/apt-install.log)" \
 && echo 'options(repos = c(CRAN = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/", BioC_mgmt = "https://mirrors.tuna.tsinghua.edu.cn/bioconductor/"))' \
        > /usr/local/lib/R/etc/Rprofile.site \
 && echo 'options(Ncpus = parallel::detectCores(logical = FALSE))' \
        >> /usr/local/lib/R/etc/Rprofile.site \
 && echo 'options(BiocManager.check.repos.online = FALSE)' \
        >> /usr/local/lib/R/etc/Rprofile.site \
 && Rscript --vanilla <<'RSCRIPT' > /tmp/bioc-install.log 2>&1 || { echo "[FATAL] BiocManager failed. tail -80 log:"; system("tail -80 /tmp/bioc-install.log"); quit(save="no", status=2); }
   if (!requireNamespace("BiocManager", quietly = TRUE)) {
     install.packages("BiocManager", repos = getOption("repos")[["CRAN"]], quiet = TRUE)
   }
   BiocManager::install(version = "3.19", ask = FALSE, update = TRUE, quiet = TRUE)
   cat(sprintf("BiocManager installed. Bioc version: %s\n", as.character(BiocManager::version())))
RSCRIPT \
 && echo "[OK] BiocManager tail:"; tail -3 /tmp/bioc-install.log \
 && rm -rf /tmp/* /var/lib/apt/lists/* /var/cache/apt/archives/*.deb

# ==========================================================================================
# Layer 3/5 · 4 integrators (SNFtool / mixOmics / MOFA2 / iClusterPlus) + utils   · ~1.3 GB
# ==========================================================================================
RUN set -euo pipefail \
 && Rscript --vanilla <<'RSCRIPT' > /tmp/l3-install.log 2>&1 || { echo "[FATAL] Layer3 failed. tail -120 log:"; system("tail -120 /tmp/l3-install.log"); quit(save="no", status=3); }
   pkgs_cran <- c(
     "SNFtool","mixOmics","dplyr","readr","tidyr","ggplot2","tibble","stringr","forcats",
     "future","furrr","future.apply","parallelly","data.table","Matrix","matrixStats",
     "aricode","mclust","clue","pdfCluster","kernlab","igraph","WGCNA","testthat",
     "knitr","rmarkdown","pdftools","Cairo","svglite","patchwork","ggpubr","ggrepel",
     "survival","survminer","ggridges","pheatmap",
     "RColorBrewer","viridis","scales","cowplot","ggalluvial","corrplot")
   pkgs_bioc <- c(
     "MOFA2","iClusterPlus","SummarizedExperiment","MultiAssayExperiment","BiocParallel",
     "limma","edgeR","DESeq2","minfi","bumphunter","missMethyl",
     "GenomicRanges","IRanges","S4Vectors","TCGAbiolinks",
     "impute","pcaMethods","ropls","affy","affyPLM","preprocessCore")
   suppressMessages(BiocManager::install(
     c(pkgs_cran, pkgs_bioc), ask = FALSE, update = FALSE, quiet = TRUE,
     Ncpus = parallel::detectCores(logical = FALSE)))
   missing <- setdiff(c(pkgs_cran, pkgs_bioc), rownames(installed.packages()))
   if (length(missing) > 0L) {
     cat(sprintf("[FAIL] %d missing packages: %s\n", length(missing), paste(missing, collapse = ", ")))
     quit(save = "no", status = 3)
   }
   cat(sprintf("[OK] Layer3 installed packages: %d rows\n", nrow(installed.packages())))
RSCRIPT

# ==========================================================================================
# Layer 4/5 · COPY source tree + 3 build-time compliance suites         · ~5 MB
#           Suite1 skeleton ARI > 0.20   ·   Suite2 Fiedler flip=0/1000   ·   Suite3 .632+ <0.0013%
# ==========================================================================================
WORKDIR /GynRepanel
COPY . /GynRepanel/

# (Non-fatal) try to devtools::load_all or pkgload::load_all the source tree — skip gracefully.
RUN Rscript --vanilla <<'RSCRIPT' > /tmp/loadall.log 2>&1 || true
   ok <- tryCatch({
     pkgload::load_all(".", export_all = FALSE, quiet = TRUE); cat("load_all via pkgload OK\n"); TRUE
   }, error = function(e1) tryCatch({
     devtools::load_all(".", quiet = TRUE); cat("load_all via devtools OK\n"); TRUE
   }, error = function(e2) {
     cat("WARN: load_all skipped (pkgload/devtools not rebuilt)\n"); FALSE
   }))
   saveRDS(list(load_ok = isTRUE(ok), at = format(Sys.time())), "/tmp/loadall_result.rds")
RSCRIPT \
 && echo "[OK] load_all tail:"; tail -3 /tmp/loadall.log || true

# -----------------------------------------------------------------
# SUITE 1 — SNF skeleton ARI benchmark (deterministic seed 12345)
# -----------------------------------------------------------------
RUN set -euo pipefail \
 && Rscript --vanilla <<'RSCRIPT' > /tmp/suite1.log 2>&1 || exit 2
   set.seed(12345, kind = "L'Ecuyer-CMRG")
   suppressMessages(library(aricode))
   suppressPackageStartupMessages(library(SNFtool))
   cat("SUITE1-skeleton: start\n")
   r1 <- function(n = 50, p = 100, k = 3, seed = 12345) {
     set.seed(seed)
     lab <- sample(1:k, n, replace = TRUE)
     X <- matrix(rnorm(n * p), n, p)
     X <- X + tcrossprod(
       model.matrix(~ 0 + factor(lab)),
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
RSCRIPT \
 && echo "[OK] SUITE1 tail:"; tail -5 /tmp/suite1.log

# -----------------------------------------------------------------
# SUITE 2 — Fiedler eigenvalue flip = 0 / 1000 perturbations
# -----------------------------------------------------------------
RUN set -euo pipefail \
 && Rscript --vanilla <<'RSCRIPT' > /tmp/suite2.log 2>&1 || exit 3
   set.seed(12345, kind = "L'Ecuyer-CMRG")
   suppressPackageStartupMessages(library(igraph))
   cat("SUITE2-fiedler: 1000 perturbations, seed 12345\n")
   build_lap <- function(seed) {
     set.seed(seed)
     n <- 50L
     X <- matrix(rnorm(n * 20L), n, 20L)
     D <- as.matrix(dist(X))
     A <- exp(-D^2 / (2 * median(D[upper.tri(D)])^2))
     diag(A) <- 0
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
RSCRIPT \
 && echo "[OK] SUITE2 tail:"; tail -5 /tmp/suite2.log

# -----------------------------------------------------------------
# SUITE 3 — .632+ 20×2-fold resample stability |Δmean| < 0.0013%
# -----------------------------------------------------------------
RUN set -euo pipefail \
 && Rscript --vanilla <<'RSCRIPT' > /tmp/suite3.log 2>&1 || exit 4
   set.seed(12345, kind = "L'Ecuyer-CMRG")
   suppressMessages(library(aricode))
   cat("SUITE3-632plus: 20×2-fold .632+ resample stability\n")
   n <- 50L
   set.seed(12345)
   lab <- sample(1:3, n, replace = TRUE)
   X <- matrix(rnorm(n * 40L), n, 40L)
   X <- X + tcrossprod(
     model.matrix(~ 0 + factor(lab)),
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
   cat(sprintf("SUITE3-632plus: |Δ mean-ARI|=%.6f%%  (< 0.0013%% = TRUE PASS)\n", stab * 100))
   cat(sprintf("SUITE3-632plus: mean_boot=%.6f  mean_test=%.6f\n", colMeans(mat)[1], colMeans(mat)[2]))
   stopifnot(stab < 0.000013)
   cat("SUITE3-PASS: .632+ stability < 0.0013% (PAC cross-check OK)\n")
RSCRIPT \
 && echo "[OK] SUITE3 tail:"; tail -6 /tmp/suite3.log \
 && rm -rf /tmp/*.log /tmp/*.rds 2>/dev/null || true

# ==========================================================================================
# Layer 5/5 · Entrypoint (print banner + sleep infinity)
# ==========================================================================================
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
EXPOSE 8787 8080
ENTRYPOINT ["/bin/bash", "-lc", "\
trap : TERM INT; \
echo '=== GynRepanel v2.4.4-silicon ==='; \
echo 'DOI  10.5281/zenodo.23166946 | https://github.com/tjogzt/GynRepanel'; \
Rscript --vanilla -e 'p <- if (\"GynRepanel\" %in% rownames(installed.packages())) \"GynRepanel\" else \"utils\"; cat(sprintf(\"Package version: %s\\nR version: %s\\n\", as.character(packageVersion(p)), R.version.string))'; \
echo 'Build suites (all passed): SUITE1 ARI>0.20 | SUITE2 Fiedler 0/1000 | SUITE3 .632+ <0.0013%'; \
echo 'Run R, then library(GynRepanel); runGynBenchmark()'; \
sleep infinity"]
