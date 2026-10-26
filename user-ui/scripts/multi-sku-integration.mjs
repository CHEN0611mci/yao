// Dedicated synthetic products only; cancel every successful order and hide fixtures.
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { execFileSync, spawn } from 'node:child_process'
import { fileURLToPath } from 'node:url'
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..')
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
const mysql = config.MYSQL_EXE || 'mysql.exe'
const mysqlArgs = [
  '--host=' + (config.DB_HOST || '127.0.0.1'),
  '--port=' + (config.DB_PORT || '3306'),
  '--user=' + (config.DB_USERNAME || 'root'),
  '--database=' + (config.DB_NAME || 'shop'),
  '-N',
  '-B',
  '--unbuffered',
]
const mysqlOptions = { env: { ...process.env, MYSQL_PWD: config.DB_PASSWORD }, windowsHide: true }
const sql = (query) =>
  execFileSync(mysql, [...mysqlArgs, '-e', query], { ...mysqlOptions, encoding: 'utf8' }).trim()
const base = process.env.USER_UI_BASE || 'http://127.0.0.1:81'
const stamp = Date.now(),
  products = [],
  orders = [],
  checks = [],
  failures = []
async function allFinished(promises) {
  const results = await Promise.allSettled(promises)
  const failed = results.find((r) => r.status === 'rejected')
  if (failed) throw failed.reason
  return results.map((r) => r.value)
}
async function raw(url, method = 'GET', data, token = '') {
  return fetch(base + url, {
    method,
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: data === undefined ? undefined : JSON.stringify(data),
  }).then((r) => r.json())
}
async function api(url, method, data, token) {
  const b = await raw(url, method, data, token)
  assert.equal(b.code, 200, `${url}: ${JSON.stringify(b)}`)
  return b.data
}
const login = await fetch('http://127.0.0.1:8080/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ username: 'admin', password: 'admin123' }),
}).then((r) => r.json())
assert.ok(login.token)
const admin = login.token
try {
  for (let i = 0; i < 2; i++) {
    const p = await api(
      '/api/admin/items',
      'POST',
      {
        merchantId: 9001,
        categoryId: 1,
        title: `多规格并发验收-${stamp}-${i}`,
        mainImage: '/images/companions.svg',
        petSpecies: 'ALL',
        ageStage: 'ALL',
        skus: [0, 1].map((j) => ({
          specName: `规格${j}`,
          price: 0.01,
          stock: 100,
          skuCode: `MULTI${stamp}${i}${j}`,
          status: 1,
        })),
      },
      admin,
    )
    products.push(p)
    await api(`/api/admin/items/${p.id}/status`, 'PUT', { status: 1 }, admin)
  }
  const buyers = await Promise.all(
    Array.from({ length: Number(process.env.MULTI_BUYERS || 12) }, async (_, i) => {
      const buyer = await api('/api/member/register', 'POST', {
        username: `multi${stamp}${i}`,
        nickname: '多规格并发验收',
        password: 'Multi_test2026',
      })
      const address = await api(
        '/api/member/addresses',
        'POST',
        {
          receiver: '虚拟测试',
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
  const groups = [products[0].skus, products.flatMap((p) => p.skus)]
  for (const skus of groups) {
    const results = await Promise.all(
      buyers.map(async (b, i) => {
        const ordered = i % 2 ? [...skus].reverse() : skus
        const response = await raw(
          '/api/orders',
          'POST',
          {
            addressId: b.addressId,
            clientToken: crypto.randomUUID(),
            items: ordered.map((s) => ({ skuId: s.id, quantity: 1 })),
          },
          b.token,
        )
        if (response.code === 200) orders.push({ orderNo: response.data.orderNo, token: b.token })
        else
          failures.push({
            phase: `${skus.length} SKU submit`,
            code: response.errorCode,
            msg: response.msg,
          })
        return response
      }),
    )
    checks.push({
      name: `${skus.length} SKU reversed submit`,
      total: results.length,
      passed: results.filter((x) => x.code === 200).length,
    })
    const pending = orders.splice(0)
    const cancellations = await Promise.all(
      pending.map(async (o) => {
        const response = await raw(
          `/api/orders/${o.orderNo}/cancel`,
          'POST',
          { reason: '多规格回归恢复库存' },
          o.token,
        )
        if (response.code !== 200) {
          orders.push(o)
          failures.push({ phase: 'cancel', code: response.errorCode, msg: response.msg })
        }
        return response
      }),
    )
    checks.push({
      name: `${skus.length} SKU concurrent cancel`,
      total: cancellations.length,
      passed: cancellations.filter((x) => x.code === 200).length,
    })
  }
  const submit = async (buyer, skus) => {
    const order = await api(
      '/api/orders',
      'POST',
      {
        addressId: buyer.addressId,
        clientToken: crypto.randomUUID(),
        items: skus.map((s) => ({ skuId: s.id, quantity: 1 })),
      },
      buyer.token,
    )
    const owned = { orderNo: order.orderNo, token: buyer.token }
    orders.push(owned)
    return { ...owned, ...order }
  }
  // A blocked checkout must use the price committed while it waits, not its old SQL snapshot.
  const p = products[0],
    sku = p.skus[0]
  const writer = spawn(
    mysql,
    [
      ...mysqlArgs,
      '-e',
      `START TRANSACTION; UPDATE pet_item SET title=title WHERE id=${p.id}; UPDATE pet_item_sku SET price=1.01 WHERE id=${sku.id}; SELECT 'catalog-lock-ready'; DO SLEEP(2); COMMIT;`,
    ],
    mysqlOptions,
  )
  const finished = new Promise((resolve, reject) => {
    writer.once('error', reject)
    writer.once('exit', (code) =>
      code === 0 ? resolve() : reject(new Error('Catalog fixture writer failed')),
    )
  })
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error('Catalog lock readiness timeout')), 10000)
    writer.stdout.on('data', (data) => {
      if (data.toString().includes('catalog-lock-ready')) {
        clearTimeout(timeout)
        resolve()
      }
    })
    finished.catch((error) => {
      clearTimeout(timeout)
      reject(error)
    })
  })
  const repriced = await submit(buyers[0], [sku])
  await finished
  const detail = await api(`/api/orders/${repriced.orderNo}`, 'GET', undefined, buyers[0].token)
  assert.equal(Number(detail.items[0].price), 1.01)
  checks.push({ name: 'checkout uses current price after catalog lock wait', passed: true })
  await api(
    `/api/orders/${repriced.orderNo}/cancel`,
    'POST',
    { reason: '恢复库存' },
    repriced.token,
  )
  orders.splice(
    orders.findIndex((o) => o.orderNo === repriced.orderNo),
    1,
  )
  sql(`UPDATE pet_item_sku SET price=0.01 WHERE id=${sku.id}`)
  // Two compensation runs plus cancellations and new checkouts share the same four SKUs.
  const batch = await allFinished(
    buyers.map((b, i) => submit(b, i % 2 ? [...groups[1]].reverse() : groups[1])),
  )
  const split = Math.floor(batch.length / 2)
  const expired = batch.slice(0, split),
    cancelled = batch.slice(split)
  assert.ok(expired.every((o) => /^PM\d+$/.test(o.orderNo)))
  sql(
    `UPDATE pet_order SET expire_at=DATE_SUB(NOW(), INTERVAL 1 SECOND) WHERE order_no IN (${expired.map((o) => `'${o.orderNo}'`).join(',')})`,
  )
  await allFinished([
    api('/api/admin/jobs/close-timeout-orders', 'POST', undefined, admin),
    api('/api/admin/jobs/close-timeout-orders', 'POST', undefined, admin),
    ...cancelled.map((o) =>
      api(`/api/orders/${o.orderNo}/cancel`, 'POST', { reason: '混合并发恢复库存' }, o.token),
    ),
    ...buyers.map((b, i) => submit(b, i % 2 ? [...groups[1]].reverse() : groups[1])),
  ])
  for (const o of batch) {
    const current = await api(`/api/orders/${o.orderNo}`, 'GET', undefined, o.token)
    assert.equal(current.status, expired.includes(o) ? 6 : 5)
    orders.splice(
      orders.findIndex((x) => x.orderNo === o.orderNo),
      1,
    )
  }
  checks.push({
    name: `${buyers.length} initial orders + two timeout jobs + ${cancelled.length} cancels + ${buyers.length} checkouts`,
    passed: true,
  })
} catch (error) {
  failures.push({ phase: 'extended regression', message: error.message })
} finally {
  for (const o of orders) {
    const current = await api(`/api/orders/${o.orderNo}`, 'GET', undefined, o.token)
    if (current.status === 0)
      await api(`/api/orders/${o.orderNo}/cancel`, 'POST', { reason: '回归清理恢复库存' }, o.token)
    else assert.ok([5, 6].includes(current.status), 'Unexpected fixture state during cleanup')
  }
  for (const p of products) {
    const current = await api(`/api/items/${p.id}`)
    checks.push({
      name: `item ${p.id} stock restored`,
      passed: current.skus.every((s) => s.stock === 100),
    })
    await api(`/api/admin/items/${p.id}/status`, 'PUT', { status: 0 }, admin)
  }
  fs.mkdirSync('../verify/multi-sku', { recursive: true })
  const receipt = {
    at: new Date().toISOString(),
    productIds: products.map((p) => p.id),
    checks,
    failures,
  }
  fs.writeFileSync(
    `../verify/multi-sku/${process.env.RECEIPT_NAME || 'receipt'}.json`,
    JSON.stringify(receipt, null, 2),
  )
  console.log(JSON.stringify(receipt, null, 2))
}
assert.equal(failures.length, 0, 'Multi-SKU requests failed; see receipt')
assert.ok(checks.every((c) => (c.total ? c.passed === c.total : c.passed)))
