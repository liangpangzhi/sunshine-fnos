"""离线组装 Sunshine 运行环境（sway + chromium + 字体 + VAAPI）为一个 tar 层。

不依赖 Docker / Linux：直接读取 .deb 包内的 data.tar 成员，写入新的 tar.gz 层，
供 Dockerfile 用 ADD 叠加到 lizardbyte/sunshine 基础镜像上（构建时零联网）。

用法:
  python tools/build-extras.py
"""
import bz2
import gzip
import io
import json
import lzma
import os
import subprocess
import sys
import tarfile
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build")
BASE = os.path.join(BUILD, "base")
DEBS = os.path.join(BUILD, "debs")
MIRROR = "https://mirrors.aliyun.com/debian"
SUITE = "bookworm"

# 需要安装的种子包
SEEDS = [
    "chromium",
    "xvfb",
    "x11-utils",
    "xauth",
    "sway",
    "fonts-noto-cjk",
    "fonts-noto-color-emoji",
    "mesa-va-drivers",
    "libgl1-mesa-dri",
    "pulseaudio",
    "pulseaudio-utils",
    "libva2",
    "libva-drm2",
    "libva-utils",
    "dbus",
    "dbus-x11",
    "python3",
    "python3-evdev",
    "python3-xlib",
]


# ---------------------------------------------------------------- 工具函数
def curl(url, path=None, quiet=True):
    cmd = ["curl", "-sL", "--retry", "3", "--connect-timeout", "20",
           "--max-time", "1800"]
    if path:
        cmd += ["-o", path]
    cmd.append(url)
    r = subprocess.run(cmd, capture_output=True, text=(path is None))
    if r.returncode != 0:
        raise RuntimeError(f"curl 失败 {url}: {r.stderr[:200]}")
    return r.stdout


def norm(name):
    """标准化 tar 成员路径，去掉开头的 ./"""
    while name.startswith("./"):
        name = name[2:]
    return name.rstrip("/")


def decompress_blob(data, member_name):
    """按扩展名解压 deb 内部成员"""
    if member_name.endswith(".xz"):
        return lzma.decompress(data)
    if member_name.endswith(".gz"):
        return gzip.decompress(data)
    if member_name.endswith(".bz2"):
        return bz2.decompress(data)
    if member_name.endswith(".zst"):
        try:
            import zstandard  # noqa
            return zstandard.ZstdDecompressor().decompress(data)
        except ImportError:
            raise SystemExit("需要 zstandard 包处理 .zst，请 pip install zstandard")
    return data


def read_ar(data):
    """解析 .deb（ar 归档），返回 {成员名: bytes}"""
    if not data.startswith(b"!<arch>\n"):
        raise ValueError("不是 ar 归档")
    pos = 8
    out = {}
    while pos + 60 <= len(data):
        header = data[pos:pos + 60]
        name = header[0:16].decode().strip().rstrip("/")
        size = int(header[48:58].decode().strip())
        pos += 60
        out[name] = data[pos:pos + size]
        pos += size + (size % 2)
    return out


# ---------------------------------------------------------------- 基础镜像索引
def index_base():
    """读取基础镜像层，得到已有路径、已有 .so 名、已安装 dpkg 包"""
    layers = json.load(open(os.path.join(BASE, "layers.json")))
    paths = set()
    sonames = set()
    installed = {}
    for l in layers:
        p = os.path.join(BASE, l["file"])
        with tarfile.open(p, "r:gz") as t:
            for m in t:
                n = norm(m.name)
                if not n:
                    continue
                if ".wh." in os.path.basename(n):
                    continue
                paths.add(n)
                bn = os.path.basename(n)
                if ".so" in bn:
                    sonames.add(bn)
                if n == "var/lib/dpkg/status":
                    f = t.extractfile(m)
                    if f:
                        installed = parse_status(f.read().decode("utf-8", "replace"))
    return paths, sonames, installed


def parse_status(text):
    out = {}
    for block in text.split("\n\n"):
        name = ver = None
        status = None
        for line in block.splitlines():
            if line.startswith("Package: "):
                name = line[9:].strip()
            elif line.startswith("Version: "):
                ver = line[9:].strip()
            elif line.startswith("Status: "):
                status = line[8:].strip()
        if name and ver and status and "installed" in status:
            out[name] = ver
    return out


# ---------------------------------------------------------------- 包索引
def load_packages():
    idx = os.path.join(BUILD, "Packages.xz")
    if not os.path.exists(idx):
        url = f"{MIRROR}/dists/{SUITE}/main/binary-amd64/Packages.xz"
        print("下载包索引:", url)
        curl(url, idx)
    print("解析包索引 ...")
    with lzma.open(idx, "rt", encoding="utf-8", errors="replace") as f:
        text = f.read()

    pkgs = {}
    for block in text.split("\n\n"):
        info = {}
        for line in block.splitlines():
            if line.startswith(" ") or ":" not in line:
                continue
            k, v = line.split(":", 1)
            info[k.strip()] = v.strip()
        name = info.get("Package")
        if not name:
            continue
        arch = info.get("Architecture", "")
        if arch not in ("amd64", "all"):
            continue
        # 同名包优先 amd64
        if name in pkgs and pkgs[name].get("Architecture") == "amd64":
            continue
        info["_deps"] = parse_deps(info)
        pkgs[name] = info
    print(f"索引包数: {len(pkgs)}")
    return pkgs


