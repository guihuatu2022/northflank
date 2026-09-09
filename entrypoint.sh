#!/bin/bash
set -e

echo "=== Starting singbox-northflank container ==="

# ============================================
# 1. 检查必填变量
# ============================================
if [ -z "$VLESS_UUID" ] || [ -z "$WS_PATH" ] || [ -z "$PORT" ]; then
  echo "ERROR: VLESS_UUID, WS_PATH, and PORT are required environment variables"
  echo "Please set these variables in Northflank dashboard"
  exit 1
fi

echo "✓ Required variables checked"

# ============================================
# 2. 判断 CDN 模式
# ============================================
if [ "$USE_CDN" = "true" ]; then
  echo "→ CDN mode: Cloudflare enabled"
  SINGBOX_LISTEN="0.0.0.0"
  SINGBOX_PORT="$PORT"
  START_NGINX="false"
else
  echo "→ CDN mode: Local Nginx (default)"
  SINGBOX_LISTEN="127.0.0.1"
  SINGBOX_PORT="10000"
  START_NGINX="true"
fi

# ============================================
# 3. 判断 Komari Agent
# ============================================
if [ -n "$KOMARI_AGENT_TOKEN" ] && [ -n "$KOMARI_SERVER_URL" ]; then
  echo "→ Komari Agent: Enabled"
  START_KOMARI_AGENT="true"
  
  # 修复：官方格式为 --month-rotate 1 (开启) 或 --month-rotate 0 (关闭)
  if [ "$KOMARI_AGENT_MONTH_RESET" = "false" ]; then
    MONTH_ROTATE_FLAG="--month-rotate 0"
    echo "  - Monthly traffic reset: Disabled"
  else
    MONTH_ROTATE_FLAG="--month-rotate 1"
    echo "  - Monthly traffic reset: Enabled"
  fi
else
  echo "→ Komari Agent: Disabled (missing KOMARI_AGENT_TOKEN or KOMARI_SERVER_URL)"
  START_KOMARI_AGENT="false"
  MONTH_ROTATE_FLAG=""
fi

# ============================================
# 4. 生成 sing-box 配置
# ============================================
echo "→ Generating sing-box configuration..."

sed -e "s|{{LISTEN_ADDR}}|$SINGBOX_LISTEN|g" \
    -e "s|{{LISTEN_PORT}}|$SINGBOX_PORT|g" \
    -e "s|{{UUID}}|$VLESS_UUID|g" \
    -e "s|{{WS_PATH}}|$WS_PATH|g" \
    /app/config/singbox.json.template > /etc/sing-box/config.json

echo "✓ sing-box configuration generated"

# ============================================
# 5. 生成 Nginx 配置（如果需要）
# ============================================
if [ "$START_NGINX" = "true" ]; then
  echo "→ Generating Nginx configuration..."
  
  # 替换 default.conf 中的变量
  sed -e "s|{{PORT}}|$PORT|g" \
      -e "s|{{WS_PATH}}|$WS_PATH|g" \
      /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf
  
  echo "✓ Nginx configuration generated"
fi

# ============================================
# 6. 启动服务
# ============================================
echo ""
echo "=== Starting services ==="

# 启动 Nginx（如果启用）
if [ "$START_NGINX" = "true" ]; then
  echo "→ Starting Nginx on port $PORT..."
  nginx -g 'daemon off;' &
  NGINX_PID=$!
  sleep 1
  echo "✓ Nginx started (PID: $NGINX_PID)"
fi

# 启动 Komari Agent（如果启用）
if [ "$START_KOMARI_AGENT" = "true" ]; then
  echo "→ Starting Komari Agent..."
  echo "  - Endpoint: $KOMARI_SERVER_URL"
  echo "  - Token: ${KOMARI_AGENT_TOKEN:0:8}... (masked)"
  
  # 检查二进制是否存在，避免直接退出
  if [ -x "/usr/local/bin/komari-agent" ]; then
    /usr/local/bin/komari-agent \
      --endpoint "$KOMARI_SERVER_URL" \
      --token "$KOMARI_AGENT_TOKEN" \
      $MONTH_ROTATE_FLAG &
    KOMARI_PID=$!
    echo "✓ Komari Agent process started (PID: $KOMARI_PID)"
  else
    echo "ERROR: /usr/local/bin/komari-agent binary not found!"
  fi
fi

# 启动 sing-box（前台运行）
echo "→ Starting sing-box..."
echo "  - Listen: $SINGBOX_LISTEN:$SINGBOX_PORT"
echo "  - WebSocket path: $WS_PATH"
echo "  - UUID: ${VLESS_UUID:0:8}... (masked)"

exec /usr/local/bin/sing-box run -c /etc/sing-box/config.json
