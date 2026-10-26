#!/bin/bash
echo "=== 容器日志（关键行） ==="
docker logs sunshine-stream 2>&1 | grep -E "Xvfb|uinput|Screencasting|Found H.264|Found HEVC|Configuration UI|Error|警告" | tail -12
echo
echo "=== 窗口 ==="
docker exec sunshine-stream sh -c "DISPLAY=:99 xwininfo -root -children 2>/dev/null | grep -i decotv"
echo
echo "=== 配置 ==="
docker exec sunshine-stream sh -c "cat /config/sunshine.conf"
