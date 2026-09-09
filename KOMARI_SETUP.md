# Komari Server 配置指南

本指南说明如何配置 Komari Server 来监控你的 Northflank 服务。

## 什么是 Komari？

Komari 是一个轻量级自托管服务器监控工具，类似哪吒探针。

- **Komari Server**：监控面板，运行在你的 VPS 上
- **Komari Agent**：探针，运行在被监控的服务器上

## 前置条件

- 已部署 Komari Server（在其他 VPS 上）
- Northflank 服务已运行

## 步骤 1：在 Komari Server 添加节点

1. 登录你的 Komari Server 面板
2. 进入 **节点管理** → **添加节点**
3. 记录以下信息：
   - **Token**：节点认证令牌
   - **Server URL**：Komari Server 地址（例如 `https://monitor.your-domain.com`）

## 步骤 2：在 Northflank 配置环境变量

在 Northflank dashboard 的 **Environment variables** 中设置：

```bash
KOMARI_AGENT_TOKEN=你的 token
KOMARI_SERVER_URL=https://monitor.your-domain.com
KOMARI_AGENT_MONTH_RESET=true  # 可选，默认启用月度流量归零
```

## 步骤 3：重新部署

保存环境变量后，Northflank 会自动重新部署容器，Komari Agent 会立即启动。

## 步骤 4：验证连接

1. 在 Komari Server 面板查看节点列表
2. 应该能看到新节点上线
3. 检查 CPU、内存、磁盘、网络等指标是否正常上报

## 环境变量说明

| 变量名 | 说明 | 必填 | 默认值 |
|--------|------|------|--------|
| `KOMARI_AGENT_TOKEN` | 节点认证令牌 | 是（启用 Agent 时） | - |
| `KOMARI_SERVER_URL` | Komari Server 地址 | 是（启用 Agent 时） | - |
| `KOMARI_AGENT_MONTH_RESET` | 月度流量归零 | 否 | `true` |

### 月度流量归零

- `KOMARI_AGENT_MONTH_RESET=true`（默认）：启用 `--month-rotate` 参数，流量每月自动归零
- `KOMARI_AGENT_MONTH_RESET=false`：不启用，流量累计

## 故障排查

### Q: 节点不上线？

1. 检查 `KOMARI_SERVER_URL` 是否可访问
2. 确认 `KOMARI_AGENT_TOKEN` 正确
3. 查看 Northflank 容器日志

### Q: 日志报错 "connection refused"？

- 确认 Komari Server 正在运行
- 检查防火墙设置，确保端口开放
- 确认 `KOMARI_SERVER_URL` 使用 HTTPS（推荐）

### Q: 流量统计不准确？

- 启用 `KOMARI_AGENT_MONTH_RESET=true`
- 等待下一个统计周期

## 在 Komari Server 查看监控

登录 Komari Server 面板后，你可以看到：

- CPU 使用率
- 内存使用率
- 磁盘使用率
- 网络流量（上传/下载）
- 系统负载
- 在线状态

## 高级配置

### 自定义 Agent 名称

在 Komari Server 面板中修改节点名称。

### 配置告警

在 Komari Server 设置告警规则：

- CPU 使用率 > 90%
- 内存使用率 > 80%
- 磁盘使用率 > 90%
- 节点离线

### 多节点监控

重复上述步骤，在多个 Northflank 服务或其他 VPS 上部署 Komari Agent。

## 参考资料

- [Komari 官方文档](https://komari-document.pages.dev/)
- [Komari GitHub](https://github.com/komari-monitor/komari)