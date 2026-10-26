#!/bin/bash
appcenter-cli stop sunshinestream >/dev/null 2>&1
appcenter-cli uninstall sunshinestream 2>&1 | tr '\r' '\n' | grep -vE "^(uninstalling|Uninstalling)" | tail -2
sleep 3
appcenter-cli install-fpk /home/liang/sunshinestream-v3.1.1.fpk 2>&1 | tr '\r' '\n' | grep -vE "^(Verifying|installing)" | tail -2
sleep 3
echo "=== 版本 ==="
appcenter-cli list 2>&1 | grep -i sunshine
echo "=== 桌面配置（应为 icon-{0}） ==="
grep icon /var/apps/sunshinestream/target/ui/config
echo "=== 图标文件 ==="
ls /var/apps/sunshinestream/target/ui/images/
sleep 25
echo "=== 容器 ==="
docker ps --format "{{.Names}}\t{{.Status}}" | grep -i sunshine
