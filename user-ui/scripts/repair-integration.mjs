// Real local regression tests. SQL changes are restricted to records created by this run.
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { execFileSync, spawn } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..')
const base = process.env.USER_UI_BASE || 'http://127.0.0.1:81'
const config = Object.fromEntries(
  fs
    .readFileSync(path.join(root, 'config/backend.env'), 'utf8')
    .split(/\r?\n/)
    .filter((x) => x.includes('=') && !x.trim().startsWith('#'))
    .map((x) => {
      const i = x.indexOf('=')
      return [x.slice(0, i).trim(), x.slice(i + 1).trim()]
    }),
)
const mysql = config.MYSQL_EXE || process.env.MYSQL_EXE || 'mysql.exe'
function sql(query) {
  return execFileSync(
    mysql,
    [
      '--host=' + (config.DB_HOST || '127.0.0.1'),
      '--port=' + (config.DB_PORT || '3306'),
      '--user=' + (config.DB_USERNAME || 'root'),
      '--database=' + (config.DB_NAME || 'shop'),
      '--default-character-set=utf8mb4',
      '-N',
      '-B',
      '-e',
      query,
    ],
    { encoding: 'utf8', env: { ...process.env, MYSQL_PWD: config.DB_PASSWORD }, windowsHide: true },
  ).trim()
}
const checks = [],
  id = Date.now(),
  username = `repair${id}`,
  password = 'Repair_test2026'
let token = ''
async function api(url, method = 'GET', data, expected, auth = token, extra = {}) {
  const res = await fetch(base + url, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(auth ? { Authorization: `Bearer ${auth}` } : {}),
      ...extra,
    },
    body: data === undefined ? undefined : JSON.stringify(data),
  })
  const body = await res.json()
  if (expected) assert.equal(body.errorCode, expected, `${url}: ${JSON.stringify(body)}`)
  else
    assert.ok(body.code === 200 || body.errorCode === 'PET-4001', `${url}: ${JSON.stringify(body)}`)
  checks.push(`${method} ${url}: ${expected || 'PASS'}`)
  return body.data
}
await api('/api/health')
const settings = await api('/api/home/settings')
assert.ok(settings.banners.length && settings.hotKeywords.length)
const all = await api('/api/items?pageSize=100')
assert.ok(all.total > 0)
assert.ok(all.list.every((x) => x.costPrice == null && x.isPrescription === 0))
const categoryId = all.list[0].categoryId
const filtered = await api(`/api/items?categoryId=${categoryId}&pageSize=100`)
const p1 = await api(`/api/items?categoryId=${categoryId}&pageSize=1`)
assert.equal(p1.total, filtered.total)
assert.equal(p1.list.length, 1)
if (filtered.total > 1) {
  const p2 = await api(`/api/items?categoryId=${categoryId}&pageSize=1&pageNum=2`)
  assert.notEqual(p1.list[0].id, p2.list[0].id)
  assert.equal(p2.total, filtered.total)
}
await api('/api/items?keyword=' + encodeURIComponent('包治百病'), 'GET', undefined, 'PET-7001')
token = (
  await api('/api/member/register', 'POST', { username, password, nickname: '修复回归专用账号' })
).token
const tokenA = token
const petData = {
  name: '回归猫',
  species: 'CAT',
  breed: '测试',
  birthday: '2025-01-01',
  weight: 3,
  sterilized: 1,
  allergyNote: '',
  status: 0,
}
const pet = await api('/api/member/pets', 'POST', petData)
const adapted = await api(`/api/items?petId=${pet.id}&onlyStock=true`)
assert.ok(adapted.list.every((x) => ['ALL', 'CAT'].includes(x.petSpecies)))
const item = await api('/api/items/1')
assert.equal(item.costPrice, null)
const sku = item.skus.find((x) => x.status === 1 && x.stock > 5)
assert.ok(sku)
const row = await api('/api/cart/items', 'POST', { skuId: sku.id, quantity: 1, petId: pet.id })
await api(`/api/cart/items/${row.id}`, 'PUT', { clearPet: true })
assert.equal((await api('/api/cart')).find((x) => x.id === row.id).petId, null)
const addressData = {
  receiver: '虚拟验收',
  phone: '13800000000',
  province: '测试省',
  city: '测试市',
  district: '测试区',
  detail: '回归验证专用，不发货',
  isDefault: 1,
}
const a = await api('/api/member/addresses', 'POST', addressData)
const b = await api('/api/member/addresses', 'POST', {
  ...addressData,
  receiver: '已更新地址',
  isDefault: 0,
})
const submit = () =>
  api('/api/orders', 'POST', {
    addressId: a.id,
    clientToken: crypto.randomUUID(),
    items: [{ skuId: sku.id, quantity: 1 }],
    remark: `repair-${id}`,
  })
