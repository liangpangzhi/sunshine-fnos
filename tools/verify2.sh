#!/bin/bash
sleep 20
echo "=== 状态 ==="
appcenter-cli status sunshinestream 2>&1 | tail -1
docker ps --format "{{.Names}}\t{{.Status}}" | grep -i sunshine
echo "=== 容器环境 HOME ==="
docker inspect sunshine-stream --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -E "HOME|DECO_URL"
echo "=== 配置 ==="
docker exec sunshine-stream cat /config/sunshine.conf 2>&1 | head -12
echo "=== 桥接 / 画面 ==="
docker exec sunshine-stream sh -c "tail -2 /var/log/mouse-bridge.log; DISPLAY=:99 xwininfo -root -children 2>/dev/null | grep -ci decotv"
echo "=== 编码器 ==="
docker logs sunshine-stream 2>&1 | grep -E "Found H.264|Screencasting|Configuration UI" | tail -3
