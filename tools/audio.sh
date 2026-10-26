#!/bin/bash
echo "=== root 直连 PA ==="
docker exec sunshine-stream sh -c "PULSE_SERVER=unix:/run/pulse/native pactl info 2>&1 | head -8"
echo
echo "=== sink 列表 ==="
docker exec sunshine-stream sh -c "PULSE_SERVER=unix:/run/pulse/native pactl list short sinks 2>&1"
echo
echo "=== PA 进程用户 ==="
docker exec sunshine-stream sh -c "ps -o user,pid,args -C pulseaudio 2>&1 | head -3"
echo
echo "=== 47990 监听 ==="
ss -lntp 2>/dev/null | grep -E "4798|4799|48000" | head -6
