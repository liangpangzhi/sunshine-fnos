"""上传本地脚本到 NAS 并以 root 执行（sudo -S 自动喂密码）。

用法: python tools/nas-run.py tools/diag.sh
"""
import os
import sys
import paramiko

HOST, PORT, USER = "192.168.5.11", 22, "liang"
PWD = "87669305Liang!"


def main(local_script):
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, port=PORT, username=USER, password=PWD,
              timeout=15, look_for_keys=False, allow_agent=False)
    try:
        remote = "/tmp/" + os.path.basename(local_script)
        sftp = c.open_sftp()
        sftp.put(local_script, remote)
        sftp.chmod(remote, 0o755)
        sftp.close()

        cmd = f"echo '{PWD}' | sudo -S bash {remote} 2>&1"
        stdin, stdout, stderr = c.exec_command(cmd, timeout=600)
        for line in iter(stdout.readline, ""):
            sys.stdout.write(line)
            sys.stdout.flush()
        code = stdout.channel.recv_exit_status()
        print(f"\n[exit] {code}")
    finally:
        c.close()


if __name__ == "__main__":
    main(sys.argv[1])
