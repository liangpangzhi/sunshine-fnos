#!/bin/bash
# Sunshine 串流容器启动脚本
#   Xvfb(可配置分辨率) -> PulseAudio 虚拟扬声器 -> Chromium 打开「任意应用地址」-> Sunshine(NVENC) 串流
#   串流目标保存在 /appdata/app.conf，由「串流控制台」(47991) 随时修改，浏览器自动重启切换
set -m

export XDG_RUNTIME_DIR=/tmp/xdg-runtime
mkdir -p "$XDG_RUNTIME_DIR" /var/log /config
chmod 700 "$XDG_RUNTIME_DIR"

# ---------- 串流目标配置 ----------
CFG_DIR=/appdata
CFG="$CFG_DIR/app.conf"
RELOAD_FLAG="$CFG_DIR/.reload"
mkdir -p "$CFG_DIR"

cfg_get() { sed -n "s/^$1=//p" "$CFG" 2>/dev/null | head -n1; }
conf_write() {  # url title mode res seed nonce
    mkdir -p "$CFG_DIR"
    {
        printf 'url=%s\n' "$(printf '%s' "$1" | tr -d '\r\n')"
        printf 'title=%s\n' "$(printf '%s' "$2" | tr -d '\r\n')"
        printf 'mode=%s\n' "$(printf '%s' "$3" | tr -d '\r\n')"
        printf 'res=%s\n' "$(printf '%s' "$4" | tr -d '\r\n')"
        printf 'seed=%s\n' "$(printf '%s' "$5" | tr -d '\r\n')"
        printf 'nonce=%s\n' "$(printf '%s' "$6" | tr -d '\r\n')"
    } > "$CFG.tmp" 2>/dev/null && mv "$CFG.tmp" "$CFG"
}

ENV_URL="${APP_URL:-}"
ENV_TITLE="${APP_TITLE:-}"
ENV_MODE="${APP_MODE:-kiosk}"
ENV_RES="${APP_RES:-1920x1080}"
# 每次「在安装/升级向导里填了地址」都会带一个新的 APP_NONCE，
# 用它区分「向导新填的地址」和「控制台里改过的地址」，两者互不覆盖
ENV_NONCE="${APP_NONCE:-}"

if [ ! -f "$CFG" ]; then
    # 首次启动：把安装时填写的地址固化下来
    conf_write "${ENV_URL:-http://192.168.5.11:3000}" "${ENV_TITLE:-我的应用}" \
               "${ENV_MODE:-kiosk}" "${ENV_RES:-1920x1080}" "${ENV_URL}" "$ENV_NONCE"
    echo "首次启动，串流目标：$(cfg_get url)"
elif [ -n "$ENV_NONCE" ] && [ "$ENV_NONCE" != "$(cfg_get nonce)" ]; then
    # 安装 / 重装 / 升级时向导里填了新地址：以新地址为准
    echo "检测到安装向导指定的新地址：$ENV_URL（原：$(cfg_get url)），已切换"
    conf_write "$ENV_URL" "${ENV_TITLE:-$(cfg_get title)}" \
               "${ENV_MODE:-$(cfg_get mode)}" "${ENV_RES:-$(cfg_get res)}" \
               "$ENV_URL" "$ENV_NONCE"
fi

