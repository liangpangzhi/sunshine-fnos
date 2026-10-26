#!/bin/bash
sleep 15
echo "=== 容器状态 ==="
docker ps --format "{{.Names}}\t{{.Status}}" | grep -i sunshine
echo "=== PA 进程 ==="
docker exec sunshine-stream sh -c "pgrep -a pulseaudio || echo 未运行"
echo "=== PA 日志尾部 ==="
docker exec sunshine-stream sh -c "tail -8 /var/log/pulseaudio.log 2>&1"
echo "=== socket ==="
docker exec sunshine-stream sh -c "ls -l /run/pulse/native 2>&1"
echo "=== 重试连接 ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; pactl info 2>&1 | head -3"
