#!/bin/bash
echo "=== 窗口 ==="
docker exec sunshine-stream sh -c "DISPLAY=:99 xwininfo -root -children 2>/dev/null | grep -i decotv"
echo "=== 桥接进程 ==="
docker exec sunshine-stream sh -c "ps aux | grep mouse-bridge | grep -v grep | awk '{print \$11,\$12,\$13}'"
echo "=== 接管设备 ==="
docker exec sunshine-stream sh -c "grep 接管 /var/log/mouse-bridge.log | tail -5"
