#!/bin/bash
echo "=== 1. 导入镜像 ==="
docker load -i /home/liang/sunshine-stream.tar.gz 2>&1 | tail -3
echo
echo "=== 2. 覆盖应用内镜像文件 ==="
cp -f /home/liang/sunshine-stream.tar.gz /var/apps/sunshinestream/target/images/sunshine-stream.tar.gz && ls -lh /var/apps/sunshinestream/target/images/
echo
echo "=== 3. 镜像内自检 ==="
docker run --rm --entrypoint /bin/sh sunshine-stream:latest -c "ls -l /start.sh /etc/sway/sunshine-sway.conf; echo ---; command -v chromium sway pulseaudio pactl; echo ---; head -5 /start.sh; echo ---; ls -ld /bin /lib /sbin /lib64" 2>&1 | tail -20
