"""查询 Docker Hub 镜像的 config 与构建历史，用于挑选合适的基础镜像（走 curl，绕过代理问题）。"""
import json
import subprocess
import sys


def curl_json(url, headers=None):
    cmd = ["curl", "-sL", "--connect-timeout", "20", "--max-time", "120"]
    for k, v in (headers or {}).items():
        cmd += ["-H", f"{k}: {v}"]
    cmd.append(url)
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    return json.loads(out)


def token(repo):
    d = curl_json("https://auth.docker.io/token?service=registry.docker.io"
                  f"&scope=repository:{repo}:pull")
    return d["token"]


ACCEPT = ("application/vnd.docker.distribution.manifest.v2+json,"
          "application/vnd.docker.distribution.manifest.list.v2+json,"
          "application/vnd.oci.image.manifest.v1+json,"
          "application/vnd.oci.image.index.v1+json")


def inspect(repo, tag="latest"):
    try:
        tk = token(repo)
        h = {"Authorization": f"Bearer {tk}", "Accept": ACCEPT}
        m = curl_json(f"https://registry-1.docker.io/v2/{repo}/manifests/{tag}", h)
        if "manifests" in m:
            amd = [x for x in m["manifests"]
                   if x.get("platform", {}).get("architecture") == "amd64"]
            if not amd:
                print(f"[{repo}:{tag}] 无 amd64")
                return
            m = curl_json(
                f"https://registry-1.docker.io/v2/{repo}/manifests/{amd[0]['digest']}", h)
        cfg = curl_json(
            f"https://registry-1.docker.io/v2/{repo}/blobs/{m['config']['digest']}", h)
    except Exception as e:
        print(f"[{repo}:{tag}] 查询失败: {e}")
        return

    c = cfg.get("config", {})
    print(f"\n=== {repo}:{tag} ===")
    print("Cmd:", c.get("Cmd"), "| Entrypoint:", c.get("Entrypoint"))
    total = sum(l.get("size", 0) for l in m.get("layers", []))
    print(f"层数: {len(m.get('layers', []))}  解压前总计: {total/1024/1024:.0f} MB")
    keys = ("sway", "gamescope", "chromium", "firefox", "xorg", "xvfb",
            "sunshine", "vaapi", "mesa", "weston", "cage")
    hits = []
    for hst in cfg.get("history", []):
        cb = hst.get("created_by", "")
        low = cb.lower()
        if any(k in low for k in keys):
            hits.append(cb[:150])
    print("构建历史关键行:")
    for x in hits[-15:]:
        print("  -", x)


if __name__ == "__main__":
    targets = sys.argv[1:] or ["gameonwhales/sunshine:latest"]
    for t in targets:
        repo, _, tag = t.partition(":")
        inspect(repo, tag or "latest")
