#!/bin/bash
echo "=== Sunshine 状态文件 ==="
docker exec sunshine-stream sh -c "ls -la /config/.config/sunshine/ 2>&1; echo '---'; cat /config/.config/sunshine/sunshine_state.json 2>&1 | head -20"
