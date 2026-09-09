# Cloudflare Worker 配置指南

本指南说明如何配置 Cloudflare Worker 来提供伪装网站和反向代理 `/ws` 到 Northflank 容器。

## 前置条件

1. Cloudflare 账号（免费套餐即可）
2. 已部署的 Northflank 服务（`USE_CDN=true` 模式）
3. 自己的域名（已添加到 Cloudflare）

## 步骤 1：获取 Northflank 服务地址

在 Northflank dashboard 中找到你的服务地址，格式为：
```
https://your-service.app.northflank.io
```

## 步骤 2：创建 Cloudflare Worker

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com)
2. 进入 **Workers & Pages** → **Create application**
3. 选择 **Create Worker**
4. 输入 Worker 名称（例如 `nebula-proxy`）
5. 点击 **Deploy**

## 步骤 3：部署 Worker 代码

### 方法 A：通过 Dashboard 直接编辑

1. 点击 **Quick edit**
2. 粘贴以下代码
3. 点击 **Save and deploy**

### 方法 B：通过 Wrangler CLI

```bash
npm install -g wrangler
wrangler login
wrangler init nebula-proxy
cd nebula-proxy
# 编辑 worker.js，粘贴下方代码
wrangler deploy
```

## Worker 代码

```javascript
// Cloudflare Worker for singbox-northflank
// 功能：提供伪装网站 + 反向代理 /ws 到 Northflank

const NORTHFLANK_URL = 'https://your-service.app.northflank.io'; // 替换为你的 Northflank 地址
const WS_PATH = '/ws'; // 与你的 WS_PATH 一致

// 伪装网站 HTML（简化版，实际可以放在 R2 或外部存储）
const HTML_CONTENT = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Nebula CLI - Command Line Tool</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #1f2937; }
        .navbar { background: #fff; border-bottom: 1px solid #e5e7eb; padding: 1rem 0; }
        .container { max-width: 1200px; margin: 0 auto; padding: 0 20px; }
        .navbar .container { display: flex; justify-content: space-between; align-items: center; }
        .logo { font-size: 1.5rem; font-weight: 700; color: #2563eb; text-decoration: none; }
        .nav-links { display: flex; list-style: none; gap: 2rem; }
        .nav-links a { color: #4b5563; text-decoration: none; font-weight: 500; }
        .hero { padding: 6rem 0; text-align: center; background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%); }
        .hero h1 { font-size: 3.5rem; font-weight: 800; color: #1e40af; margin-bottom: 1rem; }
        .subtitle { font-size: 1.25rem; color: #6b7280; margin-bottom: 2rem; }
        .btn { display: inline-block; padding: 0.875rem 2rem; border-radius: 8px; font-weight: 600; text-decoration: none; }
        .btn-primary { background: #2563eb; color: #fff; }
        .btn-primary:hover { background: #1d4ed8; }
        .install-command { background: #1f2937; color: #e5e7eb; padding: 1rem 2rem; border-radius: 8px; display: inline-block; font-family: monospace; margin-top: 1rem; }
        footer { background: #f9fafb; border-top: 1px solid #e5e7eb; padding: 2rem 0; margin-top: 4rem; text-align: center; color: #6b7280; font-size: 0.875rem; }
    </style>
</head>
<body>
    <nav class="navbar">
        <div class="container">
            <a href="/" class="logo">Nebula CLI</a>
            <ul class="nav-links">
                <li><a href="/downloads.html">Downloads</a></li>
                <li><a href="/docs.html">Docs</a></li>
                <li><a href="/about.html">About</a></li>
            </ul>
        </div>
    </nav>
    <main>
        <section class="hero">
            <div class="container">
                <h1>Nebula CLI</h1>
                <p class="subtitle">The command-line tool for managing cloud infrastructure</p>
                <a href="#" class="btn btn-primary">Download v2.1.0</a>
                <div class="install-command">curl -fsSL https://nebula-cli.dev/install.sh | bash</div>
            </div>
        </section>
    </main>
    <footer>
        <div class="container">
            <p>&copy; 2026 Nebula CLI. Open source under MIT License.</p>
        </div>
    </footer>
</body>
</html>
`;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    
    // 处理 WebSocket 请求
    if (url.pathname === WS_PATH || url.pathname.startsWith(WS_PATH + '/')) {
      return handleWebSocket(request, url);
    }
    
    // 处理静态页面请求
    return handleStaticRequest(request, url);
  }
};

async function handleWebSocket(request, url) {
  const targetUrl = new URL(NORTHFLANK_URL + url.pathname + url.search);
  
  try {
    const response = await fetch(targetUrl.toString(), {
      method: request.method,
      headers: request.headers,
      body: request.body
    });
    
    return response;
  } catch (error) {
    console.error('WebSocket proxy error:', error);
    return new Response('Proxy error', { status: 500 });
  }
}

async function handleStaticRequest(request, url) {
  // 简单路由：返回伪装网站 HTML
  // 实际可以扩展为支持多页面
  
  return new Response(HTML_CONTENT, {
    headers: {
      'content-type': 'text/html;charset=UTF-8',
      'cache-control': 'public, max-age=3600'
    }
  });
}
```

## 步骤 4：配置自定义域名

1. 在 Cloudflare Dashboard 进入 **Workers & Pages** → 选择你的 Worker
2. 进入 **Triggers** → **Custom domains**
3. 点击 **Add custom domain**
4. 输入你的域名（例如 `nebula-cli.com`）
5. Cloudflare 会自动创建 DNS 记录

## 步骤 5：更新 Northflank 环境变量

在 Northflank dashboard 设置：

```bash
USE_CDN=true
PORT=443  # 或 8443
```

## 步骤 6：关闭 Health Check

⚠️ **重要**：在 Northflank dashboard 关闭 Health Check，因为 sing-box 不是标准 HTTP 服务。

1. 进入服务详情页
2. 找到 **Health checks** 或 **Monitoring**
3. 关闭或禁用 Health Check

## 验证部署

1. 访问你的域名：`https://your-domain.com`
2. 应该看到伪装网站
3. 使用 sing-box 客户端测试连接

## 高级配置

### 支持多页面

将完整的 HTML 文件存储在 Cloudflare R2 或外部存储，Worker 根据路径返回不同页面。

### 添加缓存

```javascript
// 在 handleStaticRequest 中添加
const cachedResponse = await env.CACHE.get(url.pathname);
if (cachedResponse) {
  return new Response(cachedResponse, {
    headers: { 'content-type': 'text/html' }
  });
}
```

### 日志和监控

在 Worker 设置中启用 **Log streams** 查看访问日志。

## 故障排查

### Q: WebSocket 连接失败？

- 检查 `NORTHFLANK_URL` 是否正确
- 确认 Northflank 服务正在运行
- 检查 `WS_PATH` 是否一致

### Q: 页面显示 404？

- 确认 Worker 已正确部署
- 检查域名 DNS 记录是否指向 Cloudflare

### Q: 速度很慢？

- 检查 Northflank 服务所在区域
- 考虑使用 Cloudflare R2 缓存静态资源

## 费用估算

- **免费套餐**：每天 100,000 次请求，足够个人使用
- **付费套餐**：$5/月，每天 1000 万次请求

## 参考资料

- [Cloudflare Workers 文档](https://developers.cloudflare.com/workers/)
- [Cloudflare WebSocket 支持](https://developers.cloudflare.com/workers/runtime-apis/websockets/)