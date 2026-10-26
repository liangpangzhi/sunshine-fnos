#!/bin/bash
echo "=== Sunshine 音频日志（本次会话） ==="
docker logs sunshine-stream 2>&1 | grep -iE "audio|sink|pulse|microphone" | tail -14
echo
echo "=== 当前 sink ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; pactl list short sinks; echo '--- 默认 ---'; pactl get-default-sink"
echo
echo "=== 正在播放的流（sink-inputs） ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; pactl list short sink-inputs; echo '--- 详情 ---'; pactl list sink-inputs | grep -E 'Sink:|application.name|Corked|Mute' | head -12"
echo
echo "=== 各 sink 音量/静音 ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; for s in \$(pactl list short sinks | awk '{print \$2}'); do echo -n \"\$s: \"; pactl get-sink-volume \$s | head -1; pactl get-sink-mute \$s; done"
