#!/bin/bash
appcenter-cli install-fpk /home/liang/sunshinestream.fpk 2>&1 | tr '\r' '\n' | grep -vE "^(Verifying|installing)" | tail -4
sleep 5
echo "=== 应用状态 ==="
appcenter-cli status sunshinestream 2>&1 | tail -2
echo "=== 桌面入口文件 ==="
ls -l /var/apps/sunshinestream/target/ui/ 2>&1
ls -l /var/apps/sunshinestream/target/ui/images/ 2>&1
echo "=== manifest 桌面字段 ==="
grep -E "desktop_uidir|desktop_applaunchname|^version" /var/apps/sunshinestream/target/manifest 2>/dev/null
echo "=== 桌面入口配置 ==="
cat /var/apps/sunshinestream/target/ui/config 2>&1
