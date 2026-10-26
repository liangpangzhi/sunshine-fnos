#!/bin/bash
echo "=== 容器状态 ==="
docker ps -a --format "{{.Names}}\t{{.Status}}" | grep -i sunshine
echo "=== compose 文件是否已更新 ==="
grep -c "minimum_fps_target\|dbus-daemon" /var/apps/sunshinestream/target/docker/start.sh 2>/dev/null
echo "=== 尝试 up ==="
cd /var/apps/sunshinestream/target/docker && timeout 120 docker compose up -d 2>&1 | tail -4
sleep 25
docker ps --format "{{.Names}}\t{{.Status}}" | grep -i sunshine
