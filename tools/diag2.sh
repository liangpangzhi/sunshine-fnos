#!/bin/bash
echo "===== trim_app_center/error.log（最近 80 行）====="
tail -n 80 /var/log/trim_app_center/error.log 2>/dev/null
echo
echo "===== info.log 中 sunshine 相关（最近 60 行）====="
grep -iE "sunshin|docker" /var/log/trim_app_center/info.log 2>/dev/null | tail -60
