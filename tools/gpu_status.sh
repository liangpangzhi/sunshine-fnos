#!/bin/bash
echo "=== nvidia-smi（GPU 使用率/显存/进程） ==="
nvidia-smi --query-gpu=utilization.gpu,utilization.encoder,utilization.decoder,memory.used --format=csv 2>&1
echo "--- 使用 GPU 的进程 ---"
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv 2>&1 | head -6
echo
echo "=== Sunshine 编码器选择 ==="
docker logs sunshine-stream 2>&1 | grep -E "Found H.264|Found HEVC|Encoder .* selected|nvenc" | tail -5
echo
echo "=== 容器内 GPU 设备 ==="
docker exec sunshine-stream sh -c "ls /dev/nvidia* 2>/dev/null | head -5; nvidia-smi -L 2>&1 | head -2"
echo
echo "=== 容器内 CPU 占用 TOP ==="
docker exec sunshine-stream sh -c "ps -eo pcpu,comm --sort=-pcpu | head -6"
