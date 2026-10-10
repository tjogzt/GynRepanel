#!/usr/bin/env bash
# GynRepanel bioRxiv一键POST上传脚本
# 依赖: 用户贴入 biorxiv_api_key (bxxxx 64字符) + manuscript/main.pdf
# 用法:
#   export BIORXIV_API_KEY="bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
#   tools/biorxiv_upload.sh  [path/to/manuscript.pdf]
# 文档: https://api.biorxiv.org/
set -euo pipefail
PDF="${1:-../manuscript/main.pdf}"
cd "$(dirname "$0")/.."

if [ -z "${BIORXIV_API_KEY:-}" ]; then
  echo "❌ 请先设置 BIORXIV_API_KEY 环境变量：export BIORXIV_API_KEY=bxxxxxxxxxx"
  exit 1
fi
if [ ! -f "$PDF" ]; then
  echo "❌ PDF文件不存在: $PDF (先跑 Task-A xelatex 3遍生成)"
  exit 2
fi
METADATA="../results/docs/bioRxiv_Metadata_v2.4.1.json"
OUT="../results/docs/bioRxiv_Upload_Response.json"
echo "== POST https://api.biorxiv.org/posts/submission ="
echo "   PDF: $PDF ($(du -h "$PDF" | cut -f1))"
/usr/bin/curl -i -X POST "https://api.biorxiv.org/posts/submission" \
  -H "Authorization: Bearer ${BIORXIV_API_KEY}" \
  -H "Accept: application/json" \
  -F "metadata=<$METADATA" \
  -F "content=@$PDF" \
  -o "$OUT" -D "../results/docs/bioRxiv_Upload_Headers.txt"
echo "响应头 (first 15):"
head -15 ../results/docs/bioRxiv_Upload_Headers.txt || true
echo "响应体 (first 300 bytes):"
head -c 300 "$OUT"; echo ""
echo "   完整响应写入: $OUT"
