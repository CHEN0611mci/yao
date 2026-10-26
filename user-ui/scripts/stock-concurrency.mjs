// Creates a dedicated one-unit sandbox SKU; never changes seed inventory.
import assert from 'node:assert/strict'
import fs from 'node:fs'
const base = process.env.USER_UI_BASE || 'http://127.0.0.1:81',
  id = Date.now()
let token = ''
async function call(url, method = 'GET', data, auth = token) {
  const result = await fetch(base + url, {
    method,
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${auth}` },
    body: data ? JSON.stringify(data) : undefined,
  }).then((r) => r.json())
  assert.ok(result.code === 200 || result.errorCode === 'PET-4001', JSON.stringify(result))
  return result.data
}
const admin = await fetch('http://127.0.0.1:8080/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ username: 'admin', password: 'admin123' }),
}).then((r) => r.json())
assert.ok(admin.token)
const item = await call(
  '/api/admin/items',
  'POST',
  {
    merchantId: 9001,
    categoryId: 1,
    title: `并发验收专用-${id}`,
    subtitle: '虚拟商品，不实际销售',
    mainImage: '/images/companions.svg',
    brand: '验收',
    petSpecies: 'ALL',
    ageStage: 'ALL',
    costPrice: 0.01,
    supportSubscribe: 0,
    isPrescription: 0,
    detail: '并发回归',
    skus: [{ specName: '仅一件', price: 0.01, stock: 1, skuCode: `TEST${id}`, status: 1 }],
  },
  admin.token,
)
await call(`/api/admin/items/${item.id}/status`, 'PUT', { status: 1 }, admin.token)
token = (
  await call('/api/member/register', 'POST', {
    username: `stock${id}`,
    password: 'Stock_test2026',
    nickname: '并发验收',
  })
).token
const address = await call('/api/member/addresses', 'POST', {
  receiver: '测试',
  phone: '13800000000',
  province: '测试省',
  city: '测试市',
  district: '测试区',
  detail: '并发专用虚拟地址',
  isDefault: 1,
})
const detail = await call(`/api/items/${item.id}`),
  sku = detail.skus[0]
const results = await Promise.all(
  Array.from({ length: 20 }, async () =>
    fetch(base + '/api/orders', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify({
        addressId: address.id,
        clientToken: crypto.randomUUID(),
        items: [{ skuId: sku.id, quantity: 1 }],
      }),
    }).then((r) => r.json()),
  ),
)
const success = results.filter((x) => x.code === 200),
  failed = results.filter((x) => x.errorCode === 'PET-3001')
assert.equal(success.length, 1)
assert.equal(failed.length, 19)
assert.equal((await call(`/api/items/${item.id}`)).skus[0].stock, 0)
await call(`/api/orders/${success[0].data.orderNo}/cancel`, 'POST', { reason: '并发回归恢复库存' })
assert.equal((await call(`/api/items/${item.id}`)).skus[0].stock, 1)
await call(`/api/admin/items/${item.id}/status`, 'PUT', { status: 0 }, admin.token)
const receipt = {
  at: new Date().toISOString(),
  requests: 20,
  success: success.length,
  stockRejected: failed.length,
  stockAfterSale: 0,
  stockAfterCancel: 1,
  itemId: item.id,
  note: 'Dedicated synthetic SKU hidden after test; no seed inventory changed.',
}
fs.mkdirSync('../verify/repair', { recursive: true })
fs.writeFileSync('../verify/repair/concurrency.json', JSON.stringify(receipt, null, 2))
console.log(JSON.stringify(receipt))
