# sunshinestream（飞牛 FnOS 串流应用）

> 🌐 English version: [README_EN.md](README_EN.md)

把 **飞牛 NAS** 变成一台「串流主机」：**安装时填写任意应用地址**（任何 Web 应用），电视 / 手机 / 平板通过 **Moonlight** 即可全屏串流该应用。NAS 上运行 [Sunshine](https://github.com/SunshineStream/Sunshine) 串流服务端 + 虚拟桌面（Xvfb + Chromium），画面与声音一路送到大屏。

## 特性

- **安装时填地址，装完就能串**：安装向导里填「应用地址 / 应用名称 / 打开方式 / 分辨率」，装好即是你要的应用，不用改配置、不用重建镜像。
- **串流控制台（47991）**：装好后想换应用，打开 `http://NAS-IP:47991` 改地址保存即可，浏览器 2 秒内自动切到新应用——**无需重装**。带地址可达性探测、常用预设、浏览器运行状态。
- **三种打开方式**：全屏沉浸（无地址栏，影视/看板）、窗口 + 地址栏（应用内需跳转）、仅虚拟桌面（不自动开浏览器）。
- **能改、能守、能自愈**：升级时默认沿用你上次的地址（向导里填了新地址才覆盖）；运行期改过的地址不会被升级冲掉；Chromium 崩溃或被杀会自动重启。
- **NVENC 硬件编码**：视频流由 NVIDIA 显卡（如 P620）的 NVENC 直接产出 H.264/HEVC，不占 CPU。
- **音频已修复**：修复了「串流成功但电视无声音」的三个叠加问题（`stream_audio` 开关、声卡抓取错位、PulseAudio 残留状态），详见 [安装配置指南](sunshine-fnos/安装配置指南.md)。
- **一键离线安装**：打包为飞牛 `.fpk`，内置完整运行镜像，应用中心离线安装即可，全程无需联网。

## 快速开始

```text
1) 应用中心 → 手动安装 sunshinestream.fpk
2) 向导里填：应用地址 http://192.168.5.11:5666   应用名称 飞牛影视   全屏沉浸   1920x1080
3) 电视装 Moonlight → 手动添加主机 192.168.5.11 → 4 位 PIN 在 https://NAS-IP:47990 里确认
4) 电视上点主机 → 全屏串流「飞牛影视」
```

想换应用：桌面「串流控制台」→ 改地址 → 保存并切换（或直接访问 `http://NAS-IP:47991`）。

## 目录结构

```
sunshine-fnos/        # 飞牛应用包源码（manifest / docker / ui / wizard / cmd）
  app/docker/         # 容器编排、start.sh（串流目标 + 浏览器守护 + 音频修复）、console.py（串流控制台）、mouse-bridge.py
  app/ui/             # 桌面入口（47990 后台 / 47991 控制台）与图标
  wizard/install      # 安装向导：应用地址 / 名称 / 打开方式 / 分辨率
  cmd/                # 安装/升级/卸载回调（把向导填的地址落盘）
  manifest            # 应用元信息（版本号等）
  sunshinestream.fpk  # 离线安装包（二进制，见 Releases）
  app/images/sunshine-stream.tar.gz  # Docker 镜像（二进制，见 Releases）
Sunshine/             # Sunshine 上游源码（34M，用于追溯音频捕获等实现细节）
build-fpk.py          # 将 sunshine-fnos/ 打包为 .fpk（含权限位/换行符修正与自检）
export-image.sh/.ps1  # 导出 Docker 镜像为 tar.gz
tools/                # 部署 / 诊断辅助脚本（nas-run、nas-upload 等）
离线安装说明.md        # 离线安装步骤
```

## 串流目标是怎么流转的

```
安装向导 wizard_app_url
        │  cmd/install_init 校验并规范化
        ├──> app/docker/app.env      （包内初始值，容器环境变量）
        └──> /var/apps/sunshinestream/var/app.conf  （持久化运行配置）
                                │
串流控制台 47991 改地址 ────────┤
                                ▼
        start.sh 读 app.conf → Chromium 打开该地址 → Xvfb → Sunshine(NVENC) → Moonlight
```

优先级：`app.conf`（控制台修改）> `app.env`（安装向导）> 内置默认值。
升级时向导留空 → 沿用上次的地址；向导填了新地址 → 以新地址为准。

## 构建

```bash
# 打包为 .fpk（产物：sunshine-fnos/sunshinestream.fpk）
python build-fpk.py

# 导出 Docker 镜像（产物：sunshine-fnos/app/images/sunshine-stream.tar.gz）
bash export-image.sh
```

> 二进制产物（`.fpk`、镜像 `tar.gz`）体积较大，**不入库**，请从 GitHub Releases 获取，或本地构建。

## 安装

详见 [离线安装说明.md](离线安装说明.md) 与 [安装配置指南](sunshine-fnos/安装配置指南.md)。简言之：在飞牛应用中心离线安装 `sunshinestream.fpk`，向导里填要串流的应用地址，电视端用 Moonlight 连接 `https://<NAS-IP>:47990` 配对后即可开串。

## 发布版本（Releases）

二进制产物（`.fpk` 安装包、Docker 镜像）体积较大，不纳入 Git，已发布在 GitHub Releases：

- `sunshinestream.fpk`：飞牛应用中心离线安装包
- `sunshine-stream.tar.gz`：Docker 镜像（`docker load` 导入）

下载地址：https://github.com/liangpangzhi/sunshine-fnos/releases

## 许可

Sunshine 本体基于 **GPL-3.0** 许可（见 `Sunshine/`）。本工程在 Sunshine 基础上增加了飞牛应用封装、串流目标可配置与音频/输入适配。
