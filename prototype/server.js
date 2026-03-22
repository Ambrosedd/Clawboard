const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname);
const HOST = process.env.HOST || '0.0.0.0';
const PORT = Number(process.env.PORT || 4321);

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.txt': 'text/plain; charset=utf-8',
  '.md': 'text/markdown; charset=utf-8'
};

function safeJoin(root, targetPath) {
  const filePath = path.resolve(root, '.' + targetPath);
  if (!filePath.startsWith(root)) return null;
  return filePath;
}

function renderDir(urlPath, dirPath) {
  const items = fs.readdirSync(dirPath, { withFileTypes: true })
    .sort((a, b) => Number(b.isDirectory()) - Number(a.isDirectory()) || a.name.localeCompare(b.name, 'zh-CN'));

  const parent = urlPath === '/' ? '' : `<li><a href="${path.posix.dirname(urlPath.endsWith('/') ? urlPath.slice(0, -1) : urlPath) || '/'}">..</a></li>`;
  const list = items.map(item => {
    const name = item.name + (item.isDirectory() ? '/' : '');
    const href = path.posix.join(urlPath, item.name) + (item.isDirectory() ? '/' : '');
    return `<li><a href="${href}">${name}</a></li>`;
  }).join('\n');

  return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>prototype-app-first files</title>
  <style>
    body{font-family:-apple-system,BlinkMacSystemFont,"SF Pro Display","PingFang SC",sans-serif;background:#0f1220;color:#eef2ff;padding:32px;line-height:1.6}
    .card{max-width:860px;margin:0 auto;background:#171b2e;border:1px solid rgba(255,255,255,.08);border-radius:20px;padding:24px}
    h1{margin-top:0;font-size:28px}
    p{color:#a9b3d1}
    a{color:#9fb1ff;text-decoration:none}
    ul{list-style:none;padding:0;margin:20px 0 0}
    li{padding:10px 0;border-top:1px solid rgba(255,255,255,.06)}
  </style>
</head>
<body>
  <div class="card">
    <h1>prototype-app-first 文件服务器</h1>
    <p>可以直接打开 <a href="/index.html">/index.html</a> 查看原型，也可以下载截图文件。</p>
    <ul>${parent}${list}</ul>
  </div>
</body>
</html>`;
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const pathname = decodeURIComponent(url.pathname);
  let target = safeJoin(ROOT, pathname);

  if (!target) {
    res.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' });
    return res.end('Forbidden');
  }

  try {
    let stat = fs.existsSync(target) ? fs.statSync(target) : null;

    if (!stat && pathname === '/') {
      target = path.join(ROOT, 'index.html');
      stat = fs.existsSync(target) ? fs.statSync(target) : null;
    }

    if (!stat) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      return res.end('Not Found');
    }

    if (stat.isDirectory()) {
      const html = renderDir(pathname.endsWith('/') ? pathname : pathname + '/', target);
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      return res.end(html);
    }

    res.writeHead(200, {
      'Content-Type': MIME[path.extname(target).toLowerCase()] || 'application/octet-stream',
      'Cache-Control': 'no-cache'
    });
    fs.createReadStream(target).pipe(res);
  } catch (err) {
    res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Server Error\n' + err.message);
  }
});

server.listen(PORT, HOST, () => {
  console.log(`Serving ${ROOT} at http://${HOST}:${PORT}`);
});
