#!/bin/bash
echo "=== 进程 ==="
docker exec sunshine-stream sh -c "ps aux | grep -E 'Xvfb|chromium|pulseaudio|sunshine' | grep -v grep | awk '{print \$11, \$12, \$13}' | head -12"
echo
echo "=== X11 窗口 ==="
docker exec sunshine-stream sh -c "DISPLAY=:99 xwininfo -root -children 2>&1 | head -12"
echo
echo "=== chromium.log ==="
docker exec sunshine-stream sh -c "tail -15 /var/log/chromium.log 2>&1"
echo
echo "=== pulse ==="
docker exec sunshine-stream sh -c "ls -l /run/pulse/native 2>&1; tail -5 /var/log/pulseaudio.log 2>&1"
echo
echo "=== DecoTV 连通性 ==="
docker exec sunshine-stream sh -c "curl -s -o /dev/null -w 'deco: %{http_code}\n' --max-time 8 http://192.168.5.11:13006/ 2>&1"
