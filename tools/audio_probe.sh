#!/bin/bash
echo "=== 两个 monitor 各录 2 秒，比较数据量 ==="
for s in virtual_speaker sink-sunshine-stereo; do
  docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; timeout 2 parec --device=$s.monitor --format=s16le --rate=48000 --channels=2 --raw 2>/dev/null | wc -c" | tr -d '\r' | xargs -I{} echo "  $s.monitor: {} 字节"
done
echo
echo "=== sink-inputs（是否有流） ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; pactl list short sink-inputs"
