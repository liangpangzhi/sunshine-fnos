#!/bin/bash
set -e
D=/var/apps/sunshinestream/target/docker
cp -f /home/liang/start.sh "$D/start.sh"
cp -f /home/liang/docker-compose.yaml "$D/docker-compose.yaml"
chmod +x "$D/start.sh"
echo "=== 清理旧配置（切换 nvenc） ==="
docker run --rm -v sunshine-stream_sunshine-config:/config --entrypoint /bin/sh sunshine-stream:latest -c "rm -f /config/sunshine.conf" 2>/dev/null || \
docker volume ls | grep -i sunshine
echo "=== 重建容器 ==="
appcenter-cli stop sunshinestream >/dev/null 2>&1 || true
cd "$D" && docker compose up -d 2>&1 | tail -5
echo "=== 等待 35s ==="
sleep 35
echo "=== 状态 ==="
docker ps -a --format "{{.Names}}\t{{.Status}}" | grep -i sunshine
echo "=== 日志 ==="
docker logs sunshine-stream 2>&1 | tail -45
