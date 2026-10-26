#!/bin/bash
cat > /etc/avahi/services/sunshine-nvstream.service <<'XML'
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">Sunshine (NAS)</name>
  <service>
    <type>_nvstream._tcp</type>
    <port>47989</port>
  </service>
</service-group>
XML
systemctl restart avahi-daemon
sleep 3
echo "=== 广播验证 ==="
timeout 6 avahi-browse -rt _nvstream._tcp 2>&1 | head -15
echo
echo "=== avahi 状态 ==="
systemctl is-active avahi-daemon
