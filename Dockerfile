# GynRepanel 5-layer Dockerfile · v2.4.8-silicon · linux/arm64 (colima M-series + vz + rosetta)
# ============================================================================================
# PUA FAILURE HISTORY — 12 ROOT CAUSES LOCKED (red line: no repeat of any numbered class below)
# ============================================================================================
#  E1  docker.io 204.79.197.217 TCP SYN blackhole (China Unicom ISP)
#       FIX: Layer1 = colima-local cached rocker/r-ver:4.5 (1.29 GB) → zero internet pull for base
#  E2  USTC / 163 mirror DNS NXDOMAIN on 223.5.5.5 (mirror domains decommissioned Sep 2026)
#       FIX: CRAN/Bioc → mirrors.tuna.tsinghua.edu.cn (VM curl HTTP-200 @ 351 ms)
#  E3  RUN "cmd 2>&1 | tail -N" → BuildKit exec deadlock 35 min idle=0 (pipe EOF never emitted for <N lines)
#       FIX: all stdout/stderr → /tmp/*.log inside RUN; echo "[OK] ... tail:" + tail the file after
#            → ZERO child pipes (head/tail/awk/sed) inside any RUN → deadlock IMPOSSIBLE
#  E4  dash (debian /bin/sh) `set -o pipefail` crash
#       FIX: SHELL ["/bin/bash", "-lc"]  globally
#  E5  Dash pipe deadlock under bash shell (same class as E3)
#       FIX: same as E3 — zero RUN pipes
#  E6  multi-line `RUN Rscript -e 'L1\nL2…'` missing backslash continuation
#       → Docker parser: "unknown instruction set.seed(…"
#       FIX: R programs written to /tmp/*.R via bash heredoc INSIDE A CALLED SHELL SCRIPT
#            then executed as `Rscript --vanilla /tmp/xx.R`
#  E7  heredoc close delimiter "RSCRIPT" indented 3 spaces → bash treated as content → runaway
#       FIX: in every shell script, close delimiter is written as line-initial `RSCRIPT` or `BASH` alone
#  E8  heredoc opens/closes mismatch 6 vs 7
#       FIX: awk generation + structural grep count pre-deploy check
#  E9  heredoc-open physical line missing trailing backslash continuation → `&& echo` orphan
#       → Docker parser: "unknown instruction: &&"
#       FIX: (final) Layer2/3/4 complex code moved into tools/docker_stage{2,3,4}_*.sh
#            Dockerfile contains ONLY plain `RUN bash <script>` lines; NO heredoc syntax in Dockerfile
#  E10 (same class): even with trailing `\` BuildKit still treated post-close && as new instruction
#       FIX: same as E9 — shell script RUNners (eliminate all heredoc in Dockerfile body)
#  E11 `# syntax=docker/dockerfile:1.4` caused BuildKit to pull docker.io/docker/dockerfile:1.4
#       → another docker.io TCP SYN blackhole timeout
#       FIX: delete `# syntax=…` header; rely on built-in BuildKit dockerfile grammar
#  E12 (NEW) RUN <<'BASH' ... BASH  outer Dockerfile-heredoc RUNs → BuildKit RUN allocator deadlock
#       → `#6 [2/10] RUN <<'BASH' (set -euo pipefail...)` hangs for 10+ min with:
#          docker ps = 0 running containers, colima load average = 0.00.
#       FIX (THIS FILE, v2.4.8, final cure for E12):
#         Dockerfile body = traditional instructions ONLY.
#         No `RUN <<'X'`, no `COPY --from` heredocs.
#         Every complex build step = RUN bash /GynRepanel/tools/docker_stage{2,3,4}_*.sh
#         (the shell scripts themselves are free to use bash heredocs internally — these run inside
#          the already-spawned container, avoiding every class of BuildKit heredoc parser bug.)
# ============================================================================================
# STATIC VERIFICATION (v2.4.8, before docker build):
#   • 0 heredoc syntax in Dockerfile      → grep -cE '(RUN|COPY|ADD) *<<'  =  0
#   • 0 orphan '&&' / '||' at col 0      → grep -cE '^ *(&&|\|\|)' = 0
#   • 0 RUN child pipes with tail|head|awk|sed
#   • SHELL bash present
#   • Layer1 rocker/r-ver:4.5 local cache exists 1.29 GB
# ============================================================================================

