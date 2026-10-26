#!/bin/bash
echo "=== 安装 v3.1.0（离线：仅 docker load + 解包） ==="
appcenter-cli install-fpk /home/liang/sunshinestream-v3.1.0.fpk 2>&1 | tr '\r' '\n' | grep -vE "^(Verifying|installing)" | tail -3
sleep 3
echo "=== 版本/状态 ==="
appcenter-cli list 2>&1 | grep -i sunshine
echo "=== 启动应用 ==="
appcenter-cli start sunshinestream 2>&1 | tr '\r' '\n' | tail -2
sleep 40
echo "=== 容器 ==="
docker ps --format "{{.Names}}\t{{.Status}}" | grep -i sunshine
