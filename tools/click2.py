import time
from Xlib import X, display
from Xlib.ext import xtest

d = display.Display(":99")
# 「继续观看」第一张卡片（登峰传奇）中心，1920x1080 坐标
xtest.fake_input(d, X.MotionNotify, x=380, y=750)
d.sync(); time.sleep(0.3)
xtest.fake_input(d, X.ButtonPress, 1); d.sync(); time.sleep(0.1)
xtest.fake_input(d, X.ButtonRelease, 1); d.sync()
print("已点击继续观看卡片")