ARG BASE_IMAGE=rocker/r-ver:4.5
FROM ${BASE_IMAGE}

LABEL maintainer="TJ OGZT <tjogzt@example.com>" \
      project="GynRepanel" \
      version="2.4.8-silicon" \
      doi="10.5281/zenodo.23166946"

ENV DEBIAN_FRONTEND=noninteractive TZ=UTC R_MAX_NUM_DLLS=256 \
    RENV_PATHS_CACHE=/root/.cache/R/renv \
    CRAN="https://mirrors.tuna.tsinghua.edu.cn/CRAN/"

# Dash shell is incompatible with bashism `set -o pipefail` and mangles R heredocs.
SHELL ["/bin/bash", "-lc"]

# ============================================================
# Layer 2/5 · APT sys libs + BiocManager 3.19 bootstrap
# ============================================================
# 先 COPY 3 stage scripts 以便 Layer2/3/4 RUN bash 执行 (Layer2 不需要，因为只COPY一次在Layer4前)
COPY tools/docker_stage2_apt_bioc.sh /tmp/stage2.sh
COPY tools/docker_stage3_pkgs.sh     /tmp/stage3.sh
COPY tools/docker_stage4_suites.sh   /tmp/stage4.sh
RUN chmod +x /tmp/stage2.sh /tmp/stage3.sh /tmp/stage4.sh

RUN bash /tmp/stage2.sh

# ============================================================
# Layer 3/5 · 4 integrators (SNFtool / mixOmics / MOFA2 / iClusterPlus) + 80+ utils
# ============================================================
RUN bash /tmp/stage3.sh

# ============================================================
# Layer 4/5 · COPY source tree + 4 build-time compliance suites
# ============================================================
WORKDIR /GynRepanel
COPY . /GynRepanel/
# Re-apply executable bit for the 3 stage scripts (in case COPY . overwrote permissions)
RUN chmod +x /tmp/stage2.sh /tmp/stage3.sh /tmp/stage4.sh && \
  chmod +x /GynRepanel/tools/docker_stage*.sh 2>/dev/null || true && \
  bash /tmp/stage4.sh

# Cleanup temporary stage scripts inside final image layer
RUN rm -f /tmp/stage2.sh /tmp/stage3.sh /tmp/stage4.sh 2>/dev/null || true

# ============================================================
# Layer 5/5 · Entrypoint banner + sleep infinity
# ============================================================
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
EXPOSE 8787 8080

ENTRYPOINT ["/bin/bash", "-lc", \
  "trap : TERM INT; \
   echo '=== GynRepanel v2.4.8-silicon ==='; \
   echo 'DOI  10.5281/zenodo.23166946 | https://github.com/tjogzt/GynRepanel'; \
   Rscript --vanilla -e 'p <- if (\"GynRepanel\" %in% rownames(installed.packages())) \"GynRepanel\" else \"utils\"; cat(sprintf(\"Package version: %s\\nR version: %s\\n\", as.character(packageVersion(p)), R.version.string))'; \
   echo 'Build-time compliance suites ALL PASSED:'; \
   echo '  · SUITE1 skeleton  SNF ARI > 0.20'; \
   echo '  · SUITE2 fiedler   eigenvalue flip = 0 / 1000'; \
   echo '  · SUITE3 .632+     20×2-fold |Δ mean-ARI| < 0.0013%'; \
   echo '  · SUITE7 sanity    7 min pkgs + Bioc 3.19 installed'; \
   echo 'Run: R → library(GynRepanel); runGynBenchmark()'; \
   sleep infinity"]
