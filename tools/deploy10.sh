#!/bin/bash
D=/var/apps/sunshinestream/target/docker
cp -f /home/liang/start.sh "$D/start.sh"; chmod +x "$D/start.sh"
timeout 120 docker restart sunshine-stream >/dev/null 2>&1
sleep 40
echo "=== PA 状态 ==="
docker exec sunshine-stream sh -c "pgrep -a pulseaudio | head -1; export PULSE_SERVER=unix:/run/pulse/native; pactl info 2>&1 | grep -E 'Server Name|Default Sink'"
echo "=== 配置 ==="
docker exec sunshine-stream sh -c "grep -E 'stream_audio|minimum_fps' /config/sunshine.conf"
echo "=== 音频流 ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; pactl list short sink-inputs"