APP_URL_CUR=$(cfg_get url)
APP_TITLE_CUR=$(cfg_get title)
APP_MODE_CUR=$(cfg_get mode)
APP_RES_CUR=$(cfg_get res)
case "$APP_MODE_CUR" in kiosk|browser|desktop) ;; *) APP_MODE_CUR=kiosk ;; esac
case "$APP_RES_CUR" in [0-9]*x[0-9]*) ;; *) APP_RES_CUR=1920x1080 ;; esac
SCREEN_W=${APP_RES_CUR%x*}
SCREEN_H=${APP_RES_CUR#*x}
echo "串流目标：${APP_TITLE_CUR} (${APP_URL_CUR}) 模式=${APP_MODE_CUR} 分辨率=${SCREEN_W}x${SCREEN_H}"

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
Xvfb :99 -screen 0 "${SCREEN_W}x${SCREEN_H}x24" -nolisten tcp -ac >/var/log/xvfb.log 2>&1 &
for _ in $(seq 1 20); do
    [ -S /tmp/.X11-unix/X99 ] && break
    sleep 0.5
done
if [ -S /tmp/.X11-unix/X99 ]; then
    export DISPLAY=:99
    echo "Xvfb 就绪 (DISPLAY=:99, ${SCREEN_W}x${SCREEN_H})"
else
    echo "警告：Xvfb 启动失败，请查看 /var/log/xvfb.log"
fi

# ---------- 5. 串流控制台（换地址不用重装） ----------
if command -v python3 >/dev/null 2>&1 && [ -f /usr/local/bin/console.py ]; then
    APP_URL="$APP_URL_CUR" APP_TITLE="$APP_TITLE_CUR" APP_MODE="$APP_MODE_CUR" APP_RES="$APP_RES_CUR" \
        python3 /usr/local/bin/console.py >>/var/log/console.log 2>&1 &
    echo "串流控制台已启动: http://<NAS-IP>:47991"
else
    echo "提示：未找到 console.py，跳过串流控制台"
fi

# ---------- 6. 浏览器守护：按配置打开目标地址，配置变化/崩溃后自动重启 ----------
CHROMIUM_BIN=""
for c in /usr/bin/chromium /usr/lib/chromium/chromium; do
    if [ -x "$c" ]; then CHROMIUM_BIN="$c"; break; fi
done

# 关掉翻译功能：否则外文/多语言页面会在串流画面右上角弹出翻译提示条，挡在电视上
for pdir in /etc/chromium/policies/managed /etc/opt/chrome/policies/managed; do
    mkdir -p "$pdir" 2>/dev/null
    printf '{"TranslateEnabled": false}\n' > "$pdir/sunshinestream.json" 2>/dev/null
done

BPID=""
stop_browser() {
    [ -n "$BPID" ] && kill "$BPID" 2>/dev/null
    pkill -f "user-data-dir=/config/chromium-profile" 2>/dev/null
    sleep 1
    pkill -9 -f "user-data-dir=/config/chromium-profile" 2>/dev/null
    BPID=""
}

browser_loop() {
    BPID=""
    while true; do
        rm -f "$RELOAD_FLAG"
        url=$(cfg_get url)
        mode=$(cfg_get mode)
        case "$mode" in kiosk|browser) ;; *) mode=kiosk ;; esac

        if [ -z "$CHROMIUM_BIN" ] || [ "$mode" = "desktop" ] || [ -z "$url" ]; then
            # 仅虚拟桌面：不打开浏览器
            sleep 3
            continue
        fi

        if [ "$mode" = "kiosk" ]; then
            extra="--kiosk"
        else
            extra="--start-maximized"
        fi

        "$CHROMIUM_BIN" \
            $extra --no-sandbox --no-first-run --no-default-browser-check \
            --disable-crash-reporter --disable-infobars --disable-dev-shm-usage \
            --ozone-platform=x11 --window-position=0,0 \
            --window-size="${SCREEN_W},${SCREEN_H}" \
            --autoplay-policy=no-user-gesture-required --lang=zh-CN \
            --hide-scrollbars --disable-translate \
            --disable-session-crashed-bubble --disable-features=Translate,TranslateUI \
            --user-data-dir=/config/chromium-profile \
            "$url" >>/var/log/chromium.log 2>&1 &
        BPID=$!
        echo "[$(date '+%F %T')] 已打开 ${url}（模式 ${mode}）"

        # 进程活着就守着；配置变化或收到 .reload 就重启
        while kill -0 "$BPID" 2>/dev/null; do
            sleep 2
            new_url=$(cfg_get url)
            new_mode=$(cfg_get mode)
            if [ "$new_url" != "$url" ] || [ "$new_mode" != "$mode" ] || [ -f "$RELOAD_FLAG" ]; then
                echo "[$(date '+%F %T')] 串流目标变更：${url} -> ${new_url}，重启浏览器"
                stop_browser
                break
            fi
        done

        if [ -n "$BPID" ] && ! kill -0 "$BPID" 2>/dev/null; then
            echo "[$(date '+%F %T')] 浏览器已退出，2 秒后重新打开"
            stop_browser
            sleep 2
        else
            sleep 1
        fi
    done
}

browser_loop &

# ---------- 7. 本机 USB 鼠标/键盘桥接（Xvfb 不读本地输入设备） ----------
if command -v python3 >/dev/null 2>&1 && [ -f /usr/local/bin/mouse-bridge.py ]; then
    DISPLAY=:99 python3 /usr/local/bin/mouse-bridge.py >/var/log/mouse-bridge.log 2>&1 &
    sleep 1
    grep -q "接管鼠标" /var/log/mouse-bridge.log 2>/dev/null && \
        echo "本机输入已接管: $(grep -c '' /var/log/mouse-bridge.log) 行" || \
        echo "提示：未检测到本地鼠标设备（可热插拔后重启应用）"
fi

# ---------- 8. Sunshine 前台运行 ----------
exec /usr/bin/sunshine /config/sunshine.conf
