#!/bin/bash
D=/var/apps/sunshinestream/target/docker
docker load -i /home/liang/sunshine-stream.tar.gz 2>&1 | tail -1
cp -f /home/liang/sunshine-stream.tar.gz /var/apps/sunshinestream/target/images/
cp -f /home/liang/start.sh "$D/start.sh"; chmod +x "$D/start.sh"
echo "=== 重建容器 ==="
cd "$D" && docker compose up -d --force-recreate 2>&1 | tail -3
sleep 35
echo "=== 状态 ==="
docker ps --format "{{.Names}}\t{{.Status}}" | grep -i sunshine
echo "=== 输入桥接日志 ==="
docker exec sunshine-stream sh -c "cat /var/log/mouse-bridge.log 2>&1"
echo "=== 关键启动日志 ==="
docker logs sunshine-stream 2>&1 | grep -E "Xvfb|输入|Screencasting|Found H.264|Configuration UI|警告" | tail -8
