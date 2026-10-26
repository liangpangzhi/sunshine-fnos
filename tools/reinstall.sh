#!/bin/bash
echo "=== 卸载旧版本 ==="
appcenter-cli uninstall sunshinestream 2>&1 | tr '\r' '\n' | grep -vE "^(Uninstalling|uninstall)" | tail -3
sleep 4
echo "=== 安装 v2.6.0 ==="
appcenter-cli install-fpk /home/liang/sunshinestream.fpk 2>&1 | tr '\r' '\n' | grep -vE "^(Verifying|installing)" | tail -3
sleep 4
echo "=== 版本与状态 ==="
appcenter-cli list 2>&1 | grep -i sunshine
echo "=== 桌面入口 ==="
ls /var/apps/sunshinestream/target/ui/ 2>&1
grep -E "desktop_uidir|desktop_applaunchname" /var/apps/sunshinestream/manifest 2>&1
