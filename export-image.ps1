# 在 Windows（Docker Desktop 已启动）PowerShell 中运行：
#   cd <本目录>\sunshine-fnos\app\docker
#   powershell -ExecutionPolicy Bypass -File ..\..\..\export-image.ps1
#
# 作用：构建包含 sway + Chromium + VAAPI 驱动的完整镜像，并导出为 tar，供飞牛 NAS 离线导入。

$ErrorActionPreference = "Stop"

$dockerDir = Join-Path $PSScriptRoot "sunshine-fnos\app\docker"
$outFile   = Join-Path $PSScriptRoot "sunshine-stream-image.tar"

Write-Host "[1/3] 拉取基础镜像 lizardbyte/sunshine:latest-debian-bookworm (linux/amd64) ..."
docker pull --platform linux/amd64 lizardbyte/sunshine:latest-debian-bookworm

Write-Host "[2/3] 构建完整镜像 sunshine-stream:latest ..."
docker build --platform linux/amd64 -t sunshine-stream:latest $dockerDir

Write-Host "[3/3] 导出镜像到 $outFile ..."
docker save -o $outFile sunshine-stream:latest

$size = [math]::Round((Get-Item $outFile).Length / 1MB, 1)
Write-Host "完成。镜像文件: $outFile ($size MB)"
Write-Host "把该 tar 上传到 NAS，飞牛「Docker → 镜像 → 导入」或 SSH 执行: docker load -i <路径>/sunshine-stream-image.tar"
