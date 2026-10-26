#!/bin/bash
echo "=== sway.log ==="
docker exec sunshine-stream sh -c "cat /var/log/sway.log 2>&1 | tail -15"
echo
echo "=== volumes ==="
docker volume ls | grep -i sunshine
echo
echo "=== nvidia 设备/工具 ==="
docker exec sunshine-stream sh -c "ls /dev/nvidia* 2>&1 | head -6; nvidia-smi -L 2>&1 | head -3; ls /usr/lib/x86_64-linux-gnu/libnvidia-encode* 2>&1 | head -3"
echo
echo "=== 当前 sunshine.conf ==="
docker exec sunshine-stream sh -c "cat /config/sunshine.conf 2>&1"
