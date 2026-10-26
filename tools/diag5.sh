#!/bin/bash
appcenter-cli install-fpk --help 2>&1 | head -25
echo "=== DecoTV 容器 ==="
docker ps -a --format "{{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -i "deco\|tv" | head -5
echo "=== 3006 本地探测 ==="
curl -s -o /dev/null -w "%{http_code}\n" --max-time 5 http://127.0.0.1:3006/ 2>&1
