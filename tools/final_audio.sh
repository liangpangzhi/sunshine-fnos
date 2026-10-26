#!/bin/bash
echo "=== Sunshine 本次会话音频日志 ==="
docker logs sunshine-stream 2>&1 | grep -iE "Start capturing|audio capture|capturing Audio|default sink" | tail -6
echo
echo "=== 正在录音的流（source-outputs） ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; pactl list short source-outputs"
echo
echo "=== sink-input 所在 sink ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; pactl list sink-inputs | grep -E 'Sink:|application.name|Sample Spec' | head -6"
