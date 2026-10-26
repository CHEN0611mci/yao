// Real merchant -> reviewer -> storefront regression on a dedicated synthetic item.
import assert from 'node:assert/strict'
import fs from 'node:fs'
const base = process.env.USER_UI_BASE || 'http://127.0.0.1:81',
  stamp = Date.now(),
  checks = []
async function login(username, password) {
  const body = await fetch('http://127.0.0.1:8080/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password }),
  }).then((r) => r.json())
  assert.ok(body.token, `login ${username}: ${body.msg}`)
  checks.push(`login ${username}: PASS`)
  return body.token
}
async function api(url, method = 'GET', data, token = '', expected) {
  const response = await fetch(base + url, {
    method,
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: data === undefined ? undefined : JSON.stringify(data),
  })
  const body = await response.json()
  if (expected === 403) assert.equal(body.code, 403, JSON.stringify(body))
  else if (expected) assert.equal(body.errorCode, expected, JSON.stringify(body))
  else assert.equal(body.code, 200, JSON.stringify(body))
  checks.push(`${method} ${url}: ${expected || 'PASS'}`)
  return body.data
}
const admin = await login('admin', 'admin123'),
  merchant = await login('merchant1', 'merchant123'),
  reviewer = await login('reviewer', 'reviewer123')
