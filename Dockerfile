FROM debian:bookworm-slim

# 安装依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 创建目录
RUN mkdir -p /etc/sing-box /etc/nginx/conf.d /app/config /app/web

# 安装 sing-box
ARG SINGBOX_VERSION=1.11.2
RUN curl -fsSL -o /tmp/sing-box.tar.gz \
    "https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/sing-box-${SINGBOX_VERSION}-linux-amd64.tar.gz" \
    && tar -xzf /tmp/sing-box.tar.gz -C /tmp \
    && mv /tmp/sing-box /usr/local/bin/ \
    && chmod +x /usr/local/bin/sing-box \
    && rm -rf /tmp/sing-box.tar.gz

# 安装 Komari Agent
ARG KOMARI_AGENT_VERSION=0.5.0
RUN curl -fsSL -o /tmp/komari-agent.tar.gz \
    "https://github.com/komari-monitor/komari-agent/releases/download/v${KOMARI_AGENT_VERSION}/komari-agent-${KOMARI_AGENT_VERSION}-linux-amd64.tar.gz" \
    && tar -xzf /tmp/komari-agent.tar.gz -C /tmp \
    && mv /tmp/komari-agent /usr/local/bin/ \
    && chmod +x /usr/local/bin/komari-agent \
    && rm -rf /tmp/komari-agent.tar.gz

# 复制配置文件
COPY config/singbox.json.template /app/config/
COPY nginx/nginx.conf /etc/nginx/
COPY nginx/conf.d/default.conf.template /etc/nginx/conf.d/

# 复制伪装网站
COPY web/ /app/web/

# 复制启动脚本
COPY entrypoint.sh /app/
RUN chmod +x /app/entrypoint.sh

# 清理
RUN apt-get clean && rm -rf /var/cache/apt/*

# 默认命令
CMD ["/app/entrypoint.sh"]