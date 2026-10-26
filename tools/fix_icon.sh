#!/bin/bash
D=/var/apps/sunshinestream/target/ui
cp -f /home/liang/ui-config.txt "$D/config"
chmod 644 "$D/config"
echo "=== 当前配置 ==="
cat "$D/config"
echo "=== 图标文件 ==="
ls -la "$D/images/"
echo "=== 图标是否可读 ==="
python3 -c "
from PIL import Image
for n in ['icon-64.png','icon-256.png']:
    im = Image.open('$D/images/'+n); print(n, im.size, im.mode)
" 2>/dev/null || echo "(容器外无 PIL，跳过)"