def parse_deps(info):
    out = []
    for key in ("Pre-Depends", "Depends"):
        raw = info.get(key, "")
        if not raw:
            continue
        for clause in raw.split(","):
            alts = [a.strip() for a in clause.split("|") if a.strip()]
            names = []
            for a in alts:
                n = a.split("(")[0].strip()
                n = n.split(":")[0].strip()
                if n:
                    names.append(n)
            if names:
                out.append(names)
    return out


def resolve(seeds, pkgs, installed):
    """贪心解析依赖闭包"""
    chosen = []
    seen = set()
    queue = list(seeds)
    missing = []
    while queue:
        name = queue.pop(0)
        if name in seen:
            continue
        seen.add(name)
        if name not in pkgs:
            # 基础镜像里已有？或虚拟包
            if name in installed:
                continue
            providers = [p for p in pkgs.values()
                         if name in p.get("Provides", "").replace(",", " ").split()]
            if providers:
                pn = providers[0]["Package"]
                if pn not in seen:
                    queue.append(pn)
                continue
            missing.append(name)
            continue
        info = pkgs[name]
        if name in installed and installed[name] == info.get("Version"):
            # 基础镜像已是同一版本，跳过（不重复打包）
            continue
        chosen.append(name)
        for alts in info["_deps"]:
            have = [a for a in alts if a in pkgs or a in installed]
            pick = have[0] if have else alts[0]
            if pick not in seen:
                queue.append(pick)
    return chosen, missing


def download_debs(names, pkgs):
    os.makedirs(DEBS, exist_ok=True)
    files = []
    total = 0
    for i, name in enumerate(names, 1):
        info = pkgs[name]
        fn = os.path.basename(info["Filename"])
        path = os.path.join(DEBS, fn)
        if not os.path.exists(path):
            url = f"{MIRROR}/{info['Filename']}"
            curl(url, path)
        size = os.path.getsize(path)
        total += size
        files.append(path)
        print(f"  [{i}/{len(names)}] {name:32s} {size/1024/1024:6.1f} MB")
    print(f"共 {len(files)} 个 deb，合计 {total/1024/1024:.0f} MB")
    return files


# ---------------------------------------------------------------- 组装层
def build_layer(deb_files, out_path, extra_files):
    """把各个 deb 的 data.tar 成员写入新层（同名路径保留首次出现）"""
    seen = set()
    count = 0
    total_bytes = 0
    with tarfile.open(out_path, "w:gz", compresslevel=6) as out:
        # 先写自定义文件（start.sh、sway 配置）
        for src, dest, mode in extra_files:
            ti = tarfile.TarInfo(dest)
            data = open(src, "rb").read()
            ti.size = len(data)
            ti.mode = mode
            ti.mtime = 0
            ti.uid = ti.gid = 0
            out.addfile(ti, io.BytesIO(data))
            seen.add(dest)
            count += 1

        for deb in deb_files:
            raw = open(deb, "rb").read()
            members = read_ar(raw)
            data_name = next((k for k in members if k.startswith("data.tar")), None)
            if not data_name:
                raise SystemExit(f"{deb} 缺少 data.tar")
            inner = decompress_blob(members[data_name], data_name)
            with tarfile.open(fileobj=io.BytesIO(inner), mode="r:") as t:
                for m in t:
                    n = norm(m.name)
                    if not n or n in seen:
                        continue
                    seen.add(n)
                    m.name = n
                    m.uid = m.gid = 0
                    m.uname = m.gname = ""
                    if m.isfile():
                        f = t.extractfile(m)
                        out.addfile(m, f)
                        total_bytes += m.size
                    else:
                        out.addfile(m)
                    count += 1
    print(f"层已生成: {out_path}  {os.path.getsize(out_path)/1024/1024:.0f} MB, "
          f"成员 {count} 个, 文件内容 {total_bytes/1024/1024:.0f} MB")


