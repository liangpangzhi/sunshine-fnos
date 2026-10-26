"""上传本地文件到 NAS（SFTP，带进度）。

用法: python tools/nas-upload.py 本地文件 远程路径
"""
import os
import sys
import time
import paramiko

HOST, PORT, USER, PWD = "192.168.5.11", 22, "liang", "87669305Liang!"


def main(local, remote):
    size = os.path.getsize(local)
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, port=PORT, username=USER, password=PWD,
              timeout=15, look_for_keys=False, allow_agent=False)
    try:
        sftp = c.open_sftp()
        start = time.time()
        last = [0]

        def cb(done, total):
            pct = done * 100 // total
            if pct >= last[0] + 5 or done == total:
                last[0] = pct
                speed = done / max(time.time() - start, 0.1) / 1024 / 1024
                print(f"  {pct:3d}%  {done/1024/1024:6.0f}/{total/1024/1024:.0f} MB"
                      f"  {speed:.1f} MB/s", flush=True)

        sftp.put(local, remote, callback=cb)
        sftp.close()
        print(f"上传完成: {remote} ({size/1024/1024:.0f} MB, "
              f"{time.time()-start:.0f}s)")
    finally:
        c.close()


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
