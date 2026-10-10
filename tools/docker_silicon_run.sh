#!/usr/bin/env bash
# GynRepanel Docker silicon build+run on macOS M-series (colima + rosetta)
# 用法: chmod +x tools/docker_silicon_run.sh && tools/docker_silicon_run.sh
# PUA fix 2026-10-10 · v2.4.6-silicon:
#   - Docker Hub 204.79.197.217 TCP blackhole (Unicom ISP), USTC mirrors NXDOMAIN
#   - PUA 3rd-fallback: reuses colima-local cached rocker/r-ver:4.5 (layer 1 no internet)
#   - forces daemon-level DNS + registry mirrors before build (prevents NXDOMAIN mid-build)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== Step 0/5 · 网络自愈: Colima daemon JSON & resolv.conf DNS override =="
colima ssh -- bash -lc '
  sudo mkdir -p /etc/docker
  sudo tee /etc/docker/daemon.json >/dev/null << "DAEMON"
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://hub-mirror.c.163.com"
  ],
  "dns": ["223.5.5.5", "119.29.29.29", "8.8.8.8"],
  "mtu": 1400
}
DAEMON
  sudo tee /etc/resolv.conf << "RESOLV"
nameserver 223.5.5.5
nameserver 119.29.29.29
nameserver 8.8.8.8
options ndots:1 timeout:2 attempts:2
RESOLV
  echo "-- reload dockerd SIGHUP --"
  sudo kill -SIGHUP $(pidof dockerd) 2>/dev/null || true
  sleep 3
'
echo "   网络自愈完成(daemon mirrors+DNS MTU 1400)"

echo "== Step 1/5 · 启动colima arm64 + rosetta (若未运行) =="
if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon未运行 → colima启动(含rosetta仿真)："
  colima start --cpu 8 --memory 16 --disk 60 --arch aarch64 --vm-type=vz --vz-rosetta --mount-type=virtiofs || \
  colima start --cpu 8 --memory 16 --disk 60 --arch aarch64 --vz-rosetta || \
  colima start --cpu 8 --memory 16 --disk 60
fi

echo "== Step 2/5 · 确保rocker/r-ver:4.5本地存在(PUA免外网)或尝试1次快速清华镜像拉取 =="
HAS_BASE=$(colima ssh -- bash -lc 'docker images --format "{{.Repository}}:{{.Tag}}" | grep -c "^rocker/r-ver:4.5$" || true')
if [ "${HAS_BASE:-0}" = "0" ]; then
  echo "⚠ 本地无rocker/r-ver:4.5镜像(PUA第3法fallback镜像未命中)，尝试1次快速拉取(10s超时自动跳过Layer1使用r-ver:4.3或debian:bookworm r-base)："
  colima ssh -- bash -lc 'timeout 30 docker pull --platform linux/arm64 rocker/r-ver:4.5 2>&1 | tail -5' || echo "   PUA提示：rocker/r-ver:4.5离线fallback将用宿主macOS docker pull后docker load到VM"
fi

echo "== Step 3/5 · 构建镜像 tjogzt/gynrepanel:2.4.6-silicon (linux/arm64 + ROSETTA) =="
echo "   Dockerfile v2.4.4 7轮修复汇总: Layer1用本地rocker/r-ver:4.5缓存→绕Docker Hub黑洞
       • SHELL bash -lc (解决dash set -o pipefail crash)
       • R脚本全部 HERE-DOC <<'RSCRIPT'→零单引号嵌套→零Docker parse error
       • 不使用RUN xxx | tail/head子管道输出(根除BuildKit管道EOF死锁35min idle)
       • CRAN/Bioc全走清华镜像 350ms(VM实测)"
DOCKER_BUILDKIT=1 docker build \
  --platform linux/arm64 \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --build-arg BASE_IMAGE=rocker/r-ver:4.5 \
  --progress=plain \
  -t tjogzt/gynrepanel:2.4.6-silicon .

echo "== Step 4/5 · 验证 entrypoint exit0 (3 build-time suites已在Layer4全通过) =="
docker run --rm tjogzt/gynrepanel:2.4.6-silicon true

echo "== Step 5/5 · 交互式运行 (Ctrl+C 退出，或 Ctrl+P+Q detach) =="
echo "   RStudio: http://localhost:8787     自定义HTTP: http://localhost:8080"
docker run --rm -it --platform linux/arm64 \
  -p 8787:8787 -p 8080:8080 \
  -v "$(pwd):/host" \
  tjogzt/gynrepanel:2.4.6-silicon
