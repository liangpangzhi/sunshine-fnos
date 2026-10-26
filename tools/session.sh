#!/bin/bash
echo "=== 桥接进程 ==="
docker exec sunshine-stream sh -c "pgrep -af mouse-bridge || echo 未运行"
echo
echo "=== 串流会话/编码参数 ==="
docker logs sunshine-stream 2>&1 | grep -iE "client|session|stream|fps|bitrate|codec" | tail -15
