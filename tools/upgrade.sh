#!/bin/bash
appcenter-cli install-fpk /home/liang/sunshinestream.fpk 2>&1 | tr '\r' '\n' | grep -vE "^(Verifying|installing)" | tail -5
sleep 5
appcenter-cli status sunshinestream 2>&1 | tail -2
docker ps --format "{{.Names}}\t{{.Status}}" | grep -i sunshine
docker logs sunshine-stream 2>&1 | grep -E "Xvfb 就绪|Screencasting|Found H.264|Configuration UI" | tail -5
