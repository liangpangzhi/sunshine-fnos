#!/bin/bash
echo "=== event16 设备信息 ==="
grep -B4 "Handlers=.*event16" /proc/bus/input/devices 2>/dev/null | grep -E "N:|H:"
echo
echo "=== by-id 中的鼠标 ==="
ls -l /dev/input/by-id/ 2>/dev/null | grep -iE "mouse|kbd" | head -5