const order = await submit()
await api(`/api/orders/${order.orderNo}/address`, 'PUT', { addressId: b.id })
assert.equal(
  JSON.parse((await api(`/api/orders/${order.orderNo}`)).receiverSnapshot).receiver,
  '已更新地址',
)
const found = await api('/api/orders?keyword=' + order.orderNo)
assert.equal(found.total, 1)
assert.equal((await api('/api/orders?keyword=no-match-' + id)).total, 0)
await api(`/api/orders/${order.orderNo}/cancel`, 'POST', { reason: '回归取消' })
await api(`/api/orders/${order.orderNo}/address`, 'PUT', { addressId: a.id }, 'PET-3002')
const feedback = `修复回归反馈-${id}`
await api('/api/member/feedback', 'POST', { content: feedback })
assert.equal(sql(`SELECT COUNT(*) FROM sys_oper_log WHERE oper_param='${feedback}'`), '1')
await api(`/api/member/pets/${pet.id}`, 'DELETE')
assert.ok((await api('/api/member/pets/export')).some((x) => x.id === pet.id && x.status === 1))
await api(`/api/member/pets/${pet.id}`, 'PUT', petData)
assert.ok((await api('/api/member/pets')).some((x) => x.id === pet.id))
// Expiry and receipt times are changed only on this run's own synthetic orders.
const expired = await submit()
sql(
  `UPDATE pet_order SET expire_at=DATE_SUB(NOW(),INTERVAL 1 MINUTE) WHERE order_no='${expired.orderNo}'`,
)
await api(
  '/api/pay/mock',
  'POST',
  { orderNo: expired.orderNo, channel: 'WECHAT', result: 'SUCCESS' },
  'PET-3002',
)
const beforeRestore = Number(sql(`SELECT stock FROM pet_item_sku WHERE id=${sku.id}`))
const deadline = Date.now() + 40000
while (
  Date.now() < deadline &&
  sql(`SELECT status FROM pet_order WHERE order_no='${expired.orderNo}'`) === '0'
)
  await new Promise((resolve) => setTimeout(resolve, 1000))
assert.equal(sql(`SELECT status FROM pet_order WHERE order_no='${expired.orderNo}'`), '6')
assert.equal(Number(sql(`SELECT stock FROM pet_item_sku WHERE id=${sku.id}`)), beforeRestore + 1)
checks.push('scheduled timeout closes synthetic order and restores stock exactly once')
const paid = await submit()
await api('/api/pay/mock', 'POST', { orderNo: paid.orderNo, channel: 'WECHAT', result: 'SUCCESS' })
// Use existing admin sandbox account. No CAPTCHA is solved: disabled flag must be returned.
const captcha = await fetch('http://127.0.0.1:8080/captchaImage').then((r) => r.json())
assert.equal(captcha.captchaEnabled, false, 'This script requires local sandbox CAPTCHA disabled')
const admin = await fetch('http://127.0.0.1:8080/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ username: 'admin', password: 'admin123' }),
}).then((r) => r.json())
assert.ok(admin.token, 'sandbox admin login failed')
const ship = { company: '回归测试物流', trackingNo: `TEST${id}` }
await api(`/api/admin/orders/${paid.orderNo}/ship`, 'PUT', ship, undefined, admin.token)
await api(`/api/admin/orders/${paid.orderNo}/ship`, 'PUT', ship, undefined, admin.token)
await api(`/api/orders/${paid.orderNo}/address`, 'PUT', { addressId: a.id }, 'PET-3002')
sql(
  `UPDATE pet_order SET ship_time=DATE_SUB(NOW(),INTERVAL 366 DAY) WHERE order_no='${paid.orderNo}'`,
)
const confirmDeadline = Date.now() + 70000
while (
  Date.now() < confirmDeadline &&
  sql(`SELECT status FROM pet_order WHERE order_no='${paid.orderNo}'`) === '3'
)
  await new Promise((resolve) => setTimeout(resolve, 1000))
