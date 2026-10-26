#!/bin/bash
D=/var/apps/sunshinestream/target/docker
echo "=== 1. 导入镜像 ==="
docker load -i /home/liang/sunshine-stream.tar.gz 2>&1 | tail -2
cp -f /home/liang/sunshine-stream.tar.gz /var/apps/sunshinestream/target/images/
cp -f /home/liang/start.sh "$D/start.sh"; chmod +x "$D/start.sh"
cp -f /home/liang/docker-compose.yaml "$D/docker-compose.yaml"
echo "=== 2. 清理旧容器与配置卷 ==="
appcenter-cli stop sunshinestream >/dev/null 2>&1 || true
docker rm -f sunshine-stream >/dev/null 2>&1 || true
docker volume rm -f docker_sunshine-config sunshine-stream_sunshine-config >/dev/null 2>&1 || true
echo "=== 3. 启动 ==="
cd "$D" && docker compose up -d 2>&1 | tail -3
echo "=== 4. 等待 40s ==="
sleep 40
echo "=== 状态 ==="
docker ps -a --format "{{.Names}}\t{{.Status}}" | grep -i sunshine
echo "=== 日志 ==="
docker logs sunshine-stream 2>&1 | tail -40
echo "=== xvfb.log ==="
docker exec sunshine-stream sh -c "tail -5 /var/log/xvfb.log 2>&1"
echo "=== 配置 ==="
docker exec sunshine-stream sh -c "cat /config/sunshine.conf 2>&1"
