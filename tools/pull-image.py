"""纯 Python 拉取 Docker Hub 镜像（linux/amd64），保存各层 blob 与 config。

用法: python tools/pull-image.py lizardbyte/sunshine:latest-debian-bookworm build/base
"""
import json
import os
import subprocess
import sys


def curl_json(url, headers=None):
    cmd = ["curl", "-sL", "--connect-timeout", "20", "--max-time", "120"]
    for k, v in (headers or {}).items():
        cmd += ["-H", f"{k}: {v}"]
    cmd.append(url)
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    return json.loads(out)


def curl_file(url, path, headers=None):
    cmd = ["curl", "-sL", "--retry", "3", "--connect-timeout", "20",
           "--max-time", "1800", "-o", path]
    for k, v in (headers or {}).items():
        cmd += ["-H", f"{k}: {v}"]
    cmd.append(url)
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"下载失败 {url}: {r.stderr[:200]}")


ACCEPT = ("application/vnd.oci.image.index.v1+json,"
          "application/vnd.docker.distribution.manifest.list.v2+json,"
          "application/vnd.docker.distribution.manifest.v2+json,"
          "application/vnd.oci.image.manifest.v1+json")


def main(ref, outdir):
    repo, _, tag = ref.partition(":")
    tag = tag or "latest"
    os.makedirs(outdir, exist_ok=True)

    tok = curl_json("https://auth.docker.io/token?service=registry.docker.io"
                    f"&scope=repository:{repo}:pull")["token"]
    h = {"Authorization": f"Bearer {tok}", "Accept": ACCEPT}

    m = curl_json(f"https://registry-1.docker.io/v2/{repo}/manifests/{tag}", h)
    if "manifests" in m:
        amd = [x for x in m["manifests"]
               if x.get("platform", {}).get("architecture") == "amd64"
               and x.get("platform", {}).get("os") == "linux"]
        if not amd:
            raise SystemExit("没有 linux/amd64 版本")
        m = curl_json(f"https://registry-1.docker.io/v2/{repo}/manifests/{amd[0]['digest']}", h)

    with open(os.path.join(outdir, "manifest.json"), "w") as f:
        json.dump(m, f, indent=2)

    # config
    cfg_digest = m["config"]["digest"].split(":")[1]
    curl_file(f"https://registry-1.docker.io/v2/{repo}/blobs/{m['config']['digest']}",
              os.path.join(outdir, "config.json"), h)
    print("config:", cfg_digest[:12])

    layers = []
    for i, l in enumerate(m["layers"]):
        digest = l["digest"].split(":")[1]
        path = os.path.join(outdir, f"layer_{i:02d}_{digest[:12]}.tar.gz")
        if not os.path.exists(path):
            curl_file(f"https://registry-1.docker.io/v2/{repo}/blobs/{l['digest']}", path, h)
        size = os.path.getsize(path) / 1024 / 1024
        print(f"layer {i}: {digest[:12]} {size:.1f} MB")
        layers.append({"digest": l["digest"], "file": os.path.basename(path),
                       "mediaType": l["mediaType"], "size": os.path.getsize(path)})

    with open(os.path.join(outdir, "layers.json"), "w") as f:
        json.dump(layers, f, indent=2)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "build/base")
