// Exercises the real API through Vite's /api proxy, using only newly created test data.
import assert from 'node:assert/strict'
import fs from 'node:fs'
const base = process.env.USER_UI_BASE || 'http://127.0.0.1:81'
const username = `uitest_${Date.now().toString().slice(-8)}`,
  password = 'UserUI_test2026',
  checks = []
let token = ''
async function call(url, method = 'GET', data, expected) {
  const headers = {}
  if (token) headers.Authorization = `Bearer ${token}`
  if (data && !(data instanceof FormData)) headers['Content-Type'] = 'application/json'
  const response = await fetch(`${base}${url}`, {
    method,
    headers,
    body: data ? (data instanceof FormData ? data : JSON.stringify(data)) : undefined,
  })
  const body = await response.json()
  if (expected) {
    assert.equal(body.errorCode, expected, `${method} ${url}: ${JSON.stringify(body)}`)
    checks.push(`${method} ${url} → ${expected}`)
    return body.data
  }
  assert.ok(
    body.code === 200 || body.errorCode === 'PET-4001',
    `${method} ${url}: ${JSON.stringify(body)}`,
  )
  checks.push(`${method} ${url} → PASS`)
  return body.data
}
await call('/api/cart', 'GET', null, 'PET-2001')
const categories = await call('/api/home/categories')
assert.ok(categories.length > 0)
const items = await call('/api/items?pageSize=100')
assert.ok(items.total > 0)
await call('/api/home/recommend?limit=8')
const item = await call('/api/items/1'),
  sku = item.skus.find((sku) => sku.stock > 4 && sku.status === 1)
assert.ok(sku)
await call('/api/items/11', 'GET', null, 'PET-3003')
const registration = await call('/api/member/register', 'POST', {
  username,
  password,
  nickname: '用户端验收员',
})
token = registration.token
await call('/api/member/login', 'POST', { username, password: 'wrong-password' }, 'PET-2002')
const signedIn = await call('/api/member/login', 'POST', { username, password })
token = signedIn.token
await call('/api/member/me')
await call('/api/member/me', 'PUT', { nickname: '用户端演示员', avatar: '' })
const form = new FormData()
form.append(
  'file',
  new Blob(
    [
      Buffer.from(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jD1sAAAAASUVORK5CYII=',
        'base64',
      ),
    ],
    { type: 'image/png' },
  ),
  'ui-test.png',
)
await call('/api/member/upload/image', 'POST', form)
const petData = {
  name: '验收小猫',
  species: 'CAT',
  breed: '测试品种',
  birthday: '2026-02-01',
  weight: 3.5,
  sterilized: 0,
  allergyNote: '谷物',
  status: 0,
}
const pet = await call('/api/member/pets', 'POST', petData)
await call(`/api/member/pets/${pet.id}`)
await call(`/api/member/pets/${pet.id}`, 'PUT', { ...petData, weight: 3.6 })
await call('/api/member/pets')
const addressData = {
  receiver: '演示收货人',
  phone: '13800000000',
  province: '测试省',
  city: '测试市',
  district: '测试区',
  detail: '仅用于课程验收的虚拟地址',
  isDefault: 1,
}
const address = await call('/api/member/addresses', 'POST', addressData)
await call(`/api/member/addresses/${address.id}`)
await call(`/api/member/addresses/${address.id}`, 'PUT', addressData)
await call(`/api/member/addresses/${address.id}/default`, 'PUT')
const disposable = await call('/api/member/addresses', 'POST', {
  ...addressData,
  receiver: '临时测试地址',
  isDefault: 0,
})
await call(`/api/member/addresses/${disposable.id}`, 'DELETE')
await call('/api/member/addresses')
const cartRow = await call('/api/cart/items', 'POST', { skuId: sku.id, quantity: 1, petId: pet.id })
await call(`/api/cart/items/${cartRow.id}`, 'PUT', { quantity: 2, checked: 1 })
const cart = await call('/api/cart')
assert.equal(cart[0].quantity, 2)
const preview = await call('/api/checkout/preview', 'POST', {
  skuIds: [sku.id],
  addressId: address.id,
})
assert.equal(preview.items[0].quantity, 2)
const payload = {
  addressId: address.id,
  clientToken: crypto.randomUUID(),
  items: [{ skuId: sku.id, quantity: 2, petId: pet.id }],
  remark: '用户端自动验收：取消恢复库存',
}
const order = await call('/api/orders', 'POST', payload),
  duplicate = await call('/api/orders', 'POST', payload)
assert.equal(order.orderNo, duplicate.orderNo)
assert.equal(duplicate.duplicated, true)
await call(`/api/orders/${order.orderNo}`)
await call('/api/orders?status=0')
await call(`/api/orders/${order.orderNo}/confirm`, 'POST', null, 'PET-3002')
await call(`/api/orders/${order.orderNo}/cancel`, 'POST', { reason: '自动验收取消' })
await call('/api/orders?status=5')
const paidOrder = await call('/api/orders', 'POST', {
  ...payload,
  clientToken: crypto.randomUUID(),
  items: [{ skuId: sku.id, quantity: 1 }],
  remark: '用户端验收：支付三分支',
})
for (const result of ['FAIL', 'TIMEOUT', 'SUCCESS']) {
  const data = await call('/api/pay/mock', 'POST', {
    orderNo: paidOrder.orderNo,
    channel: 'WECHAT',
    result,
  })
  assert.equal(data.status, result === 'FAIL' ? 'FAILED' : result)
}
const payment = await call(`/api/pay/${paidOrder.orderNo}`)
assert.equal(payment.orderStatus, 2)
const repeated = await call('/api/pay/mock', 'POST', {
  orderNo: paidOrder.orderNo,
  channel: 'WECHAT',
  result: 'SUCCESS',
})
assert.equal(repeated.duplicated, true)
await call('/api/member/messages')
await call('/api/member/messages/unread-count')
const messages = await call('/api/member/messages')
if (messages.list[0]) await call(`/api/member/messages/${messages.list[0].id}/read`, 'PUT')
await call('/api/member/messages/read-all', 'PUT')
const another = await call('/api/member/register', 'POST', {
  username: `${username}b`,
  password,
  nickname: '隔离验收员',
})
const originalToken = token
token = another.token
await call(`/api/orders/${paidOrder.orderNo}`, 'GET', null, 'PET-4003')
await call(`/api/member/pets/${pet.id}`, 'GET', null, 'PET-2003')
token = originalToken
await call(`/api/member/pets/${pet.id}`, 'DELETE')
const removable = await call('/api/cart/items', 'POST', { skuId: sku.id, quantity: 1 })
await call(`/api/cart/items/${removable.id}`, 'DELETE')
await call('/api/member/logout', 'POST')
await call('/api/member/me', 'GET', null, 'PET-2001')
const receipt = {
  base,
  username,
  checks,
  passCount: checks.length,
  orderNo: order.orderNo,
  paidOrderNo: paidOrder.orderNo,
  note: 'Only synthetic test members/data created. One paid sandbox order remains; no seed reset.',
}
fs.mkdirSync('../verify/user-ui', { recursive: true })
fs.writeFileSync('../verify/user-ui/api-receipt.json', JSON.stringify(receipt, null, 2))
console.log(JSON.stringify({ passCount: checks.length, username, paidOrderNo: paidOrder.orderNo }))
