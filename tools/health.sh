#!/bin/bash
echo "=== 应用/容器 ==="
appcenter-cli status sunshinestream 2>&1 | tail -1
docker ps --format "{{.Names}}\t{{.Status}}" | grep -i sunshine
echo "=== 音频配置（关键三项） ==="
docker exec sunshine-stream sh -c "grep -E 'stream_audio|audio_sink|minimum_fps' /config/sunshine.conf || echo '缺项'"
echo "=== PA / D-Bus ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; pgrep -x pulseaudio >/dev/null && echo PA运行中; pgrep -x dbus-daemon >/dev/null && echo dbus运行中; pactl info 2>&1 | grep 'Default Sink'"
echo "=== 输入桥接 ==="
docker exec sunshine-stream sh -c "grep 接管 /var/log/mouse-bridge.log 2>/dev/null | tail -3"
echo "=== 画面 ==="
docker exec sunshine-stream sh -c "DISPLAY=:99 xwininfo -root -children 2>/dev/null | grep -i decotv"
echo "=== 编码器 ==="
docker logs sunshine-stream 2>&1 | grep -E "Found H.264|Screencasting" | tail -2
