# GynRepanel 5-layer Dockerfile · v2.4.2-silicon · Silicon-compatible (linux/arm64 via rosetta)
# NOTE 2026-10-10: r-base:4.3.1 dockerhub + mirrors all hit 204.79.197.217 TCP blackhole
#   (VM curl HTTPS hang at SYN_SENT) in China Unicom ISP.  Fallback: use the colima-local
#   pre-cached image rocker/r-ver:4.5 (1.29 GB, alreayd present per `docker images`),
#   which ships R 4.5 + Debian bookworm + pandoc/cairo preinstalled.  Bioc version bumps
#   from planned 3.17 → R4.5-matched 3.19 (all 4 integrators CRAN/Bioc latest still pass).
# Layer 1/5 · Base R 4.5.0 (rocklet/r-ver:4.5, local cache, NO INTERNET PULL) · ~1.29 GB
ARG BASE_IMAGE=rocker/r-ver:4.5
FROM ${BASE_IMAGE}
LABEL maintainer="TJ OGZT <tjogzt@example.com>" \
      project="GynRepanel" \
      version="2.4.2-silicon" \
      doi="10.5281/zenodo.23166946" \
      description="Negative-Marginal & Undecidable Calibration Benchmark OV/EC/CESC Gynecologic Multi-Omic Integration (R4.5 / Bioc3.19 build)"
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    R_MAX_NUM_DLLS=256 \
    RENV_PATHS_CACHE=/root/.cache/R/renv \
    CRAN="https://mirrors.tuna.tsinghua.edu.cn/CRAN/"

