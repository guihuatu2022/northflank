# singbox-northflank

在 Northflank 上部署 sing-box (vless + ws) 服务，支持 Cloudflare CDN 和 Komari 监控。

## 功能特性

- ✅ **sing-box 核心**: 支持 vless + WebSocket 协议
- ✅ **两种部署模式**: 
  - 本地模式：Nginx 提供伪装网站 + WS 反代
  - CDN 模式：Cloudflare Worker 提供前端和 CDN 加速
- ✅ **Komari Agent 集成**: 可选启用，连接到外部 Komari Server
- ✅ **月度流量归零**: Komari Agent 支持 `--month-rotate` 参数
- ✅ **多页面伪装站**: 英文开源软件镜像站风格
- ✅ **GitHub 自动构建**: 推送代码自动构建镜像

## 环境变量

### 必填变量

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `VLESS_UUID` | vless 用户 UUID | `550e8400-e29b-41d4-a716-446655440000` |
| `WS_PATH` | WebSocket 路径 | `/ws` |
| `PORT` | 容器暴露端口 | `8080` 或 `443` |

### 可选变量

| 变量名 | 说明 | 默认值 | 备注 |
|--------|------|--------|------|
| `USE_CDN` | 是否使用 Cloudflare CDN | `false` | `true` 或 `false` |
| `KOMARI_AGENT_TOKEN` | Komari Agent token | - | 与 `KOMARI_SERVER_URL` 同时存在才启用 |
| `KOMARI_SERVER_URL` | Komari Server endpoint | - | 与 `KOMARI_AGENT_TOKEN` 同时存在才启用 |
| `KOMARI_AGENT_MONTH_RESET` | 月度流量归零 | `true` | `false` 关闭 `--month-rotate` |

## 部署模式

### 模式 A：本地 Nginx（默认）

```bash
VLESS_UUID=your-uuid
WS_PATH=/ws
PORT=8080
USE_CDN=false  # 或不设置
```

**特点**：
- Nginx 监听 `PORT`（例如 8080）
- sing-box 监听 `127.0.0.1:10000`（容器内部）
- Nginx 提供伪装网站 + reverse_proxy `/ws` 到 sing-box
- 用户访问 `https://your-service.app.northflank.io`

### 模式 B：Cloudflare CDN

```bash
VLESS_UUID=your-uuid
WS_PATH=/ws
PORT=443
USE_CDN=true
```

**特点**：
- 不启动 Nginx
- sing-box 监听 `0.0.0.0:PORT`
- Cloudflare Worker 提供伪装站 + 反向代理 `/ws`
- 用户访问你的域名（CNAME 到 Cloudflare）

**⚠️ 重要**：在 Northflank dashboard 关闭 Health Check（sing-box 不是标准 HTTP 服务）

## 部署步骤

### 1. Fork 仓库

Fork 此仓库到你的 GitHub 账号。

### 2. 在 Northflank 创建服务

1. 登录 [Northflank](https://northflank.com)
2. 创建新项目（Project）
3. 创建服务（Service）：
   - 选择 **Connect GitHub repository**
   - 选择你的仓库
   - Build option 选择 **Dockerfile**
   - 指定 Dockerfile 路径（根目录留空）

### 3. 配置环境变量

在 Northflank dashboard 的 **Environment variables** 中设置：

```bash
VLESS_UUID=你的 UUID
WS_PATH=/ws
PORT=8080
# USE_CDN=false  # 默认，不设置即可
# KOMARI_AGENT_TOKEN=你的 token  # 可选
# KOMARI_SERVER_URL=https://你的 komari-server  # 可选
# KOMARI_AGENT_MONTH_RESET=true  # 默认启用
```

### 4. 配置端口

1. 在 **Networking** 标签页添加一个 **Public port**
2. Port 设置为 `8080`（与 `PORT` 环境变量一致）
3. Protocol 选择 **HTTP**
4. Northflank 会自动分配 `*.app.northflank.io` 的 HTTPS 域名

### 5. 部署

- 保存配置后，Northflank 会自动构建并部署
- 首次部署约需 2-3 分钟

### 6. （可选）配置 Cloudflare CDN

如果使用 `USE_CDN=true`：

1. 在 Cloudflare 创建 Worker
2. 部署 `docs/CLOUDFLARE_SETUP.md` 中的 Worker 代码
3. 将你的域名 CNAME 到 Cloudflare
4. 在 Northflank dashboard 关闭 Health Check

## Komari Agent 配置

### 启用 Komari Agent

设置以下两个环境变量：

```bash
KOMARI_AGENT_TOKEN=你的 token
KOMARI_SERVER_URL=https://你的 komari-server.com
```

### 关闭月度流量归零

```bash
KOMARI_AGENT_MONTH_RESET=false
```

### 在 Komari Server 查看

登录你的 Komari Server 面板，应该能看到新节点上线。

## 客户端配置

### sing-box 客户端配置示例

```json
{
  "outbounds": [
    {
      "type": "vless",
      "server": "your-service.app.northflank.io",
      "server_port": 443,
      "uuid": "你的 UUID",
      "transport": {
        "type": "ws",
        "path": "/ws"
      }
    }
  ]
}
```

### 如果使用 Cloudflare CDN

```json
{
  "outbounds": [
    {
      "type": "vless",
      "server": "your-domain.com",
      "server_port": 443,
      "uuid": "你的 UUID",
      "transport": {
        "type": "ws",
        "path": "/ws"
      }
    }
  ]
}
```

## 常见问题

### Q: Northflank 的 Health Check 失败怎么办？

**模式 B（`USE_CDN=true`）**：sing-box 不是标准 HTTP 服务，需要在 Northflank dashboard 关闭 Health Check。

**模式 A（默认）**：Nginx 提供 HTTP 服务，Health Check 应该通过。

### Q: 如何切换 CDN 模式？

修改 `USE_CDN` 环境变量，Northflank 会自动重新部署。

### Q: 端口冲突怎么办？

确保 `PORT` 环境变量与 Northflank 中配置的 Public port 一致。

### Q: 如何更新配置？

修改环境变量后，Northflank 会自动重新部署容器。

## 文件结构

```text
.
├── Dockerfile                    # 镜像构建文件
├── entrypoint.sh                 # 容器启动脚本
├── config/
│   └── singbox.json.template     # sing-box 配置模板
├── nginx/
│   ├── nginx.conf                # Nginx 主配置
│   └── conf.d/
│       └── default.conf.template # Nginx 虚拟主机配置
├── web/                          # 伪装网站
│   ├── index.html
│   ├── downloads.html
│   ├── docs.html
│   ├── changelog.html
│   ├── about.html
│   ├── 404.html
│   └── assets/
│       ├── style.css
│       └── app.js
├── .github/
│   └── workflows/
│       └── build.yml             # GitHub Actions
└── README.md
```

## 安全提示

- 不要在 GitHub 提交中包含敏感信息（UUID、token 等）
- 所有敏感配置都通过 Northflank 环境变量设置
- 定期更新 sing-box 和 Komari Agent 版本

## 许可证

MIT License