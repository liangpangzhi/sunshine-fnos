#!/bin/bash
echo "=== fnmonitor（商店应用，可正常显示图标）ui/config ==="
cat /var/apps/fnmonitor/ui/config 2>&1 | head -40
echo
echo "=== fnmonitor manifest 桌面字段 ==="
grep -E "desktop_|^version|^appname" /var/apps/fnmonitor/manifest 2>&1
echo
echo "=== 其他有 https 的 url 入口示例 ==="
grep -rl '"protocol": *"https"' /var/apps/*/ui/config 2>/dev/null | head -3
for f in $(grep -rl '"protocol": *"https"' /var/apps/*/ui/config 2>/dev/null | head -2); do echo "--- $f"; head -20 "$f"; done
