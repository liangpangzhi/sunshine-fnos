#!/usr/bin/env python3
"""串流控制台（http://NAS-IP:47991）

用途：不重新安装应用的前提下，随时修改「要串流的应用地址」。
配置写入 /appdata/app.conf，容器内的 start.sh 每 2 秒轮询一次，
发现地址变化就自动重启 Chromium 打开新地址，串流画面随即切换。

只用标准库，无第三方依赖。
"""
import html
import json
import os
import re
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(os.environ.get("CONSOLE_PORT", "47991"))
CONF_DIR = os.environ.get("APP_CONF_DIR", "/appdata")
CONF = os.path.join(CONF_DIR, "app.conf")
RELOAD_FLAG = os.path.join(CONF_DIR, ".reload")
DEFAULT_URL = os.environ.get("APP_URL", "http://192.168.5.11:3000")
DEFAULT_TITLE = os.environ.get("APP_TITLE", "我的应用")
DEFAULT_MODE = os.environ.get("APP_MODE", "kiosk")
DEFAULT_RES = os.environ.get("APP_RES", "1920x1080")

MODES = [
    ("kiosk", "全屏沉浸（无地址栏）"),
    ("browser", "窗口 + 地址栏"),
    ("desktop", "仅虚拟桌面（不打开浏览器）"),
]
RESOLUTIONS = ["1920x1080", "1280x720"]

PRESETS = [
    ("DecoTV", "http://192.168.5.11:3000"),
    ("飞牛影视", "http://192.168.5.11:5666"),
    ("飞牛管理页", "https://192.168.5.11:5667"),
]


