#!/bin/bash
echo "=== X11 输入相关库 ==="
docker exec sunshine-stream sh -c "ldconfig -p | grep -E 'libXtst|libX11.so|libXfixes|libXrandr' | head -6"
echo
echo "=== 截屏工具探测 ==="
docker exec sunshine-stream sh -c "for c in xwd import ffmpeg scrot; do command -v \$c || true; done"
echo
echo "=== 应用状态 ==="
appcenter-cli status sunshinestream 2>&1 | tail -5
echo
echo "=== 47990 从本机可达性 ==="
curl -sk -o /dev/null -w "https 47990 -> %{http_code}\n" --max-time 8 https://127.0.0.1:47990/ 2>&1
