# sunshinestream（飞牛 FnOS 串流应用）

把 **飞牛 NAS** 变成一台「游戏串流主机」：在 NAS 上运行 [Sunshine](https://github.com/SunshineStream/Sunshine) 串流服务端 + 虚拟桌面（Xvfb + Chromium），电视 / 手机 / 平板通过 **Moonlight** 客户端直接连接，即可在大屏上播放 DecoTV 等网页内容，或串流其他应用。

## 特性

- **NVENC 硬件编码**：视频流由 NVIDIA 显卡（如 P620）的 NVENC 编码器直接产出 H.264/HEVC，不占 CPU。
- **音频已修复**：修复了「串流成功但电视无声音」的三个叠加问题（`stream_audio` 开关、声卡抓取错位、PulseAudio 残留状态），详见 [安装配置指南](sunshine-fnos/安装配置指南.md)。
- **虚拟桌面 + 浏览器**：Xvfb 提供 1080p 虚拟显示，Chromium 打开 DecoTV，配合输入桥接，NAS 能接管物理键鼠。
- **一键离线安装**：打包为飞牛 `.fpk`，应用中心离线安装即可。

## 目录结构

```
sunshine-fnos/        # 飞牛应用包源码（manifest / docker / ui / cmd）
  app/docker/         # 容器编排、start.sh（核心启动与音频修复逻辑）、输入桥接
  app/ui/             # 桌面入口配置与图标
  cmd/                # 安装/卸载/升级回调脚本
  manifest            # 应用元信息（版本号等）
  sunshinestream.fpk  # 离线安装包（二进制，见 Releases）
  app/images/sunshine-stream.tar.gz  # Docker 镜像（二进制，见 Releases）
Sunshine/             # Sunshine 上游源码（34M，用于追溯音频捕获等实现细节）
build-fpk.py          # 将 sunshine-fnos/ 打包为 .fpk
export-image.sh/.ps1  # 导出 Docker 镜像为 tar.gz
tools/                # 部署 / 诊断辅助脚本（nas-run、nas-upload 等）
离线安装说明.md        # 离线安装步骤
```

## 构建

```bash
# 打包为 .fpk（产物：sunshine-fnos/sunshinestream.fpk）
python build-fpk.py

# 导出 Docker 镜像（产物：sunshine-fnos/app/images/sunshine-stream.tar.gz）
bash export-image.sh
```

> 二进制产物（`.fpk`、镜像 `tar.gz`）体积较大，**不入库**，请从 GitHub Releases 获取，或本地构建。

## 安装

详见 [离线安装说明.md](离线安装说明.md) 与 [安装配置指南](sunshine-fnos/安装配置指南.md)。简言之：在飞牛应用中心离线安装 `sunshinestream.fpk`，电视端用 Moonlight 连接 `https://<NAS-IP>:47990`。

## 许可

Sunshine 本体基于 **GPL-3.0** 许可（见 `Sunshine/`）。本工程在 Sunshine 基础上增加了飞牛应用封装与音频/输入适配。
