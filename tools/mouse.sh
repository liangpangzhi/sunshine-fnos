#!/bin/bash
echo "=== 输入设备列表 ==="
cat /proc/bus/input/devices 2>/dev/null | grep -E "^I:|^N:|^H:" | head -30
echo
echo "=== /dev/input 节点 ==="
ls -l /dev/input/ 2>/dev/null | head -12
echo
echo "=== 容器内可见性 ==="
docker exec sunshine-stream sh -c "ls /dev/input/ 2>&1 | head -8"
echo
echo "=== 镜像内 python ==="
docker exec sunshine-stream sh -c "command -v python3 || echo '无 python3'"
