#!/bin/bash
appcenter-cli stop sunshinestream >/dev/null 2>&1
docker rm -f sunshine-stream >/dev/null 2>&1
appcenter-cli start sunshinestream 2>&1 | tail -3
echo "=== 等待 30s ==="
sleep 30
echo "=== 容器状态 ==="
docker ps -a --format "{{.Names}}\t{{.Status}}" | grep -i sunshine
echo "=== 容器日志 ==="
docker logs sunshine-stream 2>&1 | tail -50
