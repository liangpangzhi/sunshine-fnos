本目录不再包含 Dockerfile / extras.tar.gz。
完整运行镜像已预构建并存放于 ../images/sunshine-stream.tar.gz，
由 cmd/main 在启动时 docker load 导入，安装过程无需联网、无需 build。
