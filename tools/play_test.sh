#!/bin/bash
echo 'aW1wb3J0IHRpbWUKZnJvbSBYbGliIGltcG9ydCBYLCBkaXNwbGF5CmZyb20gWGxpYi5leHQgaW1wb3J0IHh0ZXN0CgpkID0gZGlzcGxheS5EaXNwbGF5KCI6OTkiKQojIOaSreaUvuWZqOS4reWkrueahOaSreaUvuaMiemSru+8iDE5MjB4MTA4MCDnlLvpnaLkuK3nuqYgNzQwLDQ4MO+8iQp4dGVzdC5mYWtlX2lucHV0KGQsIFguTW90aW9uTm90aWZ5LCB4PTc0MCwgeT00ODApCmQuc3luYygpCnRpbWUuc2xlZXAoMC4zKQp4dGVzdC5mYWtlX2lucHV0KGQsIFguQnV0dG9uUHJlc3MsIDEpCmQuc3luYygpCnRpbWUuc2xlZXAoMC4xKQp4dGVzdC5mYWtlX2lucHV0KGQsIFguQnV0dG9uUmVsZWFzZSwgMSkKZC5zeW5jKCkKcHJpbnQoIuW3sueCueWHu+aSreaUvuaMiemSriIpCg==' | base64 -d > /home/liang/click.py
docker cp /home/liang/click.py sunshine-stream:/tmp/click.py >/dev/null 2>&1
docker exec -e DISPLAY=:99 sunshine-stream python3 /tmp/click.py
sleep 5
echo "=== 音频流 ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; pactl list short sink-inputs"
echo "=== 各 monitor 3 秒数据量 ==="
for s in virtual_speaker sink-sunshine-stereo; do
  docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; timeout 3 parec --device=.monitor --format=s16le --rate=48000 --channels=2 --raw 2>/dev/null | wc -c" | tr -d '\r' | xargs -I{} echo "  : {} 字节"
done
echo "=== 默认 sink ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; pactl get-default-sink"
