// Real local regression. Only new synthetic accounts, items and orders are mutated.
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
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
      return [
        x.slice(0, i).trim(),
        x
          .slice(i + 1)
          .trim()
          .replace(/^(['"])(.*)\1$/, '$2'),
      ]
    }),
)
const sql = (query) =>
  execFileSync(
    config.MYSQL_EXE || 'mysql.exe',
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
const checks = [],
  stamp = Date.now(),
  username = `feat${stamp}`,
  password = 'Feature_test2026'
let token = '',
  item,
  admin
async function api(url, method = 'GET', data, expected, auth = token, headers = {}) {
  const body = await fetch(base + url, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(auth ? { Authorization: `Bearer ${auth}` } : {}),
      ...headers,
    },
    body: data === undefined ? undefined : JSON.stringify(data),
  }).then((r) => r.json())
  if (expected) assert.equal(body.errorCode, expected, `${url}: ${JSON.stringify(body)}`)
  else
    assert.ok(body.code === 200 || body.errorCode === 'PET-4001', `${url}: ${JSON.stringify(body)}`)
  checks.push(`${method} ${url}: ${expected || 'PASS'}`)
  return body.data
}
const addressData = {
  receiver: '增量回归',
  phone: '13800000000',
  province: '测试省',
  city: '测试市',
  district: '测试区',
  detail: '虚拟地址，不实际发货',
  isDefault: 1,
}
await api('/api/health')
const administrator = await fetch('http://127.0.0.1:8080/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ username: 'admin', password: 'admin123' }),
}).then((r) => r.json())
assert.ok(administrator.token)
admin = administrator.token
try {
  item = await api(
    '/api/admin/items',
    'POST',
    {
      merchantId: 9001,
      categoryId: 1,
      title: `会员功能验收-${stamp}`,
      subtitle: '虚拟商品，不实际销售',
      mainImage: '/images/companions.svg',
      brand: '验收',
      petSpecies: 'ALL',
      ageStage: 'ALL',
      costPrice: 0.01,
      supportSubscribe: 0,
      isPrescription: 0,
      detail: '会员功能回归专用',
      skus: [{ specName: '测试规格', price: 0.01, stock: 100, skuCode: `FEAT${stamp}`, status: 1 }],
    },
    undefined,
    admin,
  )
  await api(`/api/admin/items/${item.id}/status`, 'PUT', { status: 1 }, undefined, admin)
  const detail = await api(`/api/items/${item.id}`),
    sku = detail.skus[0]
  const registration = await api(
    '/api/member/register',
    'POST',
    { username, password, nickname: '会员功能验收' },
    undefined,
    '',
    { 'User-Agent': 'Feature Test A' },
  )
  token = registration.token
  const memberId = registration.member.id
  const other = await api(
    '/api/member/register',
    'POST',
    { username: `other${stamp}`, password, nickname: '隔离验收' },
    undefined,
    '',
  )
  const otherToken = other.token
  await api('/api/member/favorites', 'GET', undefined, 'PET-2001', '')
  await api(`/api/member/favorites/${item.id}`, 'PUT')
  await api(`/api/member/favorites/${item.id}`, 'PUT')
  assert.equal(await api(`/api/member/favorites/${item.id}`), true)
  let favorites = await api('/api/member/favorites?pageSize=1')
  assert.equal(favorites.total, 1)
  assert.equal(favorites.list[0].id, item.id)
  assert.equal(favorites.list[0].costPrice, null)
  assert.equal(
    await api(`/api/member/favorites/${item.id}`, 'GET', undefined, undefined, otherToken),
    false,
  )
  await api(`/api/member/favorites/${item.id}`, 'DELETE', undefined, undefined, otherToken)
  assert.equal(await api(`/api/member/favorites/${item.id}`), true)
  await api(`/api/member/favorites/999999999`, 'PUT', undefined, 'PET-3003')
  await api(`/api/admin/items/${item.id}/status`, 'PUT', { status: 0 }, undefined, admin)
  favorites = await api('/api/member/favorites')
  assert.equal(favorites.total, 1)
  assert.equal(favorites.list[0].status, 0)
  await api(`/api/member/favorites/${item.id}`, 'DELETE')
  assert.equal((await api('/api/member/favorites')).total, 0)
  await api(`/api/admin/items/${item.id}/status`, 'PUT', { status: 1 }, undefined, admin)
  await api(`/api/member/favorites/${item.id}`, 'PUT')
  assert.deepEqual(await api('/api/member/preferences'), {
    orderNotifications: true,
    systemNotifications: true,
  })
  await api('/api/member/preferences', 'PUT', {
    orderNotifications: false,
    systemNotifications: false,
  })
  assert.deepEqual(await api('/api/member/preferences'), {
    orderNotifications: false,
    systemNotifications: false,
  })
  assert.deepEqual(await api('/api/member/preferences', 'GET', undefined, undefined, otherToken), {
    orderNotifications: true,
    systemNotifications: true,
  })
  await api(
    '/api/member/preferences',
    'PUT',
    { orderNotifications: null, systemNotifications: true },
    'PET-1001',
  )

  const addresses = await Promise.all(
    Array.from({ length: 6 }, (_, i) =>
      api('/api/member/addresses', 'POST', { ...addressData, receiver: `并发地址${i}` }),
    ),
  )
  let addressRows = await api('/api/member/addresses')
  assert.equal(addressRows.filter((x) => x.isDefault === 1).length, 1)
  const defaultAddress = addressRows.find((x) => x.isDefault === 1)
  await api(
    `/api/member/addresses/${defaultAddress.id}`,
    'PUT',
    { ...addressData, isDefault: 0 },
    'PET-1001',
  )
  await Promise.all(addresses.map((x) => api(`/api/member/addresses/${x.id}/default`, 'PUT')))
  assert.equal((await api('/api/member/addresses')).filter((x) => x.isDefault === 1).length, 1)
  const address = addresses[0]
  const orderData = {
    addressId: address.id,
    clientToken: crypto.randomUUID(),
    items: [{ skuId: sku.id, quantity: 1 }],
    remark: `feature-${stamp}`,
  }
  const concurrent = await Promise.all(
    Array.from({ length: 12 }, () => api('/api/orders', 'POST', orderData)),
  )
  assert.equal(new Set(concurrent.map((x) => x.orderNo)).size, 1)
  const order = concurrent[0]
  assert.equal(
    sql(
      `SELECT COUNT(*) FROM pet_order WHERE member_id=${memberId} AND client_token='${orderData.clientToken}'`,
    ),
    '1',
  )
  assert.equal(sql(`SELECT stock FROM pet_item_sku WHERE id=${sku.id}`), '99')
  await api(`/api/member/addresses/${address.id}`, 'DELETE', undefined, 'PET-1003')
  // Legacy snapshots wrote only id. Exact JSON equality must protect these too.
  sql(
    `UPDATE pet_order SET receiver_snapshot=JSON_REMOVE(receiver_snapshot,'$.addressId') WHERE order_no='${order.orderNo}'`,
  )
  await api(`/api/member/addresses/${address.id}`, 'DELETE', undefined, 'PET-1003')
  assert.equal(sql(`SELECT COUNT(*) FROM pet_message WHERE member_id=${memberId}`), '0')
  await api(`/api/orders/${order.orderNo}/cancel`, 'POST', { reason: '并发回归恢复库存' })
  assert.equal(sql(`SELECT stock FROM pet_item_sku WHERE id=${sku.id}`), '100')
  await api(`/api/member/addresses/${address.id}`, 'DELETE')
  assert.equal(sql(`SELECT COUNT(*) FROM pet_message WHERE member_id=${memberId}`), '0')
  await api('/api/member/preferences', 'PUT', {
    orderNotifications: true,
    systemNotifications: false,
  })
  const submit = () =>
    api('/api/orders', 'POST', {
      ...orderData,
      addressId: addresses[1].id,
      clientToken: crypto.randomUUID(),
    })
  const paidOrder = await submit()
  const pay = (result, key, expected) =>
    api(
      '/api/pay/mock',
      'POST',
      { orderNo: paidOrder.orderNo, channel: 'WECHAT', result },
      expected,
      token,
      { 'Idempotency-Key': key },
    )
  await pay('FAIL', `failure-${stamp}`)
  const success = await Promise.all(
    Array.from({ length: 10 }, (_, i) => pay('SUCCESS', `success-${stamp}-${i}`)),
  )
  assert.equal(new Set(success.map((x) => x.paymentNo)).size, 1)
  assert.equal(
    sql(
      `SELECT COUNT(*) FROM pet_payment WHERE order_no='${paidOrder.orderNo}' AND status='SUCCESS'`,
    ),
    '1',
  )
  await pay('FAIL', `late-failure-${stamp}`, 'PET-3002')
  await pay('TIMEOUT', `late-timeout-${stamp}`, 'PET-3002')
  await pay('TIMEOUT', `failure-${stamp}`, 'PET-1002')
  assert.equal((await api(`/api/pay/${paidOrder.orderNo}`)).status, 'SUCCESS')
  const enabledMessages = Number(
    sql(`SELECT COUNT(*) FROM pet_message WHERE member_id=${memberId}`),
  )
  assert.ok(enabledMessages > 0)
  await api('/api/member/preferences', 'PUT', {
    orderNotifications: false,
    systemNotifications: false,
  })
  assert.equal(
    Number(sql(`SELECT COUNT(*) FROM pet_message WHERE member_id=${memberId}`)),
    enabledMessages,
  )
  const callbackToken =
    sql("SELECT config_value FROM sys_config WHERE config_key='mall.pay-callback-token' LIMIT 1") ||
    'sandbox-internal-token'
  await api(
    '/api/pay/callback',
    'POST',
    { orderNo: paidOrder.orderNo, amount: paidOrder.payAmount, channel: 'WECHAT', result: 'FAIL' },
    'PET-3002',
    callbackToken,
    { 'Idempotency-Key': `cb-late-${stamp}` },
  )
  const cancelled = await submit()
  await api(`/api/orders/${cancelled.orderNo}/cancel`, 'POST', { reason: '验证关闭订单支付保护' })
  await api(
    '/api/pay/mock',
    'POST',
    { orderNo: cancelled.orderNo, channel: 'WECHAT', result: 'FAIL' },
    'PET-3002',
  )
  const expired = await submit()
  sql(
    `UPDATE pet_order SET expire_at=DATE_SUB(NOW(),INTERVAL 1 MINUTE) WHERE order_no='${expired.orderNo}'`,
  )
  await api(
    '/api/pay/mock',
    'POST',
    { orderNo: expired.orderNo, channel: 'WECHAT', result: 'TIMEOUT' },
    'PET-3002',
  )
  await api(`/api/orders/${expired.orderNo}/cancel`, 'POST', { reason: '验证过期订单保护后清理' })

  const pet = await api('/api/member/pets', 'POST', {
    name: '归档验证猫',
    species: 'CAT',
    birthday: '2025-01-01',
    weight: 3,
    sterilized: 0,
    status: 0,
  })
  const cart = await api('/api/cart/items', 'POST', { skuId: sku.id, quantity: 5, petId: pet.id })
  await api('/api/member/pets/' + pet.id, 'DELETE')
  const invalid = (await api('/api/cart')).find((x) => x.id === cart.id)
  assert.equal(invalid.valid, false)
  assert.match(invalid.invalidReason, /归档/)
  await api('/api/cart/items', 'POST', { skuId: sku.id, quantity: 1, petId: pet.id }, 'PET-2003')
  await api(
    '/api/orders',
    'POST',
    {
      ...orderData,
      clientToken: crypto.randomUUID(),
      addressId: addresses[1].id,
      items: [{ skuId: sku.id, quantity: 1, petId: pet.id }],
    },
    'PET-1001',
  )
  await api(`/api/cart/items/${cart.id}`, 'PUT', { quantity: 1, clearPet: true })
  const fixedCart = (await api('/api/cart')).find((x) => x.id === cart.id)
  assert.equal(fixedCart.quantity, 1)
  assert.equal(fixedCart.petId, null)
  assert.equal(fixedCart.valid, true)

  const login = async (client) =>
    (
      await api('/api/member/login', 'POST', { username, password }, undefined, '', {
        'User-Agent': client,
      })
    ).token
  const second = await login('Feature Test B'),
    third = await login('Feature Test C')
  let sessions = await api('/api/member/sessions')
  assert.equal(sessions.length, 3)
  assert.equal(sessions.filter((x) => x.current).length, 1)
  assert.ok(!JSON.stringify(sessions).includes(token) && !JSON.stringify(sessions).includes(second))
  const secondView = sessions.find((x) => x.client === 'Feature Test B')
  await api(`/api/member/sessions/${secondView.id}`, 'DELETE', undefined, 'PET-2003', otherToken)
  await api(`/api/member/sessions/${secondView.id}`, 'DELETE')
  await api('/api/member/me', 'GET', undefined, 'PET-2001', second)
  assert.equal(await api('/api/member/sessions/revoke-others', 'POST'), 1)
  await api('/api/member/me', 'GET', undefined, 'PET-2001', third)
  assert.equal((await api('/api/member/sessions')).length, 1)

  const phone = '139' + String(stamp).slice(-8)
  await api('/api/member/phone', 'PUT', { phone: '123', password }, 'PET-1001')
  await api('/api/member/phone', 'PUT', { phone, password: 'Wrong_password' }, 'PET-2002')
  const fourth = await login('Feature Test D')
  await api('/api/member/phone', 'PUT', { phone, password })
  await api('/api/member/me', 'GET', undefined, 'PET-2001')
  await api('/api/member/me', 'GET', undefined, 'PET-2001', fourth)
  token = await login('Feature Test A')
  assert.equal((await api('/api/member/me')).phone, phone.slice(0, 3) + '****' + phone.slice(-4))
  await api('/api/member/phone', 'PUT', { phone, password }, 'PET-1001')
  await api('/api/member/phone', 'PUT', { phone, password }, 'PET-1002', otherToken)
  assert.equal((await api('/api/member/preferences')).orderNotifications, false)
  assert.equal((await api('/api/member/favorites')).total, 1)
  const receipt = {
    at: new Date().toISOString(),
    username,
    memberId,
    itemId: item.id,
    paidOrder: paidOrder.orderNo,
    passCount: checks.length,
    checks,
    note: 'Synthetic data only; no database reset. One sandbox paid test item remains for traceability; all test orders except paid were cancelled.',
  }
  fs.mkdirSync(path.join(root, 'verify/member-features'), { recursive: true })
  fs.writeFileSync(
    path.join(root, 'verify/member-features/api-receipt.json'),
    JSON.stringify(receipt, null, 2),
  )
  console.log(JSON.stringify({ passCount: checks.length, username, paidOrder: paidOrder.orderNo }))
} finally {
  if (item && admin)
    await api(`/api/admin/items/${item.id}/status`, 'PUT', { status: 0 }, undefined, admin)
}