# ---------------------------------------------------------------- 配置读写
def read_conf():
    conf = {
        "url": DEFAULT_URL,
        "title": DEFAULT_TITLE,
        "mode": DEFAULT_MODE,
        "res": DEFAULT_RES,
        "seed": "",
    }
    try:
        with open(CONF, "r", encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if "=" not in line:
                    continue
                k, v = line.split("=", 1)
                if k in conf:
                    conf[k] = v
    except FileNotFoundError:
        pass
    return conf


def write_conf(conf):
    os.makedirs(CONF_DIR, exist_ok=True)
    tmp = CONF + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        for k in ("url", "title", "mode", "res", "seed"):
            f.write("%s=%s\n" % (k, conf.get(k, "").replace("\n", " ").strip()))
    os.replace(tmp, CONF)


URL_RE = re.compile(r"^https?://[A-Za-z0-9._~:/?#@!$&()*+,;=%-]+$")


def normalize_url(raw):
    """补协议、去空格、校验。返回 (url, err)。"""
    url = (raw or "").strip()
    if not url:
        return "", "请填写应用地址"
    if url in ("about:blank", "desktop"):
        return "about:blank", None
    if not url.lower().startswith(("http://", "https://")):
        url = "http://" + url
    if not URL_RE.match(url):
        return "", "地址格式不正确（不要包含空格等特殊字符），示例：http://192.168.5.11:3000"
    parsed = urllib.parse.urlparse(url)
    if not parsed.netloc or parsed.netloc.startswith(":"):
        return "", "地址缺少主机名，示例：http://192.168.5.11:3000"
    return url, None


def check_reachable(url, timeout=2.5):
    """在后台线程里探测目标地址，避免拖慢页面。"""
    if not url or url == "about:blank":
        return "skip"
    box = {}

    def probe():
        try:
            req = urllib.request.Request(url, method="GET",
                                         headers={"User-Agent": "sunshinestream-console"})
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                box["r"] = "ok:%d" % resp.status
        except urllib.error.HTTPError as e:
            box["r"] = "ok:%d" % e.code
        except Exception as e:  # noqa: BLE001
            box["r"] = "fail:%s" % type(e).__name__

    t = threading.Thread(target=probe, daemon=True)
    t.start()
    t.join(timeout + 0.5)
    return box.get("r", "timeout")


def chromium_running():
    try:
        out = subprocess.run(["pgrep", "-af", "chromium"],
                             capture_output=True, text=True, timeout=3).stdout
        return any("chromium" in ln and "grep" not in ln for ln in out.splitlines())
    except Exception:  # noqa: BLE001
        return False


# ---------------------------------------------------------------- 页面
CSS = """
:root{--bg:#f6f7f9;--card:#fff;--fg:#1b1f24;--muted:#6b7280;--line:#e5e7eb;
--acc:#2f6feb;--ok:#0f9d58;--warn:#c2410c;--bad:#c0392b;}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);
font:15px/1.6 -apple-system,"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif;}
.wrap{max-width:760px;margin:0 auto;padding:28px 20px 60px}
h1{font-size:21px;margin:0 0 4px;font-weight:650}
.sub{color:var(--muted);font-size:13px;margin-bottom:20px}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;
padding:20px;margin-bottom:16px;box-shadow:0 1px 2px rgba(16,24,40,.04)}
label{display:block;font-size:13px;font-weight:600;margin:14px 0 6px}
label:first-of-type{margin-top:0}
input[type=text],select{width:100%;padding:9px 11px;border:1px solid var(--line);
border-radius:8px;font-size:14px;background:#fff;color:var(--fg);outline:none}
input[type=text]:focus,select:focus{border-color:var(--acc);box-shadow:0 0 0 3px rgba(47,111,235,.12)}
.row{display:flex;gap:12px;flex-wrap:wrap}
.row>div{flex:1 1 240px}
button{cursor:pointer;border-radius:8px;border:1px solid var(--line);background:#fff;
padding:9px 16px;font-size:14px;color:var(--fg)}
button.primary{background:var(--acc);border-color:var(--acc);color:#fff;font-weight:600}
button:hover{border-color:#c9cdd4}
button.primary:hover{background:#2560cf}
.presets{display:flex;gap:8px;flex-wrap:wrap;margin-top:8px}
.presets button{padding:5px 10px;font-size:13px;color:var(--acc)}
.pill{display:inline-flex;align-items:center;gap:6px;font-size:13px;padding:3px 10px;
border-radius:999px;background:#eef2f7;color:var(--muted)}
.dot{width:7px;height:7px;border-radius:50%;background:var(--muted)}
.ok{color:var(--ok)}.bad{color:var(--bad)}.warn{color:var(--warn)}
.ok .dot{background:var(--ok)}.bad .dot{background:var(--bad)}.warn .dot{background:var(--warn)}
.meta{font-size:13px;color:var(--muted)}
.meta b{color:var(--fg);font-weight:600}
.msg{padding:9px 12px;border-radius:8px;font-size:13px;margin-bottom:14px}
.msg.ok{background:#e9f7ef;color:#0f6b3f}
.msg.err{background:#fdecea;color:#a52a1f}
a{color:var(--acc);text-decoration:none}a:hover{text-decoration:underline}
.hint{font-size:12px;color:var(--muted);margin-top:6px}
.kv{display:grid;grid-template-columns:88px 1fr;gap:4px 12px;font-size:13px}
.kv span{color:var(--muted)}
"""


def page(msg="", err="", status_note=""):
    c = read_conf()
    reach = check_reachable(c["url"])
    running = chromium_running()

    if reach.startswith("ok"):
        r_cls, r_txt = "ok", "地址可达（HTTP %s）" % reach.split(":")[1]
    elif reach == "skip":
        r_cls, r_txt = "warn", "未设置地址"
    elif reach == "timeout":
        r_cls, r_txt = "warn", "探测超时"
    else:
        r_cls, r_txt = "bad", "地址不可达"

    b_cls, b_txt = ("ok", "浏览器运行中") if running else ("bad", "浏览器未运行")

    mode_opts = "".join(
        '<option value="%s"%s>%s</option>'
        % (v, " selected" if c["mode"] == v else "", html.escape(t))
        for v, t in MODES
    )
    res_opts = "".join(
        '<option value="%s"%s>%s</option>'
        % (v, " selected" if c["res"] == v else "", v.replace("x", "×"))
        for v in RESOLUTIONS
    )
    presets = "".join(
        '<button type="button" onclick="document.getElementById(\'url\').value=%s">%s</button>'
        % (html.escape("'" + u + "'", quote=True), html.escape(n))
        for n, u in PRESETS
    )
    msg_html = ""
    if msg:
        msg_html += '<div class="msg ok">%s</div>' % html.escape(msg)
    if err:
        msg_html += '<div class="msg err">%s</div>' % html.escape(err)
    if status_note:
        msg_html += '<div class="msg ok">%s</div>' % html.escape(status_note)

    title = html.escape(c["title"] or "我的应用")
    return """<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>串流控制台 · %(title)s</title><style>%(css)s</style></head>
<body><div class="wrap">
<h1>串流控制台</h1>
<div class="sub">当前串流目标：<b>%(title)s</b> · 保存后浏览器会自动重启并打开新地址</div>
%(msg)s
<div class="card">
  <div class="row" style="margin-bottom:6px">
    <div><span class="pill %(r_cls)s"><i class="dot"></i>%(r_txt)s</span></div>
    <div><span class="pill %(b_cls)s"><i class="dot"></i>%(b_txt)s</span></div>
    <div><span class="pill">虚拟桌面 %(res_txt)s</span></div>
  </div>
  <form method="post" action="/save">
    <label for="url">应用地址</label>
    <input id="url" name="url" type="text" value="%(url)s"
      placeholder="http://192.168.5.11:3000" autocomplete="off">
    <div class="presets">%(presets)s</div>
    <div class="row">
      <div>
        <label for="title">应用名称</label>
        <input id="title" name="title" type="text" value="%(title_attr)s" maxlength="24">
      </div>
      <div>
        <label for="mode">打开方式</label>
        <select id="mode" name="mode">%(mode_opts)s</select>
      </div>
    </div>
    <label for="res">虚拟桌面分辨率</label>
    <select id="res" name="res">%(res_opts)s</select>
    <div class="hint">分辨率修改后需要重启应用（应用中心停用再启用）才会生效。</div>
    <div style="margin-top:18px;display:flex;gap:10px;flex-wrap:wrap">
      <button class="primary" type="submit">保存并切换</button>
      <button type="submit" formaction="/reload">仅重新加载页面</button>
    </div>
  </form>
</div>
<div class="card">
  <div class="meta"><b>怎么用：</b>电视端 Moonlight → 连接 <b>%(host)s:47990</b>（首次需配对）→ 选择 Desktop 开始串流。<br>
  Sunshine 后台：<a href="https://%(host)s:47990" target="_blank">https://%(host)s:47990</a>（首次需接受自签证书）。</div>
</div>
</div></body></html>""" % {
        "title": title,
        "css": CSS,
        "msg": msg_html,
        "r_cls": r_cls, "r_txt": html.escape(r_txt),
        "b_cls": b_cls, "b_txt": html.escape(b_txt),
        "res_txt": html.escape(c["res"]),
        "url": html.escape(c["url"], quote=True),
        "title_attr": html.escape(c["title"], quote=True),
        "mode_opts": mode_opts,
        "res_opts": res_opts,
        "presets": presets,
        "host": html.escape(CURRENT_HOST or "NAS-IP"),
    }


CURRENT_HOST = ""


class Handler(BaseHTTPRequestHandler):
    server_version = "sunshinestream-console/1.0"

    def _send(self, code, body, ctype="text/html; charset=utf-8", extra=None):
        data = body.encode("utf-8") if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)

    def _host(self):
        h = (self.headers.get("Host") or "").split(":")[0]
        return h or socket.gethostname()

    def do_GET(self):
        global CURRENT_HOST
        CURRENT_HOST = self._host()
        path, _, query = self.path.partition("?")
        qs = urllib.parse.parse_qs(query)
        if path in ("/", "/index.html"):
            self._send(200, page(msg=qs.get("msg", [""])[0], err=qs.get("err", [""])[0]))
        elif path == "/reload":
            self._touch_reload()
            self._redirect("/?msg=" + urllib.parse.quote("已请求重新加载页面"))
        elif path == "/api/status":
            c = read_conf()
            self._send(200, json.dumps({
                "url": c["url"], "title": c["title"], "mode": c["mode"],
                "resolution": c["res"], "reachable": check_reachable(c["url"]),
                "chromium_running": chromium_running(),
            }, ensure_ascii=False), "application/json; charset=utf-8")
        else:
            self._send(404, "not found", "text/plain; charset=utf-8")

    def do_POST(self):
        global CURRENT_HOST
        CURRENT_HOST = self._host()
        path = self.path.partition("?")[0]
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length).decode("utf-8", "replace")
        form = urllib.parse.parse_qs(raw)

        if path == "/reload":
            self._touch_reload()
            self._redirect("/?msg=" + urllib.parse.quote("已请求重新加载页面"))
            return

        if path != "/save":
            self._send(404, "not found", "text/plain; charset=utf-8")
            return

        url, err = normalize_url(form.get("url", [""])[0])
        if err:
            self._redirect("/?err=" + urllib.parse.quote(err))
            return
        conf = read_conf()
        conf["url"] = url
        title = (form.get("title", [""])[0] or "").strip() or "我的应用"
        conf["title"] = title[:24]
        mode = form.get("mode", [""])[0]
        conf["mode"] = mode if mode in dict(MODES) else "kiosk"
        res = form.get("res", [""])[0]
        conf["res"] = res if res in RESOLUTIONS else "1920x1080"
        write_conf(conf)
        self._touch_reload()
        self._redirect("/?msg=" + urllib.parse.quote("已保存，正在切换到 " + url))

    def _touch_reload(self):
        try:
            os.makedirs(CONF_DIR, exist_ok=True)
            with open(RELOAD_FLAG, "w", encoding="utf-8") as f:
                f.write(str(time.time()))
        except Exception:  # noqa: BLE001
            pass

    def _redirect(self, to):
        self._send(303, "", "text/plain; charset=utf-8", {"Location": to})

    def log_message(self, fmt, *args):  # 精简日志
        sys.stderr.write("[console] %s - %s\n" % (self.address_string(), fmt % args))


def main():
    os.makedirs(CONF_DIR, exist_ok=True)
    if not os.path.exists(CONF):
        write_conf(read_conf())
    srv = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    sys.stderr.write("[console] 串流控制台已启动: http://0.0.0.0:%d\n" % PORT)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