# ---------------------------------------------------------------- ELF 依赖校验
def elf_needed(path_or_bytes):
    data = path_or_bytes
    if len(data) < 64 or data[:4] != b"\x7fELF":
        return None
    is64 = data[4] == 2
    little = data[5] == 1
    order = "little" if little else "big"
    import struct

    def u(fmt, off):
        return struct.unpack_from(("<" if little else ">") + fmt, data, off)[0]

    if is64:
        e_phoff = u("Q", 0x20)
        e_phentsize = u("H", 0x36)
        e_phnum = u("H", 0x38)
    else:
        e_phoff = u("I", 0x1C)
        e_phentsize = u("H", 0x2A)
        e_phnum = u("H", 0x2C)

    loads, dyn = [], None
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        if is64:
            p_type = u("I", off)
            p_offset = u("Q", off + 0x08)
            p_vaddr = u("Q", off + 0x10)
            p_filesz = u("Q", off + 0x20)
        else:
            p_type = u("I", off)
            p_offset = u("I", off + 0x04)
            p_vaddr = u("I", off + 0x08)
            p_filesz = u("I", off + 0x10)
        if p_type == 1:  # PT_LOAD
            loads.append((p_vaddr, p_offset, p_filesz))
        elif p_type == 2:  # PT_DYNAMIC
            dyn = (p_offset, p_filesz)
    if not dyn:
        return []

    entsize = 16 if is64 else 8
    strtab_off = None
    needed_offsets = []
    off, size = dyn
    pos = off
    while pos < off + size:
        if is64:
            tag = u("q", pos)
            val = u("Q", pos + 8)
        else:
            tag = u("i", pos)
            val = u("I", pos + 4)
        if tag == 0:
            break
        if tag == 1:
            needed_offsets.append(val)
        elif tag == 5:
            strtab_off = val
        pos += entsize

    if strtab_off is None:
        return []

    # vaddr -> file offset
    strtab_file = None
    for vaddr, foff, fsz in loads:
        if vaddr <= strtab_off < vaddr + fsz:
            strtab_file = foff + (strtab_off - vaddr)
            break
    if strtab_file is None:
        return []

    out = []
    for n in needed_offsets:
        p = strtab_file + n
        end = data.find(b"\x00", p)
        out.append(data[p:end].decode("utf-8", "replace"))
    return out


def verify_layer(base_sonames, deb_files, bins):
    """检查关键可执行文件的动态库依赖是否都能满足"""
    provided = set(base_sonames)
    needed = {}

    # 收集 deb 提供的 .so 名 + 关键二进制
    for deb in deb_files:
        raw = open(deb, "rb").read()
        members = read_ar(raw)
        dn = next(k for k in members if k.startswith("data.tar"))
        inner = decompress_blob(members[dn], dn)
        with tarfile.open(fileobj=io.BytesIO(inner), mode="r:") as t:
            for m in t:
                n = norm(m.name)
                if ".so" in os.path.basename(n):
                    provided.add(os.path.basename(n))
                if not m.isfile():
                    continue
                base = os.path.basename(n)
                if base in bins:
                    f = t.extractfile(m)
                    try:
                        deps = elf_needed(f.read())
                    except Exception as e:
                        print(f"  解析失败 {n}: {e}")
                        continue
                    if deps:
                        needed[n] = deps

    missing = {}
    for path, deps in needed.items():
        miss = [d for d in deps if d not in provided]
        if miss:
            missing[path] = miss
    return needed, missing


def main():
    print("== 1. 索引基础镜像 ==")
    base_paths, base_sonames, installed = index_base()
    print(f"基础镜像路径 {len(base_paths)} 个，.so {len(base_sonames)} 个，"
          f"已装 dpkg 包 {len(installed)} 个")

    print("== 2. 解析依赖 ==")
    pkgs = load_packages()
    chosen, missing = resolve(SEEDS, pkgs, installed)
    print(f"需新增 {len(chosen)} 个包" + (f"，无法解析: {missing}" if missing else ""))

    print("== 3. 下载 deb ==")
    deb_files = download_debs(chosen, pkgs)

    print("== 4. 校验 ELF 依赖 ==")
    bins = {"chromium", "sway", "sunshine", "vainfo", "chromium-sandbox"}
    needed, miss = verify_layer(base_sonames, deb_files, bins)
    for p, deps in needed.items():
        print(f"  {p}: {len(deps)} 个依赖")
    if miss:
        print("  ⚠️ 缺失依赖:")
        for p, deps in miss.items():
            print(f"    {p}: {', '.join(deps[:12])}")
    else:
        print("  ✅ 关键二进制的动态库依赖全部满足")

    print("== 5. 生成层 ==")
    extras = [
        (os.path.join(ROOT, "sunshine-fnos", "app", "docker", "start.sh"),
         "start.sh", 0o755),
        (os.path.join(ROOT, "sunshine-fnos", "app", "docker", "sway-sunshine.conf"),
         "etc/sway/sunshine-sway.conf", 0o644),
        (os.path.join(ROOT, "sunshine-fnos", "app", "docker", "mouse-bridge.py"),
         "usr/local/bin/mouse-bridge.py", 0o755),
    ]
    out = os.path.join(ROOT, "sunshine-fnos", "app", "docker", "extras.tar.gz")
    build_layer(deb_files, out, extras)
    print("完成:", out)


if __name__ == "__main__":
    main()
