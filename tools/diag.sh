#!/bin/bash
# NAS 现场诊断：安装失败原因
echo "===== 1. 系统信息 ====="
hostname; cat /etc/debian_version 2>/dev/null; uname -r
echo

echo "===== 2. 磁盘空间 ====="
df -h | grep -E "Filesystem|/$|/vol" | head -12
echo

echo "===== 3. Docker 状态 ====="
docker version --format '{{.Server.Version}} / {{.Server.Arch}}' 2>&1 | head -3
docker images 2>/dev/null | grep -i sunshin || echo "无 sunshine 镜像"
docker ps -a 2>/dev/null | grep -i sunshin || echo "无 sunshine 容器"
echo

echo "===== 4. 应用安装残留 ====="
ls -la /var/apps/ 2>/dev/null | tail -8
echo "--- sunshinestream ---"
ls -laR /var/apps/sunshinestream 2>/dev/null | head -25
echo

echo "===== 5. 安装日志（关键词搜索）====="
for f in /var/log/appcenter.log /var/log/appc.log /var/log/*app*.log; do
    [ -f "$f" ] && echo "--- $f ---" && grep -iE "sunshin|fpk|install.*fail|失败" "$f" 2>/dev/null | tail -25
done
echo

echo "===== 6. 最近的系统日志 ====="
journalctl -S "-3 hours" --no-pager 2>/dev/null | grep -iE "sunshin|appcenter|fpk|app install" | tail -40
echo

echo "===== 7. GPU / 输入设备 ====="
ls -l /dev/dri/ 2>&1
ls -l /dev/uinput 2>&1
lsmod | grep -E "uinput|amdgpu" | head -5
echo

echo "===== 8. 应用中心日志目录 ====="
find /var/log -maxdepth 3 -newermt "-3 hours" -type f 2>/dev/null | grep -vE "\.gz$|btmp|wtmp|lastlog" | head -20
