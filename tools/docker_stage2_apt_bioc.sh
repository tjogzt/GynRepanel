#!/usr/bin/env bash
# Layer 2/5 — APT system libs + BiocManager 3.22 bootstrap
# 中英文双语说明:
#   本脚本在容器内作为 Layer2 的 RUN 命令，安装系统依赖 + 配置清华CRAN/Bioc镜像 + 安装BiocManager 3.22 (R4.5.0匹配)
#   This script runs inside the container as Layer 2 RUN: install system deps, configure tuna CRAN/Bioc mirrors, install BiocManager 3.22 matched to R 4.5.0
set -euo pipefail
# NOTE: do NOT `set -x` — under BuildKit --progress=plain the 65535-byte
#       stdout log buffer can fill up when apt/R emits thousands of lines,
#       causing the child write() to block forever (BuildKit exec deadlock).
#       Instead every heavy command writes its output to /tmp/*.log and we
#       tail the last N lines to BuildKit stdout as observability.

# --- PUA fix: switch apt sources to TUNA mirror (ubuntu-ports for arm64) ---
# Ubuntu official ports.ubuntu.com TCP connections hang from China Unicom.
# TUNA mirror is fast (HTTP 200 < 400ms) and reliable.
# Also set apt timeouts to prevent indefinite hangs on slow mirrors.
cat > /etc/apt/apt.conf.d/99timeout <<'APTCONF'
Acquire::http::Timeout "30";
Acquire::https::Timeout "30";
Acquire::ftp::Timeout "30";
Acquire::Retries "3";
Acquire::http::Pipeline-Depth "0";
APTCONF

# Replace sources with TUNA ubuntu-ports mirror (arm64)
cat > /etc/apt/sources.list.d/ubuntu.sources <<'SOURCES'
Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
SOURCES
# Remove old sources to avoid duplicates
rm -f /etc/apt/sources.list

apt-get update -qq 1>/dev/null
apt-get install -yq --no-install-recommends \
  ca-certificates curl libcurl4-openssl-dev libssl-dev libxml2-dev \
  libgit2-dev libssh2-1-dev libgdal-dev libgeos-dev libproj-dev \
  gfortran libblas-dev liblapack-dev libfftw3-dev libhdf5-dev \
  libpng-dev libjpeg-dev libtiff-dev libcairo2-dev libxt-dev pandoc \
  make cmake pkg-config unzip > /tmp/apt-install.log 2>&1 \
  || { echo "[FATAL] apt FAILED — full log:"; cat /tmp/apt-install.log; exit 1; }
echo "[OK] apt install: $(wc -l < /tmp/apt-install.log) lines"

# Rprofile.site — 清华 tuna CRAN + Bioc 镜像 + CPU 物理核数并行
#                  TUNA mirrors + parallel on physical cores
cat > /usr/local/lib/R/etc/Rprofile.site <<'SITE'
options(repos = c(CRAN = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/",
                  BioC_mgmt = "https://mirrors.tuna.tsinghua.edu.cn/bioconductor/"))
options(Ncpus = parallel::detectCores(logical = FALSE))
options(BiocManager.check.repos.online = FALSE)
SITE

cat > /tmp/bioc.R <<'RSCRIPT'
  # Set CRAN/Bioc mirrors explicitly (Rscript --vanilla does NOT load Rprofile.site)
  options(repos = c(CRAN = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/",
                    BioC_mgmt = "https://mirrors.tuna.tsinghua.edu.cn/bioconductor/"))
  options(Ncpus = parallel::detectCores(logical = FALSE))
  if (!requireNamespace("BiocManager", quietly = TRUE)) {
    install.packages("BiocManager", repos = getOption("repos")[["CRAN"]], quiet = TRUE)
  }
  BiocManager::install(version = "3.22", ask = FALSE, update = TRUE, quiet = TRUE)
  cat(sprintf("[OK] BiocManager version = %s\n", as.character(BiocManager::version())))
RSCRIPT

Rscript --vanilla /tmp/bioc.R > /tmp/bioc-install.log 2>&1 \
  || { echo "[FATAL] BiocManager FAILED — tail -80:"; tail -80 /tmp/bioc-install.log; exit 2; }
echo "[OK] BiocManager tail:"
tail -3 /tmp/bioc-install.log
rm -rf /tmp/* /var/lib/apt/lists/* /var/cache/apt/archives/*.deb
exit 0
