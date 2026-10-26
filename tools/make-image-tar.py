"""把基础镜像层 + extras 层组装成一个完整的 docker load 镜像包（legacy 格式）。

产出：sunshine-fnos/app/images/sunshine-stream.tar.gz
镜像名：sunshine-stream:latest（直接可用，无需 docker build）

用法: python tools/make-image-tar.py
"""
import gzip
import hashlib
import io
import json
import os
import shutil
import tarfile
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "build", "base")
EXTRAS = os.path.join(ROOT, "sunshine-fnos", "app", "docker", "extras.tar.gz")
OUT = os.path.join(ROOT, "sunshine-fnos", "app", "images", "sunshine-stream.tar.gz")


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    base_cfg = json.load(open(os.path.join(BASE, "config.json")))
    layers_meta = json.load(open(os.path.join(BASE, "layers.json")))

    tmp = tempfile.mkdtemp(prefix="imgtar-")
    try:
        entries = []      # (name_in_tar, path_on_disk)
        diff_ids = list(base_cfg["rootfs"]["diff_ids"])

        # ---- 1. 基础层解压成 layer.tar ----
        for i, l in enumerate(layers_meta):
            d = os.path.join(tmp, f"layer{i:02d}")
            os.makedirs(d, exist_ok=True)
            dst = os.path.join(d, "layer.tar")
            with gzip.open(os.path.join(BASE, l["file"]), "rb") as fin, \
                    open(dst, "wb") as fout:
                shutil.copyfileobj(fin, fout, 4 * 1024 * 1024)
            with open(os.path.join(d, "VERSION"), "w") as f:
                f.write("1.0")
            entries.append((f"layer{i:02d}/layer.tar", dst))
            print(f"基础层 {i}: {os.path.getsize(dst)/1024/1024:.0f} MB")

        # ---- 2. extras 层解压 + 覆盖启动脚本 + 计算 diff_id ----
        idx = len(entries)
        d = os.path.join(tmp, f"layer{idx:02d}")
        os.makedirs(d, exist_ok=True)
        dst = os.path.join(d, "layer.tar")

        # 用仓库里的最新版本覆盖镜像内的 /start.sh 与 sway 配置，
        # 避免层内脚本是旧版本（层已包含 379MB 依赖，不便为改脚本重打）
        overrides = {
            "start.sh": (os.path.join(ROOT, "sunshine-fnos", "app", "docker", "start.sh"), 0o755),
            "etc/sway/sunshine-sway.conf": (os.path.join(ROOT, "sunshine-fnos", "app", "docker", "sway-sunshine.conf"), 0o644),
            "usr/local/bin/mouse-bridge.py": (os.path.join(ROOT, "sunshine-fnos", "app", "docker", "mouse-bridge.py"), 0o755),
        }
        replaced = set()
        usrmerged = skipped_top = dup = 0
        seen = set()
        with tarfile.open(EXTRAS, "r:gz") as src, \
                tarfile.open(dst, "w") as layer:
            for m in src:
                name = m.name
                while name.startswith("./"):
                    name = name[2:]

                # usrmerge：基础镜像里 /bin /sbin /lib /lib64 是指向 usr/* 的符号链接，
                # 层里这些真实目录会覆盖掉链接，导致 /bin/sh 丢失，必须重写为 usr/ 前缀
                top = name.split("/")[0]
                if top in ("bin", "sbin", "lib", "lib64"):
                    if "/" not in name:
                        skipped_top += 1
                        continue
                    name = "usr/" + name
                    usrmerged += 1
                if name in seen:
                    dup += 1
                    continue
                seen.add(name)

                if name in overrides:
                    path, mode = overrides[name]
                    data = open(path, "rb").read()
                    ti = tarfile.TarInfo(name)
                    ti.size = len(data)
                    ti.mode = mode
                    ti.mtime = m.mtime
                    ti.uid = ti.gid = 0
                    layer.addfile(ti, io.BytesIO(data))
                    replaced.add(name)
                    continue
                m.name = name
                data = src.extractfile(m) if m.isfile() else None
                layer.addfile(m, data)
            # 层里没有则追加
            for name, (path, mode) in overrides.items():
                if name in replaced:
                    continue
                data = open(path, "rb").read()
                ti = tarfile.TarInfo(name)
                ti.size = len(data)
                ti.mode = mode
                ti.mtime = 0
                ti.uid = ti.gid = 0
                layer.addfile(ti, io.BytesIO(data))
        print("  已覆盖:", ", ".join(sorted(replaced)) or "(追加)")
        print(f"  usrmerge 重写 {usrmerged} 项，跳过顶层目录 {skipped_top} 项，去重 {dup} 项")

        with open(os.path.join(d, "VERSION"), "w") as f:
            f.write("1.0")
        entries.append((f"layer{idx:02d}/layer.tar", dst))
        extra_diff = "sha256:" + sha256_file(dst)
        diff_ids.append(extra_diff)
        print(f"extras 层: {os.path.getsize(dst)/1024/1024:.0f} MB  diff_id={extra_diff[:19]}")

        # ---- 3. 新 config ----
        cfg = json.loads(json.dumps(base_cfg))
        c = cfg["config"]
        c["Entrypoint"] = ["/start.sh"]
        c["Cmd"] = None
        c["User"] = ""
        c["WorkingDir"] = "/"
        env = [e for e in c.get("Env", [])
               if not e.startswith(("TZ=", "XDG_RUNTIME_DIR="))]
        env += ["TZ=Asia/Shanghai", "XDG_RUNTIME_DIR=/tmp/xdg-runtime"]
        c["Env"] = env
        cfg["rootfs"]["diff_ids"] = diff_ids
        cfg.setdefault("history", []).append({
            "created": "2026-10-25T00:00:00Z",
            "created_by": "ADD extras.tar.gz /   (sway + chromium + vaapi + pulseaudio, offline)",
            "comment": "sunshinestream offline runtime layer",
        })
        cfg_bytes = json.dumps(cfg).encode()
        cfg_hex = hashlib.sha256(cfg_bytes).hexdigest()

        # ---- 4. 写 docker save 归档 ----
        docker_manifest = [{
            "Config": f"{cfg_hex}.json",
            "RepoTags": ["sunshine-stream:latest"],
            "Layers": [n for n, _ in entries],
        }]

        with tarfile.open(OUT, "w:gz", compresslevel=6) as out:
            def add_bytes(name, data):
                ti = tarfile.TarInfo(name)
                ti.size = len(data)
                ti.mode = 0o644
                ti.mtime = 0
                out.addfile(ti, io.BytesIO(data))

            add_bytes(f"{cfg_hex}.json", cfg_bytes)
            add_bytes("manifest.json", json.dumps(docker_manifest).encode())
            for name, path in entries:
                ti = tarfile.TarInfo(name)
                ti.size = os.path.getsize(path)
                ti.mode = 0o644
                ti.mtime = 0
                with open(path, "rb") as f:
                    out.addfile(ti, f)

        print(f"完成: {OUT}  {os.path.getsize(OUT)/1024/1024:.0f} MB")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
