#!/usr/bin/env python
"""打包 fpk 并修正 Windows 下丢失的可执行权限位。

用法: python build-fpk.py

注意：app.tgz 内含离线镜像层（较大），此处直接复用 fnpack 产物字节，
只重写外层归档，避免重复压缩耗时。
"""
import io
import os
import subprocess
import sys
import tarfile

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


def set_mode(name, is_dir):
    if is_dir or name in EXEC_NAMES or name == "app.tgz":
        return 0o755
    return 0o644


def fix_fpk():
    src = tarfile.open(FPK, "r:gz")
    members = src.getmembers()
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz", compresslevel=6) as out:
        for m in members:
            m.mode = set_mode(m.name, m.isdir())
            data = src.extractfile(m) if m.isfile() else None
            out.addfile(m, data)
    src.close()
    with open(FPK, "wb") as f:
        f.write(buf.getvalue())


def main():
    res = subprocess.run([FNPACK, "build"], cwd=APP_DIR,
                         capture_output=True, text=True)
    print(res.stdout.strip())
    if res.returncode != 0 or not os.path.exists(FPK):
        print(res.stderr.strip(), file=sys.stderr)
        sys.exit(1)
    fix_fpk()

    t = tarfile.open(FPK, "r:gz")
    print("OK -> %s (%.0f MB)" % (FPK, os.path.getsize(FPK) / 1024 / 1024))
    print("cmd/main mode:", oct(t.getmember("cmd/main").mode))
    print("app.tgz size: %.0f MB" % (t.getmember("app.tgz").size / 1024 / 1024))
    inner = tarfile.open(fileobj=io.BytesIO(t.extractfile("app.tgz").read()), mode="r:gz")
    names = inner.getnames()
    for want in ("images/sunshine-stream.tar.gz", "docker/docker-compose.yaml"):
        print(f"  {want}: {'OK' if want in names else '缺失'}")


if __name__ == "__main__":
    main()
