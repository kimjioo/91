# 使用体积较小的 Debian Bookworm 作为基础镜像
FROM debian:bookworm-slim

# 设置环境变量 (对应原脚本的配置)
ENV APP_NAME="video-site-91" \
    GITHUB_REPO="nianzhibai/91" \
    VERSION="latest" \
    FRONTEND_PORT="9191" \
    INSTALL_PATH="/opt/video-site-91" \
    VIDEO_CONFIG="/opt/video-site-91/config.yaml" \
    VIDEO_FRONTEND_DIR="/opt/video-site-91/dist"

# 设置工作目录
WORKDIR $INSTALL_PATH

# 1. 安装核心运行依赖 (等同于 install_deps 步骤)
# 使用 --no-install-recommends 减小镜像体积，安装后清理 apt 缓存
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl tar ffmpeg openssl iproute2 python3 python3-requests python3-bs4 python3-lxml jq && \
    rm -rf /var/lib/apt/lists/*

# 2. 下载并解压发布包 (等同于 fetch_and_unpack 步骤)
# 自动检测架构并从 GitHub 拉取指定版本
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; elif [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; else exit 1; fi && \
    if [ "$VERSION" = "latest" ]; then \
        URL=$(curl -s https://api.github.com/repos/${GITHUB_REPO}/releases/latest | jq -r ".assets[] | select(.name | endswith(\"linux-${ARCH}.tar.gz\")) | .browser_download_url"); \
    else \
        URL="https://github.com/${GITHUB_REPO}/releases/download/${VERSION}/${APP_NAME}-linux-${ARCH}.tar.gz"; \
    fi && \
    echo "Downloading $URL" && \
    curl -L -o release.tar.gz "$URL" && \
    tar -xzf release.tar.gz --strip-components=1 && \
    rm release.tar.gz

# 3. 初始化配置 (等同于 prepare_config 步骤)
RUN mkdir -p data && \
    cp config.example.yaml config.yaml && \
    sed -i -E "s#listen: \".*\"#listen: \"0.0.0.0:${FRONTEND_PORT}\"#" config.yaml && \
    SECRET=$(openssl rand -hex 32) && \
    sed -i -E "s#session_secret: \".*\"#session_secret: \"$SECRET\"#" config.yaml && \
    chmod +x server

# 暴露前端端口
EXPOSE $FRONTEND_PORT

# 声明数据卷，确保容器重启或重建时，用户的视频/数据库等数据不会丢失
VOLUME ["/opt/video-site-91/data"]

# 启动命令 (前台运行)
CMD ["./server"]
