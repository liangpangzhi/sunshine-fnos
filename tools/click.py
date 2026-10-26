import time
from Xlib import X, display
from Xlib.ext import xtest

d = display.Display(":99")
# 播放器中央的播放按钮（1920x1080 画面中约 740,480）
xtest.fake_input(d, X.MotionNotify, x=740, y=480)
d.sync()
time.sleep(0.3)
xtest.fake_input(d, X.ButtonPress, 1)
d.sync()
time.sleep(0.1)
xtest.fake_input(d, X.ButtonRelease, 1)
d.sync()
print("已点击播放按钮")
