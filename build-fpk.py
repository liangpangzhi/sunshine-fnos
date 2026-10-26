#!/usr/bin/env python
"""打包 fpk：修正 Windows 下丢失的可执行权限位 + 归一化脚本换行符。

用法: python build-fpk.py

流程：
  1. 预检 app/ 与 cmd/ 下的脚本不能含 CRLF（Linux 上会 bad interpreter）
  2. 调 fnpack.exe build 生成 sunshinestream.fpk
  3. 重写外层 tar：修权限位（cmd/* 与 app.tgz 为 755）、文本文件 CRLF -> LF
  4. 打印自检结果（cmd/main 权限、app.tgz 大小、关键文件是否在包内）

注意：app.tgz 内含离线镜像层（较大），此处直接复用 fnpack 产物字节，
只重写外层归档，避免重复压缩耗时。
"""
import io
import os
import subprocess
import sys
import tarfile
import tempfile

ROOT = os.path.dirname(os.path.abspath(__file__))
APP_DIR = os.path.join(ROOT, "sunshine-fnos")
FPK = os.path.join(APP_DIR, "sunshinestream.fpk")
FNPACK = os.path.join(ROOT, "fnpack.exe")
EXEC_NAMES = {
    "cmd/main", "cmd/install_init", "cmd/install_callback",
    "cmd/uninstall_init", "cmd/uninstall_callback",
    "cmd/upgrade_init", "cmd/upgrade_callback",
    "cmd/config_init", "cmd/config_callback",
}
TEXT_EXT = {".sh", ".py", ".yaml", ".yml", ".env", ".conf", ".json", ".md", ".txt"}
TEXT_NAMES = {"manifest", "install", "config"}


def is_text(name):
    base = os.path.basename(name)
    if base in TEXT_NAMES:
        return True
    return os.path.splitext(base)[1].lower() in TEXT_EXT


def check_crlf():
    """预检：源码树里的脚本必须是 LF，否则安装脚本在 NAS 上会直接报错。"""
    bad = []
    for base, _, files in os.walk(APP_DIR):
        for f in files:
            p = os.path.join(base, f)
            if not is_text(p):
                continue
            with open(p, "rb") as fh:
                if b"\r\n" in fh.read():
                    bad.append(os.path.relpath(p, ROOT))
    for rel in sorted(bad):
        print("  [CRLF] %s" % rel)
    return bad


def set_mode(name, is_dir):
    if is_dir or name in EXEC_NAMES or name == "app.tgz":
        return 0o755
    return 0o644


def fix_fpk():
    src = tarfile.open(FPK, "r:gz")
    members = src.getmembers()
    buf = io.BytesIO()
    fixed = []
    with tarfile.open(fileobj=buf, mode="w:gz", compresslevel=6) as out:
        for m in members:
            m.mode = set_mode(m.name, m.isdir())
            data = src.extractfile(m) if m.isfile() else None
            if data is not None and is_text(m.name):
                raw = data.read()
                if b"\r\n" in raw:
                    raw = raw.replace(b"\r\n", b"\n")
                    fixed.append(m.name)
                m.size = len(raw)
                data = io.BytesIO(raw)
            out.addfile(m, data)
    src.close()
    with open(FPK, "wb") as f:
        f.write(buf.getvalue())
    if fixed:
        print("已修正换行符: %s" % ", ".join(fixed))


def inspect():
    print("OK -> %s (%.0f MB)" % (FPK, os.path.getsize(FPK) / 1024 / 1024))
    t = tarfile.open(FPK, "r:gz")
    tmp_path = None
    try:
        print("cmd/main mode:", oct(t.getmember("cmd/main").mode))
        print("app.tgz size: %.0f MB" % (t.getmember("app.tgz").size / 1024 / 1024))
        # 落临时文件再读，避免 500MB 常驻内存
        with tempfile.NamedTemporaryFile(suffix=".tgz", delete=False) as tmp:
            tmp.write(t.extractfile("app.tgz").read())
            tmp_path = tmp.name
    finally:
        t.close()
    try:
        inner = tarfile.open(tmp_path, "r:gz")
        names = inner.getnames()
        wants = [
            "docker/docker-compose.yaml",
            "docker/app.env",
            "docker/start.sh",
            "docker/console.py",
            "ui/config",
            "images/sunshine-stream.tar.gz",
        ]
        for w in wants:
            print("  %-34s %s" % (w, "OK" if w in names else "缺失"))
        for w in ("docker/start.sh", "docker/console.py", "docker/app.env"):
            if w in names:
                raw = inner.extractfile(w).read()
                print("  %-34s %s" % (w, "CRLF(异常)" if b"\r\n" in raw else "LF(正常)"))
        inner.close()
    finally:
        if tmp_path:
            os.unlink(tmp_path)


def main():
    print("== 预检换行符 ==")
    bad = check_crlf()
    if bad:
        print("存在 CRLF 脚本，Linux 上会 bad interpreter，已中止。请先转成 LF。")
        sys.exit(1)

    print("== fnpack build ==")
    res = subprocess.run([FNPACK, "build"], cwd=APP_DIR,
                         capture_output=True, text=True)
    print(res.stdout.strip())
    if res.returncode != 0 or not os.path.exists(FPK):
        print(res.stderr.strip(), file=sys.stderr)
        sys.exit(1)

    print("== 修正权限位 / 换行符 ==")
    fix_fpk()

    print("== 自检 ==")
    inspect()


if __name__ == "__main__":
    main()
