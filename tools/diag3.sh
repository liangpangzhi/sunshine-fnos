#!/bin/bash
echo "===== 可能的 appcenter CLI ====="
which appcenter-cli fnos-cli fnapp fnos 2>/dev/null
ls /usr/local/bin/ 2>/dev/null | head -30
echo
echo "===== 应用中心相关可执行文件 ====="
ls -l /usr/trim/bin/ 2>/dev/null | grep -iE "app|center" | head -20
find / -maxdepth 4 -name "*appcenter*" -type f 2>/dev/null | grep -v "/var/apps\|/proc" | head -10
echo
echo "===== trim 服务列表 ====="
systemctl list-units --type=service --state=running 2>/dev/null | grep -i trim | head -10
echo
echo "===== docker compose 版本 ====="
docker compose version 2>&1 | head -2
