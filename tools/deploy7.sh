#!/bin/bash
timeout 120 docker restart sunshine-stream 2>&1 | tail -2
sleep 30
echo "=== 配置 ==="
docker exec sunshine-stream cat /config/sunshine.conf
echo "=== dbus / PA 模块 ==="
docker exec sunshine-stream sh -c "pgrep -x dbus-daemon >/dev/null && echo 'dbus 运行中'; export PULSE_SERVER=unix:/run/pulse/native; pactl list short modules | grep -E 'dbus|null-sink'"
echo "=== 桥接与画面 ==="
docker exec sunshine-stream sh -c "tail -2 /var/log/mouse-bridge.log; DISPLAY=:99 xwininfo -root -children 2>/dev/null | grep -ci decotv"
