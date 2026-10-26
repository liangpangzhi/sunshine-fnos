#!/bin/bash
echo "=== nvidia-smi ==="
nvidia-smi 2>&1 | head -12
echo
echo "=== 驱动版本/库 ==="
cat /proc/driver/nvidia/version 2>/dev/null | head -2
ls /usr/lib/x86_64-linux-gnu/ 2>/dev/null | grep -E "^libnvidia-(encode|decode|ml|cuda)" | head -8
echo
echo "=== docker nvidia runtime ==="
docker info 2>/dev/null | grep -iA3 "Runtimes"
echo
echo "=== nvidia-container 组件 ==="
which nvidia-container-runtime nvidia-ctk 2>/dev/null
ls /etc/docker/daemon.json && cat /etc/docker/daemon.json
