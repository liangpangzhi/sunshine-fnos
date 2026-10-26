#!/bin/bash
D=/var/apps/sunshinestream/target/docker
cp -f /home/liang/mouse-bridge.py "$D/mouse-bridge.py"
cp -f /home/liang/docker-compose.yaml "$D/docker-compose.yaml"
cd "$D" && docker compose up -d --force-recreate 2>&1 | tail -3
sleep 30
echo "=== 桥接日志 ==="
docker exec sunshine-stream sh -c "cat /var/log/mouse-bridge.log 2>&1 | head -8"
