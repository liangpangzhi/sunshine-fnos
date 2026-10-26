#!/bin/bash
appcenter-cli start sunshinestream 2>&1 | tail -5
echo "=== 等待 20s ==="
sleep 20
echo "=== 镜像 ==="
docker images | grep -i sunshine
echo "=== 容器 ==="
docker ps -a --format "{{.Names}}\t{{.Status}}" | grep -i sunshine
echo "=== 日志 ==="
docker logs sunshine-stream 2>&1 | tail -40
