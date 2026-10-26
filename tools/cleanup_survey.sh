#!/bin/bash
echo "=== 容器 ==="
docker ps -a --format "{{.Names}}\t{{.Status}}" | grep -i sunshine || echo "无"
echo "=== 镜像 ==="
docker images --format "{{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}" | grep -i sunshine || echo "无"
echo "=== 悬空镜像（前 5） ==="
docker images -f dangling=true --format "{{.ID}}\t{{.Size}}" | head -5
echo "=== 卷 ==="
docker volume ls | grep -i sunshine || echo "无"
echo "=== 应用目录 ==="
ls -d /var/apps/sunshinestream 2>/dev/null || echo "无 /var/apps 目录"
ls -d /vol1/@appcenter/sunshinestream /vol1/@appdata/sunshinestream /vol1/@appconf/sunshinestream /vol1/@appmeta/sunshinestream /vol1/@apphome/sunshinestream /vol1/@apptemp/sunshinestream 2>/dev/null || echo "无 @app 子目录"
echo "=== 宿主侧集成 ==="
ls -l /etc/avahi/services/sunshine-nvstream.service 2>/dev/null || echo "无 avahi 配置"
ls -l /etc/modules-load.d/sunshinestream.conf 2>/dev/null || echo "无 uinput 自加载配置"
echo "=== /home/liang 上传残留 ==="
ls -lh /home/liang/*.tar.gz /home/liang/*.fpk /home/liang/*.ppm /home/liang/*.py 2>/dev/null | awk '{print "  ", $5, $9}' || echo "无"
echo "=== 磁盘 ==="
df -h / /vol1 | tail -2
