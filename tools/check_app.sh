#!/bin/bash
echo "=== 所有相关容器 ==="
docker ps -a --format "{{.Names}}\t{{.Status}}\t{{.Image}}" | grep -iE "sunshine|stream" || echo "无"
echo "=== 应用状态 ==="
appcenter-cli status sunshinestream 2>&1 | tail -2
echo "=== 镜像 ==="
docker images | grep -i sunshine
echo "=== compose 文件在否 ==="
ls -la /var/apps/sunshinestream/target/docker/ 2>&1 | head -8
