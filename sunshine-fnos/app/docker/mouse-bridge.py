#!/usr/bin/env python3
"""把宿主机 /dev/input 下的鼠标键盘事件转发到 X11 (XTest)。

Xvfb 不读取任何输入设备，所以本机插的 USB 鼠标/键盘需要这个桥接注入到
XTEST，虚拟桌面里的 Chromium 才能收到。支持热插拔（每 2 秒重新扫描）。
"""
import selectors
import sys
import time

from evdev import InputDevice, ecodes, list_devices
from Xlib import X, display
from Xlib.ext import xtest

BTN_MAP = {
    ecodes.BTN_LEFT: 1,
    ecodes.BTN_MIDDLE: 2,
    ecodes.BTN_RIGHT: 3,
}
SCAN_INTERVAL = 2.0


# 这些是 Sunshine 为串流客户端创建的虚拟设备，不能重复接管（否则输入端会翻倍）
SKIP_KEYWORDS = ("passthrough", "sunshine", "wb-e2e", "wb-test")


def classify(dev):
    """返回 'mouse' / 'keyboard' / None"""
    name = (dev.name or "").lower()
    if any(k in name for k in SKIP_KEYWORDS):
        return None
    try:
        caps = dev.capabilities()
    except Exception:
        return None
    if ecodes.EV_REL in caps and ecodes.EV_KEY in caps:
        keys = caps[ecodes.EV_KEY]
        if ecodes.BTN_LEFT in keys or ecodes.BTN_MOUSE in keys:
            return "mouse"
    if ecodes.EV_KEY in caps:
        keys = caps[ecodes.EV_KEY]
        if ecodes.KEY_A in keys and ecodes.KEY_Z in keys:
            return "keyboard"
    return None


def main():
    disp = display.Display()
    root = disp.screen().root
    sel = selectors.DefaultSelector()
    known = {}
    last_scan = 0.0
    dx = dy = 0

    print("输入桥接启动，监听 /dev/input（支持热插拔）", flush=True)

    while True:
        now = time.time()
        if now - last_scan > SCAN_INTERVAL:
            last_scan = now
            for path in list_devices():
                if path in known:
                    continue
                try:
                    dev = InputDevice(path)
                except Exception:
                    continue
                kind = classify(dev)
                if not kind:
                    continue
                known[path] = dev
                sel.register(dev, selectors.EVENT_READ)
                print(f"接管{kind}: {dev.name} ({path})", flush=True)

        moved = False
        dirty = False
        for key, _ in sel.select(timeout=0.01):
            dev = key.fileobj
            try:
                events = list(dev.read())
            except Exception:
                sel.unregister(dev)
                known.pop(dev.path, None)
                continue
            for ev in events:
                if ev.type == ecodes.EV_REL:
                    if ev.code == ecodes.REL_X:
                        dx += ev.value
                        moved = True
                    elif ev.code == ecodes.REL_Y:
                        dy += ev.value
                        moved = True
                    elif ev.code == ecodes.REL_WHEEL:
                        btn = 4 if ev.value > 0 else 5
                        for _ in range(abs(ev.value)):
                            xtest.fake_input(disp, X.ButtonPress, btn)
                            xtest.fake_input(disp, X.ButtonRelease, btn)
                        dirty = True
                elif ev.type == ecodes.EV_KEY:
                    if ev.code in BTN_MAP:
                        btn = BTN_MAP[ev.code]
                        xtest.fake_input(
                            disp, X.ButtonPress if ev.value else X.ButtonRelease, btn)
                        dirty = True
                    elif ecodes.KEY_ESC <= ev.code <= ecodes.KEY_MICMUTE:
                        # evdev 键码 + 8 = X11 keycode（标准映射）
                        keycode = ev.code + 8
                        xtest.fake_input(
                            disp, X.KeyPress if ev.value else X.KeyRelease, keycode)
                        dirty = True

        if moved:
            # XWarpPointer 是绝对定位，先取当前坐标再加偏移
            ptr = root.query_pointer()
            root.warp_pointer(ptr.root_x + dx, ptr.root_y + dy)
            dx = dy = 0
        if moved or dirty:
            # 关键：按键/点击后必须 sync，否则事件会滞留缓冲区
            disp.sync()


if __name__ == "__main__":
    sys.exit(main() or 0)
