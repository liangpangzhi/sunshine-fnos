#!/bin/bash
echo "=== chromium 音频相关日志 ==="
docker exec sunshine-stream sh -c "grep -iE 'audio|pulse|alsa|pcm' /var/log/chromium.log 2>/dev/null | tail -12"
echo
echo "=== 抓屏 ==="
docker cp /tmp/shot_x11.py sunshine-stream:/tmp/shot_x11.py 2>/dev/null
docker exec -e DISPLAY=:99 sunshine-stream python3 /tmp/shot_x11.py > /tmp/screen.ppm 2>/tmp/shot.err
ls -la /tmp/screen.ppm 2>&1
head -3 /tmp/shot.err 2>/dev/null
