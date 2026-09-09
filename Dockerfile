# syntax=docker/dockerfile:1

# 固定官方 sing-box 容器镜像版本，避免 Release 资产文件名变化。
FROM ghcr.io/sagernet/sing-box:v1.14.0 AS singbox

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        nginx \
        tini \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p \
        /app/config \
        /app/web \
        /etc/sing-box \
        /etc/nginx/conf.d \
        /var/cache/nginx \
        /var/log/nginx \
        /var/run

# 从官方 sing-box 镜像复制可执行文件。
# 官方镜像的 sing-box 程序通常位于 /usr/local/bin/sing-box。
COPY --from=singbox /usr/local/bin/sing-box /usr/local/bin/sing-box

RUN chmod 0755 /usr/local/bin/sing-box \
    && /usr/local/bin/sing-box version

COPY config/singbox.json.template /app/config/singbox.json.template
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/conf.d/default.conf.template /etc/nginx/conf.d/default.conf.template
COPY web/ /app/web/
COPY entrypoint.sh /app/entrypoint.sh

RUN chmod 0755 /app/entrypoint.sh \
    && nginx -t

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/app/entrypoint.sh"]
