#!/bin/bash
D=/var/apps/sunshinestream/target/docker
cp -f /home/liang/start.sh "$D/start.sh"; chmod +x "$D/start.sh"
timeout 120 docker restart sunshine-stream 2>&1 | tail -1
sleep 30
echo "=== 音频相关配置 ==="
docker exec sunshine-stream sh -c "grep -E 'stream_audio|audio_sink|minimum_fps' /config/sunshine.conf"
echo "=== 默认 sink ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; pactl get-default-sink"