const data = {
  merchantId: 123456,
  categoryId: 1,
  title: `商家审核验收-${stamp}`,
  subtitle: '虚拟商品，不实际销售',
  mainImage: '/images/companions.svg',
  brand: '验收',
  petSpecies: 'ALL',
  ageStage: 'ALL',
  costPrice: 0.01,
  supportSubscribe: 0,
  isPrescription: 0,
  detail: '商家审核回归专用',
  skus: [{ specName: '测试规格', price: 0.01, stock: 5, skuCode: `AUDIT${stamp}`, status: 1 }],
}
let item
try {
  item = await api('/api/merchant/items', 'POST', data, merchant)
  assert.equal(item.merchantId, 9001)
  assert.equal(item.auditStatus, 0)
  assert.equal(item.status, 0)
  await api(`/api/merchant/items/${item.id}/status`, 'PUT', { status: 1 }, merchant, 'PET-3003')
  await api(`/api/items/${item.id}`, 'GET', undefined, '', 'PET-3003')
  const pending = await api(
    '/api/admin/items?auditStatus=0&keyword=' + encodeURIComponent(data.title),
    'GET',
    undefined,
    reviewer,
  )
  assert.equal(pending.total, 1)
  await api('/api/admin/stock', 'GET', undefined, reviewer, 403)
  await api(`/api/admin/items/${item.id}/status`, 'PUT', { status: 1 }, reviewer, 403)
  await api('/api/admin/members', 'GET', undefined, merchant, 403)
  await api(
    `/api/admin/items/${item.id}/audit`,
    'PUT',
    { auditStatus: 1, remark: '' },
    reviewer,
    'PET-1001',
  )
  await api(
    `/api/admin/items/${item.id}/audit`,
    'PUT',
    { auditStatus: 1, remark: '验收驳回：补全商品说明' },
    reviewer,
  )
  assert.equal(
    (await api(`/api/merchant/items/${item.id}`, 'GET', undefined, merchant)).auditStatus,
    1,
  )
  const ownSku = item.skus[0]
  await api(
    `/api/merchant/items/${item.id}`,
    'PUT',
    { ...data, detail: '已补全说明，仅用于测试', skus: [{ ...ownSku, skuCode: `AUDIT${stamp}` }] },
    merchant,
  )
  assert.equal(
    (await api(`/api/merchant/items/${item.id}`, 'GET', undefined, merchant)).auditStatus,
    0,
  )
  await api(
    `/api/admin/items/${item.id}/audit`,
    'PUT',
    { auditStatus: 2, remark: '验收通过' },
    reviewer,
  )
  await api(`/api/merchant/items/${item.id}/status`, 'PUT', { status: 1 }, merchant)
  assert.equal((await api(`/api/items/${item.id}`)).id, item.id)
  const stock = await api('/api/admin/stock?itemId=' + item.id, 'GET', undefined, admin)
  assert.ok(stock.some((x) => x.skuId === ownSku.id))
  await api(
    `/api/admin/stock/${ownSku.id}`,
    'PUT',
    { targetStock: 7, remark: '回归验证库存调整' },
    admin,
  )
  assert.equal((await api(`/api/items/${item.id}`)).skus[0].stock, 7)
  await api(
    `/api/admin/stock/${ownSku.id}`,
    'PUT',
    { targetStock: 9, remark: '验证重复调整可用' },
    admin,
  )
  await api(
    `/api/admin/stock/${ownSku.id}`,
    'PUT',
    { targetStock: 7, remark: '恢复验收目标库存' },
    admin,
  )
  const logs = await api('/api/admin/stock/logs?skuId=' + ownSku.id, 'GET', undefined, admin)
  assert.ok(logs.length >= 1)
  // Different members bypass the per-member serialization and compete for the same SKU.
  const buyers = await Promise.all(
    Array.from({ length: 6 }, async (_, i) => {
      const buyer = await api('/api/member/register', 'POST', {
        username: `buyer${stamp}${i}`,
        password: 'Buyer_test2026',
        nickname: '库存流水回归',
      })
      const address = await api(
        '/api/member/addresses',
        'POST',
        {
          receiver: '虚拟验收',
          phone: '13800000000',
          province: '测试省',
          city: '测试市',
          district: '测试区',
          detail: '并发专用，不实际发货',
          isDefault: 1,
        },
        buyer.token,
      )
      return { token: buyer.token, addressId: address.id }
    }),
  )
  const orders = await Promise.all(
    buyers.map((buyer) =>
      api(
        '/api/orders',
        'POST',
        {
          addressId: buyer.addressId,
          clientToken: crypto.randomUUID(),
          items: [{ skuId: ownSku.id, quantity: 1 }],
        },
        buyer.token,
      ),
    ),
  )
  assert.equal((await api(`/api/items/${item.id}`)).skus[0].stock, 1)
  const deducted = (
    await api('/api/admin/stock/logs?skuId=' + ownSku.id, 'GET', undefined, admin)
  ).filter((x) => x.type === 'ORDER_DEDUCT')
  assert.deepEqual(
    deducted.map((x) => x.beforeQty).sort((a, b) => a - b),
    [2, 3, 4, 5, 6, 7],
  )
  assert.ok(deducted.every((x) => x.afterQty === x.beforeQty - 1))
  await Promise.all(
    orders.map((order, i) =>
      api(
        `/api/orders/${order.orderNo}/cancel`,
        'POST',
        { reason: '并发验证恢复库存' },
        buyers[i].token,
      ),
    ),
  )
  assert.equal((await api(`/api/items/${item.id}`)).skus[0].stock, 7)
  const restored = (
    await api('/api/admin/stock/logs?skuId=' + ownSku.id, 'GET', undefined, admin)
  ).filter((x) => x.type === 'ORDER_ROLLBACK')
  assert.deepEqual(
    restored.map((x) => x.beforeQty).sort((a, b) => a - b),
    [1, 2, 3, 4, 5, 6],
  )
  assert.ok(restored.every((x) => x.afterQty === x.beforeQty + 1))
  const foreign = await api(
    '/api/admin/items',
    'POST',
    {
      ...data,
      merchantId: 123456,
      title: `隔离验收-${stamp}`,
      skus: [{ ...data.skus[0], skuCode: `FOREIGN${stamp}` }],
    },
    admin,
  )
  await api(`/api/merchant/items/${foreign.id}`, 'GET', undefined, merchant, 'PET-2003')
  await api(`/api/merchant/items/${foreign.id}/status`, 'PUT', { status: 1 }, merchant, 'PET-2003')
  const filtered = await api(
    '/api/merchant/items?keyword=' + encodeURIComponent(`隔离验收-${stamp}`),
    'GET',
    undefined,
    merchant,
  )
  assert.equal(filtered.total, 0)
  const account = await api('/api/member/register', 'POST', {
    username: `status${stamp}`,
    password: 'Status_test2026',
    nickname: '禁用回归',
  })
  await api(`/api/admin/members/${account.member.id}/status`, 'PUT', { status: 1 }, admin)
  await api('/api/member/me', 'GET', undefined, account.token, 'PET-2001')
  await api(
    '/api/member/login',
    'POST',
    { username: `status${stamp}`, password: 'Status_test2026' },
    '',
    'PET-2004',
  )
  await api(`/api/admin/members/${account.member.id}/status`, 'PUT', { status: 0 }, admin)
  assert.ok(
    (
      await api('/api/member/login', 'POST', {
        username: `status${stamp}`,
        password: 'Status_test2026',
      })
    ).token,
  )
  fs.mkdirSync('../verify/member-features', { recursive: true })
  fs.writeFileSync(
    '../verify/member-features/admin-receipt.json',
    JSON.stringify(
      {
        at: new Date().toISOString(),
        itemId: item.id,
        passCount: checks.length,
        checks,
        note: 'Dedicated test items only. Foreign item never put on sale; merchant test item hidden in finally.',
      },
      null,
      2,
    ),
  )
  console.log(JSON.stringify({ passCount: checks.length, itemId: item.id }))
} finally {
  if (item) await api(`/api/admin/items/${item.id}/status`, 'PUT', { status: 0 }, admin)
}
