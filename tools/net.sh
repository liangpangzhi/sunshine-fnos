#!/bin/bash
echo "=== Sunshine 端口监听（TCP） ==="
ss -lntp | grep -E "47984|47989|47990|48010"
echo
echo "=== UDP ==="
ss -lnup | grep -E "47998|47999|48000|5353"
echo
echo "=== iptables 过滤规则 ==="
iptables -S 2>/dev/null | grep -vE "^-P|^-N" | head -15
echo "--- nft ---"
nft list ruleset 2>/dev/null | grep -iE "drop|reject|4798|4799" | head -10
echo
echo "=== 宿主 avahi ==="
systemctl is-active avahi-daemon 2>/dev/null
avahi-browse -at 2>/dev/null | grep -i "nvstream\|sunshine" | head -5
echo
echo "=== 局域网内 nvstream 广播 ==="
timeout 5 avahi-browse -rt _nvstream._tcp 2>&1 | head -12
