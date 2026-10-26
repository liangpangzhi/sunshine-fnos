#!/bin/bash
echo "=== 容器内 PA 连接 ==="
docker exec sunshine-stream sh -c "PULSE_SERVER=unix:/run/pulse/native pactl info 2>&1 | head -4"
echo "=== sink/source ==="
docker exec sunshine-stream sh -c "PULSE_SERVER=unix:/run/pulse/native pactl list short sinks; PULSE_SERVER=unix:/run/pulse/native pactl list short sources"
echo "=== PA 日志中 23:03 前后 ==="
docker exec sunshine-stream sh -c "grep -iE 'denied|reject|error|client' /var/log/pulseaudio.log | tail -12"
echo "=== sunshine 进程环境 ==="
docker exec sunshine-stream sh -c "tr '\\0' '\\n' < /proc/\$(pgrep -f '/usr/bin/sunshine' | head -1)/environ | grep -E 'PULSE|XDG|DISPLAY'"
