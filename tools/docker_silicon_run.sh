#!/usr/bin/env bash
# GynRepanel Docker silicon build+run on macOS M-series (colima + rosetta)
# 用法: chmod +x tools/docker_silicon_run.sh && tools/docker_silicon_run.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== Step 1/4 · 启动colima x86_64 + rosetta (若未运行) =="
if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon未运行 → colima启动(含rosetta仿真)："
  colima start --cpu 8 --memory 16 --disk 60 --arch aarch64 --vm-type=vz --vz-rosetta --mount-type=virtiofs || \
  colima start --cpu 8 --memory 16 --disk 60 --arch aarch64 --vz-rosetta || \
  colima start --cpu 8 --memory 16 --disk 60
fi

echo "== Step 2/4 · 构建镜像 (linux/arm64 + ROSETTA) =="
DOCKER_BUILDKIT=1 docker build \
  --platform linux/arm64 \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  -t tjogzt/gynrepanel:2.4.1 .

echo "== Step 3/4 · 验证 exit0: 2 suite + .632+ 已在Layer4/5构建期验证 =="
docker run --rm tjogzt/gynrepanel:2.4.1 true

echo "== Step 4/4 · 交互式运行 (Ctrl+C 退出，或 Ctrl+P+Q detach) =="
echo "   打开 http://localhost:8080/ 也可用"
docker run --rm -it --platform linux/arm64 \
  -p 8787:8787 -p 8080:8080 \
  -v "$(pwd):/host" \
  tjogzt/gynrepanel:2.4.1