assert.equal(sql(`SELECT status FROM pet_order WHERE order_no='${paid.orderNo}'`), '4')
assert.equal(
  sql(
    `SELECT COUNT(*) FROM pet_stock_log WHERE order_no='${expired.orderNo}' AND type='ORDER_ROLLBACK'`,
  ),
  '1',
)
checks.push('scheduled receipt completes order and repeated cycles do not restore stock twice')
const key = `callback-${id}`
const callbackToken =
  sql("SELECT config_value FROM sys_config WHERE config_key='mall.pay-callback-token'") ||
  'sandbox-internal-token'
await api(
  '/api/pay/callback',
  'POST',
  { orderNo: paid.orderNo, amount: paid.payAmount, channel: 'WECHAT', result: 'SUCCESS' },
  undefined,
  callbackToken,
  { 'Idempotency-Key': key },
)
await api(
  '/api/pay/callback',
  'POST',
  { orderNo: order.orderNo, amount: paid.payAmount, channel: 'WECHAT', result: 'SUCCESS' },
  'PET-1002',
  callbackToken,
  { 'Idempotency-Key': key },
)
await api(
  '/api/member/password',
  'PUT',
  { oldPassword: 'incorrect', newPassword: 'Repair_new2026' },
  'PET-2002',
)
await api(
  '/api/member/password',
  'PUT',
  { oldPassword: password, newPassword: password },
  'PET-1001',
)
const tokenB = (await api('/api/member/login', 'POST', { username, password })).token
await api('/api/member/password', 'PUT', { oldPassword: password, newPassword: 'Repair_new2026' })
await api('/api/member/me', 'GET', undefined, 'PET-2001', tokenA)
await api('/api/member/me', 'GET', undefined, 'PET-2001', tokenB)
token = (await api('/api/member/login', 'POST', { username, password: 'Repair_new2026' })).token
const foreign = (
  await api('/api/member/register', 'POST', {
    username: username + 'b',
    password,
    nickname: '隔离回归',
  })
).token
await api(`/api/items?petId=${pet.id}`, 'GET', undefined, 'PET-2003', foreign)
await api(`/api/orders/${paid.orderNo}/address`, 'PUT', { addressId: a.id }, 'PET-4003', foreign)
// An unavailable upstream must return JSON 503, while SPA routes remain HTML and missing assets 404.
const server = spawn(process.execPath, [path.join(root, 'setup/serve-user-ui.mjs')], {
  env: { ...process.env, USER_UI_PORT: '4189', USER_UI_API_TARGET: 'http://127.0.0.1:49999' },
  windowsHide: true,
  stdio: 'ignore',
})
try {
  let res
  for (let i = 0; i < 30; i++) {
    try {
      res = await fetch('http://127.0.0.1:4189/api/health')
      break
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 100))
    }
  }
  assert.equal(res.status, 503)
  assert.ok((await res.json()).message.includes('start-mall'))
  assert.equal((await fetch('http://127.0.0.1:4189/orders/missing')).status, 200)
  assert.equal((await fetch('http://127.0.0.1:4189/assets/not-found.js')).status, 404)
  checks.push('offline upstream JSON 503, SPA fallback and asset 404 verified')
} finally {
  server.kill()
}
const receipt = {
  base,
  username,
  passCount: checks.length,
  checks,
  expiredOrder: expired.orderNo,
  completedOrder: paid.orderNo,
  at: new Date().toISOString(),
  note: 'Only new synthetic records changed. No seed reset. One sandbox paid order consumes one unit.',
}
fs.mkdirSync(path.join(root, 'verify/repair'), { recursive: true })
fs.writeFileSync(
  path.join(root, 'verify/repair/api-receipt.json'),
  JSON.stringify(receipt, null, 2),
)
console.log(JSON.stringify({ passCount: checks.length, username, completedOrder: paid.orderNo }))
