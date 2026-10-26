#!/bin/bash
echo "=== 启动系统 D-Bus ==="
docker exec sunshine-stream sh -c "mkdir -p /run/dbus && (dbus-daemon --system --fork 2>/dev/null; echo started); sleep 1; ls -l /run/dbus/system_bus_socket 2>&1"
echo
echo "=== 给 PA 加载 dbus 模块 ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; pactl load-module module-dbus-protocol 2>&1 | head -2"
echo
echo "=== 计时测试 set-default-sink ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; time pactl set-default-sink sink-sunshine-stereo 2>&1 | head -3"
