#!/bin/bash
D=/var/apps/sunshinestream/target/docker
cp -f /home/liang/mouse-bridge.py "$D/mouse-bridge.py"
echo "=== 重启桥接进程 ==="
docker exec sunshine-stream sh -c "pkill -f mouse-bridge.py; sleep 1; DISPLAY=:99 nohup python3 /usr/local/bin/mouse-bridge.py >> /var/log/mouse-bridge.log 2>&1 &"
sleep 4
docker exec sunshine-stream sh -c "ps aux | grep mouse-bridge | grep -v grep | awk '{print \$11,\$12}'"
echo "=== 日志尾部 ==="
docker exec sunshine-stream sh -c "tail -4 /var/log/mouse-bridge.log"
