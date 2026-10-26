#!/bin/bash
D=/var/apps/sunshinestream/target/docker
cp -f /home/liang/start.sh "$D/start.sh"; chmod +x "$D/start.sh"
timeout 120 docker restart sunshine-stream 2>&1 | tail -1
sleep 30
echo "=== 配置（应无 audio_sink） ==="
docker exec sunshine-stream cat /config/sunshine.conf
echo "=== 默认 sink / 流 ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; echo -n '默认: '; pactl get-default-sink; echo -n '流: '; pactl list short sink-inputs | wc -l"
echo "=== 启动日志 ==="
docker logs sunshine-stream 2>&1 | grep -E "移除|Screencasting|Configuration UI" | tail -4
