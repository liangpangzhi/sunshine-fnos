#!/bin/bash
echo "=== 1. 删除悬空镜像（旧 sunshine 镜像） ==="
for id in $(docker images -f dangling=true --format "{{.ID}}"); do
  size=$(docker images -f dangling=true --format "{{.ID}} {{.Size}}" | grep "^$id" | awk '{print $2}')
  case "$size" in
    1.2*GB|1.3*GB) echo "  删除 $id ($size)"; docker rmi -f "$id" >/dev/null 2>&1 ;;
  esac
done
echo "=== 2. 删除旧配置卷 ==="
docker volume rm -f docker_sunshine-config >/dev/null 2>&1 && echo "  已删除 docker_sunshine-config"
docker volume ls | grep -i sunshine || echo "  无残留卷"
echo "=== 3. 删除应用数据目录 ==="
for d in /vol1/@appconf/sunshinestream /vol1/@appdata/sunshinestream /vol1/@apphome/sunshinestream /vol1/@appmeta/sunshinestream /vol1/@apptemp/sunshinestream; do
  [ -d "$d" ] && rm -rf "$d" && echo "  已删除 $d"
done
echo "=== 4. 清理上传残留 ==="
rm -f /home/liang/sunshine-stream.tar.gz /home/liang/sunshinestream.fpk \
      /home/liang/*.ppm /home/liang/*.py /home/liang/click*.py /home/liang/shot*.py
echo "=== 5. 清理宿主侧集成 ==="
rm -f /etc/avahi/services/sunshine-nvstream.service /etc/modules-load.d/sunshinestream.conf
systemctl restart avahi-daemon 2>/dev/null
echo "=== 清理后状态 ==="
echo -n "容器: "; docker ps -a --format "{{.Names}}" | grep -ci sunshine || echo 0
echo -n "镜像: "; docker images --format "{{.Repository}}" | grep -ci sunshine || echo 0
echo -n "悬空: "; docker images -f dangling=true -q | wc -l
echo -n "卷: "; docker volume ls | grep -ci sunshine || echo 0
df -h /vol1 | tail -1
