"""修复镜像层的 usrmerge 路径问题。

问题：Debian bookworm 基础镜像里 /bin、/sbin、/lib、/lib64 是指向 usr/* 的符号链接，
而 extras 层（来自 .deb 解包）把这些写成了真实目录，导致容器内 /bin/sh 丢失。

修复：把 extras 层中 bin/ sbin/ lib/ lib64/ 下的内容重写为 usr/ 前缀，
并跳过这些顶层目录条目本身。重算 diff_id 后重新输出镜像包。

用法: python tools/fix-image-tar.py
"""
import hashlib
import io
import json
import os
import shutil
import tarfile
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG = os.path.join(ROOT, "sunshine-fnos", "app", "images", "sunshine-stream.tar.gz")
PREFIXES = ("bin", "sbin", "lib", "lib64")


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(4 * 1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def transform(name):
    """返回重写后的路径；返回 None 表示跳过"""
    n = name
    while n.startswith("./"):
        n = n[2:]
    top = n.split("/")[0]
    if top in PREFIXES:
        if "/" not in n:
            return None          # 跳过顶层目录本身
        return "usr/" + n
    return n


def main():
    tmp = tempfile.mkdtemp(prefix="fiximg-")
    out_path = os.path.join(tmp, "out.tar.gz")
    try:
        src = tarfile.open(IMG, "r:gz")
        names = src.getnames()
        manifest = json.load(src.extractfile("manifest.json"))
        entry = manifest[0]
        cfg_name = entry["Config"]
        cfg = json.load(src.extractfile(cfg_name))
        layers = entry["Layers"]
        last_layer = layers[-1]
        print("层数:", len(layers), "| 待修复层:", last_layer)

        # 1) 重写 extras 层
        fixed_layer = os.path.join(tmp, "layer.tar")
        count = skipped = dupe = 0
        seen = set()
        with tarfile.open(fileobj=src.extractfile(last_layer), mode="r:") as inner, \
                tarfile.open(fixed_layer, "w") as out:
            for m in inner:
                new = transform(m.name)
                if new is None:
                    skipped += 1
                    continue
                if new in seen:
                    # usrmerge 重写后与已有路径重名（如 bin/sed -> usr/bin/sed）
                    dupe += 1
                    continue
                seen.add(new)
                m.name = new
                data = inner.extractfile(m) if m.isfile() else None
                out.addfile(m, data)
                count += 1
        print(f"  重写完成: {count} 个条目，跳过顶层目录 {skipped} 个，去重 {dupe} 个")

        # 2) 更新 config 的 diff_ids
        new_diff = "sha256:" + sha256_file(fixed_layer)
        cfg["rootfs"]["diff_ids"][-1] = new_diff
        cfg_bytes = json.dumps(cfg).encode()
        cfg_hex = hashlib.sha256(cfg_bytes).hexdigest()
        entry["Config"] = f"{cfg_hex}.json"
        print("  新 diff_id:", new_diff[:19])

        # 3) 重新输出镜像归档
        with tarfile.open(out_path, "w:gz", compresslevel=6) as out:
            def add_bytes(name, data):
                ti = tarfile.TarInfo(name)
                ti.size = len(data)
                ti.mode = 0o644
                ti.mtime = 0
                out.addfile(ti, io.BytesIO(data))

            add_bytes(entry["Config"], cfg_bytes)
            add_bytes("manifest.json", json.dumps(manifest).encode())
            for name in layers:
                if name == last_layer:
                    ti = tarfile.TarInfo(name)
                    ti.size = os.path.getsize(fixed_layer)
                    ti.mode = 0o644
                    ti.mtime = 0
                    with open(fixed_layer, "rb") as f:
                        out.addfile(ti, f)
                else:
                    m = src.getmember(name)
                    ti = tarfile.TarInfo(name)
                    ti.size = m.size
                    ti.mode = 0o644
                    ti.mtime = 0
                    out.addfile(ti, src.extractfile(m))

        src.close()
        shutil.move(out_path, IMG)
        print(f"完成: {IMG}  {os.path.getsize(IMG)/1024/1024:.0f} MB")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
