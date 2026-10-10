#!/usr/bin/env bash
# Layer 3/5 — 4 integrators (SNFtool / mixOmics / MOFA2 / iClusterPlus) + utility packages (~83 packages)
# 中文：Layer3 在Bioc基础上安装多组学整合所需全部CRAN+Bioc包
# English: Layer3 installs all CRAN + Bioconductor packages required for multi-omic integration analyses
set -euo pipefail
# Do NOT `set -x` — heavy R output would overflow BuildKit plain stdout buffer.
# All package output goes to /tmp/l3-install.log, tail printed at end.

cat > /tmp/l3.R <<'RSCRIPT'
  # Set CRAN/Bioc mirrors explicitly (Rscript --vanilla does NOT load Rprofile.site)
  # CRAN: TUNA mirror (fast from China). Bioc: official bioconductor.org (TUNA 3.22 mirror is broken — no src/contrib/PACKAGES).
  options(repos = c(CRAN = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/"))
  options(BioC_mirror = "https://bioconductor.org")
  options(Ncpus = parallel::detectCores(logical = FALSE))
  options(timeout = 1200)  # 20 min for large annotation packages (IlluminaHumanMethylationEPIC ~150MB)
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
    c(pkgs_cran, pkgs_bioc),
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
exit 0
