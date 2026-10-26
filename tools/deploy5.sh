#!/bin/bash
D=/var/apps/sunshinestream/target/docker
cp -f /home/liang/mouse-bridge.py "$D/mouse-bridge.py"
cd "$D" && docker compose up -d --force-recreate 2>&1 | tail -2
sleep 28
echo "=== 接管设备（应只剩物理键鼠） ==="
docker exec sunshine-stream sh -c "grep 接管 /var/log/mouse-bridge.log"
echo "=== 画面 ==="
docker exec sunshine-stream sh -c "DISPLAY=:99 xwininfo -root -children 2>/dev/null | grep -i decotv"