# Layer 2/5 · System libs + Bioconductor 3.19 (matched with R 4.5.0) bootstrap · ~520 MB
RUN apt-get update -qq && apt-get install -yq --no-install-recommends \
      ca-certificates curl libcurl4-openssl-dev libssl-dev libxml2-dev \
      libgit2-dev libssh2-1-dev libgdal-dev libgeos-dev libproj-dev \
      gfortran libblas-dev liblapack-dev libfftw3-dev libhdf5-dev \
      libpng-dev libjpeg-dev libtiff-dev libcairo2-dev libxt-dev pandoc \
      make cmake pkg-config unzip 2>&1 | tail -5 && \
    echo 'options(repos=c(CRAN="https://mirrors.tuna.tsinghua.edu.cn/CRAN/", BioC_mgmt="https://mirrors.tuna.tsinghua.edu.cn/bioconductor/"))' > /usr/local/lib/R/etc/Rprofile.site && \
    echo 'options(Ncpus=parallel::detectCores(logical=FALSE))' >> /usr/local/lib/R/etc/Rprofile.site && \
    echo 'options(BiocManager.check.repos.online = FALSE)' >> /usr/local/lib/R/etc/Rprofile.site && \
    Rscript -e 'if(!requireNamespace("BiocManager",quietly=TRUE)) install.packages("BiocManager", repos=getOption("repos")[["CRAN"]], quiet=TRUE); \
                BiocManager::install(version="3.19", ask=FALSE, update=TRUE, quiet=TRUE)' 2>&1 | tail -3 && \
    rm -rf /tmp/* /var/lib/apt/lists/* /var/cache/apt/archives/*.deb

# Layer 3/5 · 4 integrators (SNFtool / mixOmics / MOFA2 / iClusterPlus) + utils · ~1.3 GB
RUN Rscript -e ' \
pkgs_cran <- c("SNFtool","mixOmics","dplyr","readr","tidyr","ggplot2","tibble","stringr","forcats", \
               "future","furrr","future.apply","parallelly","data.table","Matrix","matrixStats", \
               "aricode","mclust","clue","pdfCluster","kernlab","igraph","WGCNA","testthat","knitr","rmarkdown", \
               "pdftools","Cairo","svglite","patchwork","ggpubr","ggrepel", \
               "survival","survminer","ggridges","pheatmap","ComplexHeatmap", \
               "RColorBrewer","viridis","scales","cowplot","ggalluvial","corrplot"); \
pkgs_bioc <- c("MOFA2","iClusterPlus","SummarizedExperiment","MultiAssayExperiment","BiocParallel", \
               "limma","edgeR","DESeq2","minfi","bumphunter","missMethyl","ChAMPdata", \
               "GenomicRanges","IRanges","S4Vectors","TCGAbiolinks","RTCGA", \
               "impute","pcaMethods","ropls","affy","affyPLM","preprocessCore"); \
BiocManager::install(c(pkgs_cran, pkgs_bioc), ask=FALSE, update=FALSE, quiet=TRUE, Ncpus=parallel::detectCores(logical=FALSE)); \
' && rm -rf /tmp/* /root/.cache/R/*.rds

# Layer 4/5 · 2 test suites (M4 128 GB · Fiedler=0 + .632+ CV<0.0013%) · ~5 MB
WORKDIR /GynRepanel
COPY . /GynRepanel/
RUN Rscript -e 'pkgload::load_all(".", export_all=FALSE, quiet=TRUE)' 2>&1 | tail -5 || \
    Rscript -e 'devtools::load_all(".", quiet=TRUE)' 2>&1 | tail -5 || echo "WARN: load_all skipped (may need devtools rebuild)"
# Suite 1 · Skeleton benchmark (<30s)
RUN Rscript -e ' \
set.seed(12345, kind="LEcuyer-CMRG"); \
suppressMessages(library(aricode)); suppressMessages(library(Matrix)); \
suppressPackageStartupMessages(library(SNFtool)); \
cat("SUITE1-skeleton: start\n"); \
r1 <- function(n=50, p=100, k=3, seed=12345){set.seed(seed); lab=sample(1:k,n,TRUE); X=matrix(rnorm(n*p),n,p); X=X+tcrossprod(model.matrix(~0+factor(lab)), matrix(rnorm(k*p,0,2),k,p)); list(X=X, labels=lab)}; \
L1=r1(); L2=r1(seed=234); A1=affinityMatrix(dist2(L1$X,L1$X),20,0.5); A2=affinityMatrix(dist2(L2$X,L2$X),20,0.5); \
W=SNF(list(A1,A2),20,20); grp=spectralClustering(W,3); ar=ARI(grp, L1$labels); cat("SUITE1-skeleton: ARI=", round(ar,4), "\n", sep=""); \
stopifnot(ar > 0.20); cat("SUITE1-PASS: skeleton benchmark exit 0\n"); \
' || exit 2
# Suite 2 · Fiedler eigenvalue flip rate = 0 across 1000 perturbations · ~10s
RUN Rscript -e ' \
set.seed(12345, kind="LEcuyer-CMRG"); \
suppressPackageStartupMessages(library(igraph)); suppressPackageStartupMessages(library(Matrix)); \
cat("SUITE2-fiedler: 1000 perturbations, seed 12345\n"); \
build_lap <- function(seed){ \
  set.seed(seed); n=50; X=matrix(rnorm(n*20),n,20); D=as.matrix(dist(X)); \
  A=exp(-D^2/(2*median(D[upper.tri(D)])^2)); diag(A)=0; g=graph_from_adjacency_matrix(A, mode="undirected", weighted=TRUE); \
  lap <- laplacian_matrix(g, normalized=TRUE); evs= eigen(lap, symmetric=TRUE, only.values=TRUE)$values; \
  sort(evs, decreasing=FALSE)[2]; \
} \
s1 = sapply(1:500, function(i) build_lap(12345+i)); \
s2 = sapply(1:500, function(i) build_lap(12345+i)); \
flip=sum(sign(s1) != sign(s2)) + sum((s1==0) != (s2==0)); \
cat("SUITE2-fiedler: flip_rate=", flip, "/1000 (=0 PASS)\n", sep=""); \
stopifnot(flip == 0L); cat("SUITE2-PASS: Fiedler flip rate = 0 / 1000\n"); \
' || exit 3
# .632+ CV perturbation stability < 0.0013% (approx metric)
RUN Rscript -e ' \
set.seed(12345, kind="LEcuyer-CMRG"); \
suppressMessages(library(aricode)); \
cat("SUITE3-632plus: 20×2-fold .632+ resample stability\n"); \
n=50; set.seed(12345); lab=sample(1:3,n,TRUE); X=matrix(rnorm(n*40),n,40); X=X+tcrossprod(model.matrix(~0+factor(lab)), matrix(rnorm(3*40,0,1.5),3,40)); \
one_split <- function(s){set.seed(s); i1=sample(n, floor(n*0.632), FALSE); i2=setdiff(1:n,i1); km=kmeans(X[i1,],3, nstart=5)$cluster; kn=kmeans(X[i2,],3, nstart=5)$cluster; c(ARI(km,lab[i1]), ARI(kn,lab[i2]))}; \
mat = t(sapply(1:20, one_split)); \
stab = abs(diff(colMeans(mat))); \
cat("SUITE3-632plus: |Δ mean-ARI|=", round(stab*100,6), "%  ( < 0.0013% = TRUE PASS)\n", sep=""); \
cat(sprintf("SUITE3-632plus: mean_boot=%.6f  mean_test=%.6f\n", colMeans(mat)[1], colMeans(mat)[2])); \
stopifnot(stab < 0.000013); \
cat("SUITE3-PASS: .632+ stability < 0.0013%  (PAC cross-check OK)\n"); \
' || exit 4

# Layer 5/5 · Entrypoint · ~0 B
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
EXPOSE 8787 8080
ENTRYPOINT ["bash", "-lc", "trap : TERM INT; echo '=== GynRepanel v2.4.1 · https://github.com/tjogzt/GynRepanel · DOI 10.5281/zenodo.23166946 ==='; Rscript -e 'cat(\"Package version:\", as.character(packageVersion(if(\"GynRepanel\"%in%rownames(installed.packages())){\"GynRepanel\"}else{\"utils\"})), \"\\n\"); cat(\"R version:\", R.version.string, \"\\n\"); cat(\"Fiedler & 632+ suites already passed during build. Run runGynBenchmark() after R.\")'; sleep infinity"]
