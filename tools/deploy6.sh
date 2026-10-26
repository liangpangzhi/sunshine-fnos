#!/bin/bash
D=/var/apps/sunshinestream/target/docker
cp -f /home/liang/start.sh "$D/start.sh"; chmod +x "$D/start.sh"
cd "$D" && docker compose up -d --force-recreate 2>&1 | tail -2
sleep 32
echo "=== 配置 ==="
docker exec sunshine-stream sh -c "cat /config/sunshine.conf"
echo "=== PA 的 dbus 模块 ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; pactl list short modules | grep -E 'dbus|null-sink' "
echo "=== 桥接 ==="
docker exec sunshine-stream sh -c "tail -3 /var/log/mouse-bridge.log"
echo "=== 画面 ==="
docker exec sunshine-stream sh -c "DISPLAY=:99 xwininfo -root -children 2>/dev/null | grep -i decotv"
