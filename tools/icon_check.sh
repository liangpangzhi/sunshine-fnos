#!/bin/bash
echo "=== 我们包里的图标 ==="
ls -la /var/apps/sunshinestream/target/ui/images/ 2>&1
echo "=== ui/config ==="
cat /var/apps/sunshinestream/target/ui/config 2>&1
echo
echo "=== 其他商店应用的 ui/images 命名（参考） ==="
for d in /var/apps/*/ui/images; do
  [ -d "$d" ] && echo "--- $d" && ls "$d" | head -4
done 2>/dev/null | head -30
echo
echo "=== 应用状态 ==="
appcenter-cli status sunshinestream 2>&1 | tail -2
docker ps -a --format "{{.Names}}\t{{.Status}}" | grep -i sunshine
