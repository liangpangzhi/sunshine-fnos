# sunshinestream (fnOS Streaming App)

> 🌐 中文版: [README.md](README.md)

Turn a **fnOS (FeiNiu) NAS** into a streaming host: **enter any app URL during installation** (any web app works), then stream that app full-screen to a TV / phone / tablet with **Moonlight**. The NAS runs [Sunshine](https://github.com/SunshineStream/Sunshine) plus a virtual desktop (Xvfb + Chromium).

## Features

- **Pick the app at install time**: the install wizard asks for app URL / display name / launch mode / virtual resolution — what you type is what you stream, no config editing, no image rebuild.
- **Streaming console (port 47991)**: change the streamed app later at `http://NAS-IP:47991`. The browser relaunches with the new URL within ~2 seconds — **no reinstall**. Includes URL reachability probing, presets and browser status.
- **Three launch modes**: fullscreen kiosk (no address bar), windowed with address bar (for apps that need navigation), virtual desktop only (no browser).
- **Survives upgrades and crashes**: an upgrade keeps the previously configured URL unless the wizard supplies a new one; runtime changes are never overwritten; Chromium is supervised and restarted automatically.
- **NVENC hardware encoding**: H.264/HEVC straight from the NVIDIA encoder (e.g. Quadro P620), keeping CPU free.
- **Audio fixed**: three stacked causes of "stream works but TV is silent" are handled (`stream_audio`, wrong sink capture, stale PulseAudio state). See [安装配置指南](sunshine-fnos/安装配置指南.md).
- **Offline one-click install**: shipped as a fnOS `.fpk` with the full runtime image inside — no internet needed at install time.

## Quick start

```text
1) App Center -> Manual install -> sunshinestream.fpk
2) Wizard: URL http://192.168.5.11:5666   Name "FeiNiu Media"   Kiosk   1920x1080
3) Install Moonlight on the TV -> add host 192.168.5.11 -> confirm the 4-digit PIN at https://NAS-IP:47990
4) Tap the host and the app is streamed full-screen
```

Change the app later from the **Streaming Console** desktop shortcut, or `http://NAS-IP:47991`.

## Layout

```
sunshine-fnos/        # fnOS package sources (manifest / docker / ui / wizard / cmd)
  app/docker/         # compose, start.sh (target config + browser supervisor + audio fixes), console.py, mouse-bridge.py
  app/ui/             # desktop entries (47990 admin / 47991 console) and icons
  wizard/install      # install wizard: app URL / name / launch mode / resolution
  cmd/                # install/upgrade/uninstall hooks (persist the wizard input)
  manifest            # app metadata (version, etc.)
  sunshinestream.fpk  # offline installer (binary, see Releases)
  app/images/sunshine-stream.tar.gz  # Docker image (binary, see Releases)
Sunshine/             # Sunshine upstream sources (for tracing audio capture etc.)
build-fpk.py          # pack sunshine-fnos/ into .fpk (fixes perms/line endings, self-checks)
export-image.sh/.ps1  # export the Docker image as tar.gz
tools/                # deploy / diagnostic helpers
```

## How the streaming target flows

```
install wizard: wizard_app_url
        │  cmd/install_init validates + normalizes
        ├──> app/docker/app.env                     (initial value, container env)
        └──> /var/apps/sunshinestream/var/app.conf  (persistent runtime config)
                                │
console 47991 changes URL ──────┤
                                ▼
        start.sh reads app.conf -> Chromium opens the URL -> Xvfb -> Sunshine(NVENC) -> Moonlight
```

Priority: `app.conf` (console changes) > `app.env` (install wizard) > built-in default.
Upgrade with an empty wizard keeps the previous URL; a filled wizard value overrides it.

## Build

```bash
# Build the .fpk (output: sunshine-fnos/sunshinestream.fpk)
python build-fpk.py

# Export the Docker image (output: sunshine-fnos/app/images/sunshine-stream.tar.gz)
bash export-image.sh
```

> Binaries (`.fpk`, image `tar.gz`) are large and **not committed** — grab them from GitHub Releases or build locally.

## Install

See [离线安装说明.md](离线安装说明.md) (Chinese) and [安装配置指南](sunshine-fnos/安装配置指南.md). In short: install `sunshinestream.fpk` from the fnOS App Center offline installer, type the app URL in the wizard, pair Moonlight against `https://<NAS-IP>:47990` and start streaming.

## Releases

- `sunshinestream.fpk` — fnOS offline installer
- `sunshine-stream.tar.gz` — Docker image (`docker load`)

https://github.com/liangpangzhi/sunshine-fnos/releases

## License

Sunshine itself is **GPL-3.0** (see `Sunshine/`). This project adds the fnOS packaging, configurable streaming target, and audio/input adaptations.
