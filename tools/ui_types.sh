#!/bin/bash
echo "=== 所有应用的 type 取值 ==="
grep -rh '"type"' /var/apps/*/ui/config 2>/dev/null | sed 's/.*: *//' | sort | uniq -c
echo
echo "=== 用 url 类型的应用示例 ==="
for f in $(grep -l '"type": *"url"' /var/apps/*/ui/config 2>/dev/null | head -3); do echo "--- $f"; cat "$f" | head -14; done
