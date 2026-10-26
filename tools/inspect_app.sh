#!/bin/bash
echo "=== /var/apps/sunshinestream 结构 ==="
ls -la /var/apps/sunshinestream/ 2>&1
echo "=== target ==="
ls -la /var/apps/sunshinestream/target/ 2>&1 | head -15
echo "=== 找 manifest ==="
find /var/apps/sunshinestream -maxdepth 3 -name manifest 2>/dev/null
echo "=== 找 ui ==="
find /var/apps/sunshinestream -maxdepth 4 -type d -name ui 2>/dev/null
echo "=== 已安装版本（应用中心数据库） ==="
appcenter-cli list 2>&1 | grep -i sunshine
