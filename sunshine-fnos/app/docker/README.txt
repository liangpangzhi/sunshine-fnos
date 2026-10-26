本目录不再包含 Dockerfile / extras.tar.gz。
完整运行镜像已预构建并存放于 ../images/sunshine-stream.tar.gz，
由 cmd/main 在启动时 docker load 导入，安装过程无需联网、无需 build。

与「串流目标」相关的文件：
  app.env        安装向导填写的应用地址（APP_URL / APP_TITLE / APP_MODE / APP_RES），
                 cmd/install_init 会按用户输入重写；容器启动时作为初始值读取。
  start.sh       读 /appdata/app.conf（持久化运行配置）→ 决定 Chromium 打开哪个地址；
                 内置浏览器守护，配置变化或浏览器崩溃会自动重启。
  console.py     串流控制台（http://NAS-IP:47991），可随时换地址，无需重装。

优先级：/appdata/app.conf（控制台修改） > app.env（安装向导） > 内置默认值。
