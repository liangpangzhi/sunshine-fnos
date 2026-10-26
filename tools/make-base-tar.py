"""把已下载的镜像层打包成 docker load 可用的 legacy 格式 tar.gz。

用法: python tools/make-base-tar.py build/base out.tar.gz lizardbyte/sunshine:latest-debian-bookworm
"""
import gzip
import json
import os
import shutil
import sys
import tarfile
import tempfile


def main(base_dir, out_path, repo_tag):
    manifest = json.load(open(os.path.join(base_dir, "manifest.json")))
    layers_meta = json.load(open(os.path.join(base_dir, "layers.json")))
    cfg_bytes = open(os.path.join(base_dir, "config.json"), "rb").read()
    cfg_hex = manifest["config"]["digest"].split(":")[1]

    tmp = tempfile.mkdtemp(prefix="dockerlayer-")
    layer_entries = []
    try:
        for i, l in enumerate(layers_meta):
            src = os.path.join(base_dir, l["file"])
            dst_dir = os.path.join(tmp, f"layer{i:02d}")
            os.makedirs(dst_dir, exist_ok=True)
            dst = os.path.join(dst_dir, "layer.tar")
            # 层是 gzip 压缩的 tar，需要解压成 layer.tar
            with gzip.open(src, "rb") as fin, open(dst, "wb") as fout:
                shutil.copyfileobj(fin, fout, 1024 * 1024)
            with open(os.path.join(dst_dir, "VERSION"), "w") as f:
                f.write("1.0")
            layer_entries.append((f"layer{i:02d}/layer.tar", dst))
            print(f"layer{i:02d}: {os.path.getsize(dst)/1024/1024:.0f} MB 解压完成")

        docker_manifest = [{
            "Config": f"{cfg_hex}.json",
            "RepoTags": [repo_tag],
            "Layers": [name for name, _ in layer_entries],
        }]

        with tarfile.open(out_path, "w:gz", compresslevel=6) as out:
            def add_bytes(name, data, mode=0o644):
                ti = tarfile.TarInfo(name)
                ti.size = len(data)
                ti.mode = mode
                ti.mtime = 0
                out.addfile(ti, __import__("io").BytesIO(data))

            add_bytes(f"{cfg_hex}.json", cfg_bytes)
            add_bytes("manifest.json", json.dumps(docker_manifest).encode())
            for name, path in layer_entries:
                ti = tarfile.TarInfo(name)
                ti.size = os.path.getsize(path)
                ti.mode = 0o644
                ti.mtime = 0
                with open(path, "rb") as f:
                    out.addfile(ti, f)
        print(f"完成: {out_path}  {os.path.getsize(out_path)/1024/1024:.0f} MB")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2],
         sys.argv[3] if len(sys.argv) > 3 else "lizardbyte/sunshine:latest-debian-bookworm")
