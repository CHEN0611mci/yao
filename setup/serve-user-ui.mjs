// Dependency-free production preview. API/profile requests always reach the backend.
import http from 'node:http'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
const adminMode = process.env.MALL_UI_MODE === 'admin'
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), adminMode ? '../admin-ui/dist' : '../user-ui/dist')
const port = Number(process.env.USER_UI_PORT || 81)
const backend = new URL(process.env.USER_UI_API_TARGET || 'http://127.0.0.1:8080')
if (backend.protocol !== 'http:') throw new Error('Local backend URL must use http:')
const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.json': 'application/json; charset=utf-8', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.ico': 'image/x-icon', '.woff2': 'font/woff2' }
export const server = http.createServer((request, response) => {
  let pathname
  try { pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname) }
  catch { response.writeHead(400).end(); return }
  if (/^\/(api|profile)(\/|$)/.test(pathname) || (adminMode && /^\/prod-api(\/|$)/.test(pathname))) {
    const upstream = http.request({ hostname: backend.hostname, port: backend.port || 80,
      path: adminMode ? request.url.replace(/^\/prod-api(?=\/|\?|$)/, '') || '/' : request.url, method: request.method,
      headers: { ...request.headers, host: backend.host } }, incoming => {
      response.writeHead(incoming.statusCode, incoming.headers); incoming.pipe(response)
    })
    upstream.setTimeout(20000, () => upstream.destroy(new Error('Backend timeout')))
    upstream.on('error', () => {
      if (response.headersSent) { response.destroy(); return }
      response.writeHead(503, { 'Content-Type': 'application/json; charset=utf-8' })
      response.end(JSON.stringify({ code: 503, errorCode: 'PET-SERVICE-OFFLINE', message: '商城后端未就绪，请运行 start-mall.bat，并检查 MySQL、Redis 与后端日志' }))
    })
    request.on('aborted', () => upstream.destroy()); request.pipe(upstream); return
  }
  if (!['GET', 'HEAD'].includes(request.method)) { response.writeHead(405).end(); return }
  const resolved = path.resolve(root, '.' + pathname)
  if (!resolved.startsWith(root + path.sep) && resolved !== root) { response.writeHead(403).end(); return }
  let file = resolved
  if (!fs.existsSync(file) || !fs.statSync(file).isFile()) {
    if (path.extname(pathname)) { response.writeHead(404).end(); return }
    file = path.join(root, 'index.html')
  }
  if (!fs.existsSync(file)) { response.writeHead(503).end('Build user-ui first: npm run build'); return }
  const type = mime[path.extname(file)] || 'application/octet-stream'
  response.writeHead(200, { 'Content-Type': type, 'X-Content-Type-Options': 'nosniff',
    'Cache-Control': file.endsWith('index.html') ? 'no-cache' : 'public, max-age=3600' })
  if (request.method === 'HEAD') response.end()
  else fs.createReadStream(file).on('error', () => response.destroy()).pipe(response)
})
server.listen(port, '127.0.0.1', () => console.log(`User UI: http://127.0.0.1:${port}/ -> ${backend.origin}`))
