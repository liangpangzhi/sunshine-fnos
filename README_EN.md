# sunshinestream (FnOS streaming app)

Turn your **FnOS (飞牛) NAS** into a game-streaming host: run the [Sunshine](https://github.com/SunshineStream/Sunshine) streaming server plus a virtual desktop (Xvfb + Chromium) on the NAS, and connect from a TV / phone / tablet through the **Moonlight** client. This lets you play web content like DecoTV on the big screen, or stream other applications.

> 🇨🇳 中文文档见 [README.md](README.md)

## Features

- **NVENC hardware encoding** — the video stream is produced directly by the NVIDIA GPU's NVENC encoder (e.g. P620) as H.264/HEVC, with no CPU cost.
- **Audio fixed** — resolved three stacked issues that caused "stream works but no sound on the TV" (`stream_audio` switch, wrong audio-sink capture, stale PulseAudio state). See [安装配置指南](sunshine-fnos/安装配置指南.md) (Chinese).
- **Virtual desktop + browser** — Xvfb provides a 1080p virtual display; Chromium opens DecoTV, with an input bridge so the NAS can take over the physical keyboard/mouse.
- **One-click offline install** — packaged as a FnOS `.fpk` for offline installation from the app center.

## Directory layout

```
sunshine-fnos/        # FnOS app package source (manifest / docker / ui / cmd)
  app/docker/         # container orchestration, start.sh (core startup + audio-fix logic), input bridge
  app/ui/             # desktop entry config and icons
  cmd/                # install / uninstall / upgrade callback scripts
  manifest            # app metadata (version, etc.)
  sunshinestream.fpk  # offline install package (binary, see Releases)
  app/images/sunshine-stream.tar.gz  # Docker image (binary, see Releases)
Sunshine/             # Sunshine upstream source (34M, for tracing audio-capture implementation details)
build-fpk.py          # package sunshine-fnos/ into a .fpk
export-image.sh/.ps1  # export the Docker image as a tar.gz
tools/                # deployment / diagnostics helper scripts (nas-run, nas-upload, etc.)
离线安装说明.md        # offline installation steps (Chinese)
```

## Build

```bash
# Package as .fpk (output: sunshine-fnos/sunshinestream.fpk)
python build-fpk.py

# Export the Docker image (output: sunshine-fnos/app/images/sunshine-stream.tar.gz)
bash export-image.sh
```

> Binary artifacts (`.fpk`, image `tar.gz`) are large and **not committed to git** — get them from GitHub Releases, or build them locally.

## Install

See [离线安装说明.md](离线安装说明.md) (Chinese) and [安装配置指南](sunshine-fnos/安装配置指南.md). In short: install `sunshinestream.fpk` offline in the FnOS app center, then connect Moonlight on the TV to `https://<NAS-IP>:47990`.

## Releases

Binary artifacts too large for git are published on GitHub Releases:

- `sunshinestream.fpk` — offline install package for the FnOS app center
- `sunshine-stream.tar.gz` — Docker image (`docker load` to import)

Download from: **https://github.com/liangpangzhi/sunshine-fnos/releases/tag/v3.1.1**

## License

Sunshine itself is licensed under **GPL-3.0** (see `Sunshine/`). This project adds FnOS app packaging and audio/input adaptations on top of Sunshine.
