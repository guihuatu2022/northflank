# syntax=docker/dockerfile:1

# Use the official sing-box image as a build stage.
FROM ghcr.io/sagernet/sing-box:v1.14.0 AS singbox

# Runtime image.
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime packages and required tools.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
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

# Copy sing-box binary from the official image.
COPY --from=singbox /usr/local/bin/sing-box /usr/local/bin/sing-box

RUN chmod 0755 /usr/local/bin/sing-box \
    && /usr/local/bin/sing-box version

# Download the latest Komari Agent asset matching the image architecture.
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "$ARCH" in \
        amd64) ASSET_ARCH="amd64" ;; \
        arm64) ASSET_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; \
    esac; \
    ASSET_URL="$(curl -fsSL https://api.github.com/repos/komari-monitor/komari-agent/releases/latest \
        | jq -r --arg arch "$ASSET_ARCH" \
            '.assets[] | select(.name == ("komari-agent-linux-" + $arch)) | .browser_download_url' \
        | head -n 1)"; \
    test -n "$ASSET_URL"; \
    test "$ASSET_URL" != "null"; \
    curl -fsSL "$ASSET_URL" -o /usr/local/bin/komari-agent; \
    chmod 0755 /usr/local/bin/komari-agent; \
    /usr/local/bin/komari-agent --help

# Copy project files.
COPY config/singbox.json.template /app/config/singbox.json.template
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/conf.d/default.conf.template /etc/nginx/conf.d/default.conf.template
COPY web/ /app/web/
COPY entrypoint.sh /app/entrypoint.sh

# Validate runtime files during build.
RUN chmod 0755 /app/entrypoint.sh \
    && nginx -t

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/app/entrypoint.sh"]
