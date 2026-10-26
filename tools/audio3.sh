#!/bin/bash
echo "=== sunshine 日志中音频相关 ==="
docker logs sunshine-stream 2>&1 | grep -iE "audio|pulse|sink|microphone" | tail -12
echo
echo "=== 手工抓 monitor 2 秒 ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; timeout 2 parec --device=virtual_speaker.monitor --format=s16le --rate=48000 --channels=2 --raw 2>/tmp/parec.err | wc -c; cat /tmp/parec.err | head -3"
echo
echo "=== Sunshine 创建的 sink 细节 ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; pactl list sinks | grep -E 'Name:|Sample Specification|Channel Map' | head -12"
