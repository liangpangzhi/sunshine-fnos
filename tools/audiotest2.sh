#!/bin/bash
docker exec sunshine-stream sh -c '
export PULSE_SERVER=unix:/run/pulse/native
S=$(date +%s%N)
pactl set-default-sink sink-sunshine-stereo; RC=$?
E=$(date +%s%N)
echo "rc=$RC elapsed=$(( (E-S)/1000000 ))ms"
pactl info | grep -iE "Default Sink|Server Name"
'
