"""通过 SSH 在 NAS 上执行命令。

用法:
  python tools/nas-ssh.py "命令"
  python tools/nas-ssh.py -f script.sh      # 执行本地脚本
"""
import sys
import paramiko

HOST = "192.168.5.11"
PORT = 22
USER = "liang"
PASSWORDS = ["87669305Liang!", "87669305Liang！"]


def connect():
    last = None
    for pwd in PASSWORDS:
        c = paramiko.SSHClient()
        c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            c.connect(HOST, port=PORT, username=USER, password=pwd,
                      timeout=15, banner_timeout=20, auth_timeout=20,
                      look_for_keys=False, allow_agent=False)
            return c, pwd
        except Exception as e:
            last = e
            try:
                c.close()
            except Exception:
                pass
    raise SystemExit(f"SSH 连接失败: {last}")


def run(cmd, timeout=180):
    c, pwd = connect()
    try:
        stdin, stdout, stderr = c.exec_command(cmd, timeout=timeout,
                                               get_pty=False)
        out = stdout.read().decode("utf-8", "replace")
        err = stderr.read().decode("utf-8", "replace")
        code = stdout.channel.recv_exit_status()
        return out, err, code
    finally:
        c.close()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("用法: nas-ssh.py <命令> | -f <脚本>")
    if sys.argv[1] == "-f":
        cmd = open(sys.argv[2], "r", encoding="utf-8").read()
    else:
        cmd = sys.argv[1]
    out, err, code = run(cmd)
    print(out)
    if err.strip():
        print("[stderr]", err.strip()[:2000])
    print("[exit]", code)
