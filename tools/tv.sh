#!/bin/bash
echo "=== ping 电视 ==="
ping -c 3 -W 2 192.168.5.6 2>&1 | tail -4
echo
echo "=== ARP ==="
arp -n 2>/dev/null | grep "192.168.5.6"
echo
echo "=== NAS 网卡/网段 ==="
ip -4 addr show | grep -E "inet " | head -5
