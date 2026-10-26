#!/bin/bash
echo 'aW1wb3J0IHRpbWUKZnJvbSBYbGliIGltcG9ydCBYLCBkaXNwbGF5CmZyb20gWGxpYi5leHQgaW1wb3J0IHh0ZXN0CgpkID0gZGlzcGxheS5EaXNwbGF5KCI6OTkiKQojIOOAjOe7p+e7reingueci+OAjeesrOS4gOW8oOWNoeeJh++8iOeZu+WzsOS8oOWlh++8ieS4reW/g++8jDE5MjB4MTA4MCDlnZDmoIcKeHRlc3QuZmFrZV9pbnB1dChkLCBYLk1vdGlvbk5vdGlmeSwgeD0zODAsIHk9NzUwKQpkLnN5bmMoKTsgdGltZS5zbGVlcCgwLjMpCnh0ZXN0LmZha2VfaW5wdXQoZCwgWC5CdXR0b25QcmVzcywgMSk7IGQuc3luYygpOyB0aW1lLnNsZWVwKDAuMSkKeHRlc3QuZmFrZV9pbnB1dChkLCBYLkJ1dHRvblJlbGVhc2UsIDEpOyBkLnN5bmMoKQpwcmludCgi5bey54K55Ye757un57ut6KeC55yL5Y2h54mHIikK' | base64 -d > /home/liang/click2.py
docker cp /home/liang/click2.py sunshine-stream:/tmp/click2.py >/dev/null 2>&1
docker exec -e DISPLAY=:99 sunshine-stream python3 /tmp/click2.py
sleep 10
echo "=== 音频流（sink-inputs） ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; pactl list short sink-inputs"
echo "=== monitor 数据量（3 秒） ==="
docker exec sunshine-stream sh -c 'export PULSE_SERVER=unix:/run/pulse/native; for s in virtual_speaker sink-sunshine-stereo; do n=$(timeout 3 parec --device=$s.monitor --format=s16le --rate=48000 --channels=2 --raw 2>/dev/null | wc -c); echo "  $s: $n 字节"; done'
echo "=== 默认 sink ==="
docker exec sunshine-stream sh -c "export PULSE_SERVER=unix:/run/pulse/native; pactl get-default-sink"
echo "=== 抓屏 ==="
docker cp /home/liang/shot.py sunshine-stream:/tmp/shot.py >/dev/null 2>&1
docker exec -e DISPLAY=:99 sunshine-stream python3 /tmp/shot.py > /home/liang/screen3.ppm 2>/dev/null
ls -la /home/liang/screen3.ppm
