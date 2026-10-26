#!/bin/bash
appcenter-cli stop sunshinestream 2>&1 | tail -2
sleep 3
appcenter-cli start sunshinestream 2>&1 | tail -2
sleep 15
echo "=== 状态 ==="
appcenter-cli status sunshinestream 2>&1 | tail -3
docker ps --format "{{.Names}}\t{{.Status}}" | grep -i sunshine
