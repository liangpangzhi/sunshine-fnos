#!/bin/bash
echo "=== sway.log ==="
docker exec sunshine-stream sh -c "cat /var/log/sway.log 2>&1 | tail -20"
echo
echo "=== pulseaudio.log ==="
docker exec sunshine-stream sh -c "tail -10 /var/log/pulseaudio.log 2>&1"
echo
echo "=== vainfo ==="
docker exec sunshine-stream sh -c "vainfo 2>&1 | head -15"
echo
echo "=== /dev/dri in container ==="
docker exec sunshine-stream sh -c "ls -l /dev/dri 2>&1; id"
