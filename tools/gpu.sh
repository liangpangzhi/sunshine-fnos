#!/bin/bash
echo "=== GPU 信息 ==="
lspci -nn | grep -iE "vga|3d|display"
for d in /sys/class/drm/card*/device/vendor; do echo -n "$d: "; cat $d 2>/dev/null; done
echo "=== renderD 节点 ==="
ls -l /dev/dri/by-path/ 2>/dev/null
