#!/bin/bash
# macOS / Linux / Windows Git Bash（需已安装并启动 Docker）中运行：
#   bash export-image.sh
#
# 作用：构建包含 sway + Chromium + VAAPI 驱动的完整镜像，并导出为 tar，供飞牛 NAS 离线导入。
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
DOCKER_DIR="$ROOT/sunshine-fnos/app/docker"
OUT="$ROOT/sunshine-stream-image.tar"

echo "[1/3] 拉取基础镜像 lizardbyte/sunshine:latest-debian-bookworm (linux/amd64) ..."
docker pull --platform linux/amd64 lizardbyte/sunshine:latest-debian-bookworm

echo "[2/3] 构建完整镜像 sunshine-stream:latest ..."
docker build --platform linux/amd64 -t sunshine-stream:latest "$DOCKER_DIR"

echo "[3/3] 导出镜像到 $OUT ..."
docker save -o "$OUT" sunshine-stream:latest

ls -lh "$OUT"
echo "完成。把该 tar 上传到 NAS，飞牛「Docker → 镜像 → 导入」或 SSH 执行: docker load -i <路径>/sunshine-stream-image.tar"
