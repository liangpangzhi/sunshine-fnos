import struct, sys
from Xlib import X, display

d = display.Display(":99")
root = d.screen().root
g = root.get_geometry()
w, h = g.width, g.height
raw = root.get_image(0, 0, w, h, X.ZPixmap, 0xffffffff).data
# ZPixmap 24bit -> BGRX
out = bytearray()
out += b"P6\n%d %d\n255\n" % (w, h)
for i in range(0, len(raw), 4):
    out += bytes((raw[i+2], raw[i+1], raw[i]))
sys.stdout.buffer.write(bytes(out))
