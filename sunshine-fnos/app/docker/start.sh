#!/bin/bash
# Sunshine 串流容器启动脚本
#   Xvfb(1080p60) -> PulseAudio 虚拟扬声器 -> Chromium 全屏 DecoTV -> Sunshine(NVENC) 串流
set -m

export XDG_RUNTIME_DIR=/tmp/xdg-runtime
mkdir -p "$XDG_RUNTIME_DIR" /var/log /config
chmod 700 "$XDG_RUNTIME_DIR"

# ---------- 0. 系统 D-Bus（PulseAudio system 模式设置默认声卡依赖它） ----------
mkdir -p /run/dbus
pgrep -x dbus-daemon >/dev/null 2>&1 || dbus-daemon --system --fork 2>/dev/null || true

# ---------- 1. PulseAudio 虚拟扬声器 ----------
SINK_NAME=virtual_speaker
if command -v pulseaudio >/dev/null 2>&1; then
    id pulse >/dev/null 2>&1 || useradd -r -d /run/pulse -s /usr/sbin/nologin pulse 2>/dev/null || true
    groupadd -f pulse-access 2>/dev/null || true
    usermod -aG pulse-access root 2>/dev/null || true
    # 容器重启时 /run 会保留旧状态，必须清掉 pid/旧 socket，否则 PA 拒绝启动
    rm -rf /run/pulse
    mkdir -p /run/pulse && chown pulse:pulse /run/pulse 2>/dev/null || true
    export PULSE_SERVER=unix:/run/pulse/native
    pulseaudio --system --disallow-exit --disallow-module-loading=no \
        --exit-idle-time=-1 -n \
        --load="module-native-protocol-unix auth-anonymous=1 socket=/run/pulse/native" \
        --load="module-null-sink sink_name=${SINK_NAME}" \
        --load="module-dbus-protocol" \
        --load="module-always-sink" \
        --log-target=file:/var/log/pulseaudio.log 2>/dev/null &
    for _ in $(seq 1 12); do
        [ -S /run/pulse/native ] && break
        sleep 0.5
    done
    pactl set-default-sink "$SINK_NAME" >/dev/null 2>&1 || true
fi

# 让新出现的音频流自动跟随当前默认声卡（Sunshine 起会话时会切换默认声卡）
(
    seen=""
    while true; do
        cur=$(pactl get-default-sink 2>/dev/null)
        if [ -n "$cur" ]; then
            for id in $(pactl list short sink-inputs 2>/dev/null | awk '{print $1}'); do
                case " $seen " in
                    *" $id "*) ;;
                    *) pactl move-sink-input "$id" "$cur" >/dev/null 2>&1; seen="$seen $id" ;;
                esac
            done
        fi
        sleep 3
    done
) &

# ---------- 2. 输入设备 ----------
[ -e /dev/uinput ] || mknod /dev/uinput c 10 223 2>/dev/null || true
[ -e /dev/uinput ] && chmod 666 /dev/uinput 2>/dev/null && echo "/dev/uinput 就绪"

# ---------- 3. Sunshine 配置（首次生成） ----------
# NVIDIA Quadro P620 -> NVENC 硬件编码；X11(Xvfb) 捕获虚拟桌面
if [ ! -f /config/sunshine.conf ]; then
    cat > /config/sunshine.conf <<EOF
capture = x11
encoder = nvenc
minimum_fps_target = 60
stream_audio = true
min_log_level = 1
origin_web_ui_allowed = lan
EOF
fi

# 已有配置时补齐关键参数（降低延迟）
if [ -f /config/sunshine.conf ]; then
    grep -q '^minimum_fps_target' /config/sunshine.conf || \
        echo 'minimum_fps_target = 60' >> /config/sunshine.conf
    # 旧的 audio_sink 会与 Sunshine 自动切换的默认 sink 冲突，导致串流无声，移除
    if grep -q '^audio_sink' /config/sunshine.conf; then
        sed -i '/^audio_sink/d' /config/sunshine.conf
        echo "已移除冲突的 audio_sink 配置"
    fi
    # 串流音频开关必须为 true，否则完全没有声音
    if grep -q '^stream_audio' /config/sunshine.conf; then
        grep -q '^stream_audio *= *true' /config/sunshine.conf || \
            sed -i 's/^stream_audio.*/stream_audio = true/' /config/sunshine.conf
    else
        echo 'stream_audio = true' >> /config/sunshine.conf
    fi
fi

# ---------- 4. 启动 Xvfb 虚拟显示 ----------
pkill -f "Xvfb :99" 2>/dev/null || true
Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp -ac >/var/log/xvfb.log 2>&1 &
for _ in $(seq 1 20); do
    [ -S /tmp/.X11-unix/X99 ] && break
    sleep 0.5
done
if [ -S /tmp/.X11-unix/X99 ]; then
    export DISPLAY=:99
    echo "Xvfb 就绪 (DISPLAY=:99)"
else
    echo "警告：Xvfb 启动失败，请查看 /var/log/xvfb.log"
fi

# ---------- 5. Chromium 全屏打开 DecoTV ----------
CHROMIUM_BIN=""
for c in /usr/bin/chromium /usr/lib/chromium/chromium; do
    if [ -x "$c" ]; then CHROMIUM_BIN="$c"; break; fi
done

if [ -n "$CHROMIUM_BIN" ]; then
    "$CHROMIUM_BIN" \
        --kiosk --no-sandbox --no-first-run --no-default-browser-check \
        --disable-crash-reporter --disable-infobars --disable-dev-shm-usage \
        --ozone-platform=x11 --window-position=0,0 --window-size=1920,1080 \
        --autoplay-policy=no-user-gesture-required \
        --disable-session-crashed-bubble --disable-features=Translate \
        --user-data-dir=/config/chromium-profile \
        "${DECO_URL:-http://192.168.5.11:13006}" >/var/log/chromium.log 2>&1 &
else
    echo "警告：未找到 Chromium 可执行文件"
fi

# ---------- 6. 本机 USB 鼠标/键盘桥接（Xvfb 不读本地输入设备） ----------
if command -v python3 >/dev/null 2>&1 && [ -f /usr/local/bin/mouse-bridge.py ]; then
    DISPLAY=:99 python3 /usr/local/bin/mouse-bridge.py >/var/log/mouse-bridge.log 2>&1 &
    sleep 1
    grep -q "接管鼠标" /var/log/mouse-bridge.log 2>/dev/null && \
        echo "本机输入已接管: $(grep -c '' /var/log/mouse-bridge.log) 行" || \
        echo "提示：未检测到本地鼠标设备（可热插拔后重启应用）"
fi

# ---------- 7. Sunshine 前台运行 ----------
exec /usr/bin/sunshine /config/sunshine.conf
