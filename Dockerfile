FROM debian:bookworm-slim

# 关键：这里必须保持原作者的名字，用于下载他预编译好的程序包
ARG GITHUB_REPO="nianzhibai/91"
ARG VERSION="latest"

ENV APP_NAME="video-site-91" \
    FRONTEND_PORT="9191" \
    INSTALL_PATH="/opt/video-site-91" \
    VIDEO_CONFIG="/opt/video-site-91/config.yaml" \
    VIDEO_FRONTEND_DIR="/opt/video-site-91/dist"

WORKDIR $INSTALL_PATH

# 1. 安装核心运行依赖
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl tar ffmpeg openssl iproute2 python3 python3-requests python3-bs4 python3-lxml jq && \
    rm -rf /var/lib/apt/lists/*

# 2. 自动检测架构并从原作者的 GitHub Releases 拉取指定版本
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

# 3. 初始化配置并暴露端口
RUN mkdir -p data && \
    cp config.example.yaml config.yaml && \
    sed -i -E "s#listen: \".*\"#listen: \"0.0.0.0:${FRONTEND_PORT}\"#" config.yaml && \
    SECRET=$(openssl rand -hex 32) && \
    sed -i -E "s#session_secret: \".*\"#session_secret: \"$SECRET\"#" config.yaml && \
    chmod +x server

EXPOSE $FRONTEND_PORT
VOLUME ["/opt/video-site-91/data"]
CMD ["./server"]
