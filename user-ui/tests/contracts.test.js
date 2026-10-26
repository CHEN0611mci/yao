import test from 'node:test'
import assert from 'node:assert/strict'
import { unwrap } from '../src/utils/response.js'
import { safeRedirect } from '../src/utils/auth.js'
import { messageTarget, parseSnapshot, statuses, orderItems } from '../src/utils/format.js'
import { cancelledPage } from '../src/utils/orders.js'

test('unwrap handles HTTP and business errors, trace IDs, and duplicate order success', () => {
  assert.deepEqual(unwrap({ code: 200, data: { total: 1 } }), { total: 1 })
  assert.deepEqual(unwrap({ code: 4001, errorCode: 'PET-4001', data: { orderNo: 'existing' } }), {
    orderNo: 'existing',
  })
  for (const http of [200, 409])
    assert.throws(
      () =>
        unwrap(
          { code: 3001, errorCode: 'PET-3001', message: '库存不足', traceId: 'abcdef123456' },
          http,
        ),
      (error) =>
        error.message.includes('PET-3001') &&
        error.message.includes('123456') &&
        error.status === http,
    )
  assert.throws(() => unwrap({ msg: '字段错误' }, 400), /字段错误/)
  assert.throws(
    () => unwrap({}, 429, '7'),
    (error) => error.retryAfter === 7,
  )
  assert.throws(() => unwrap('<html>bad gateway</html>', 502), /服务暂时不可用/)
})

test('login redirects and notification destinations reject external or unsafe URLs', () => {
  assert.equal(safeRedirect('/checkout?from=cart'), '/checkout?from=cart')
  for (const value of [
    'https://evil.example',
    '//evil.example',
    '/\\evil',
    '/\nevil',
    '/login?redirect=/',
    '/register',
    null,
  ])
    assert.equal(safeRedirect(value), '/')
  assert.equal(messageTarget('/pages/order/detail?orderNo=PET123'), '/orders/PET123')
  assert.equal(messageTarget('/orders/PET123'), '/orders/PET123')
  assert.equal(messageTarget('/api/orders/PET123'), '/orders/PET123')
  for (const value of [
    'javascript:alert(1)',
    '//evil.example',
    '/orders/../../member',
    '/orders/A?next=https://evil.example',
  ])
    assert.equal(messageTarget(value), '/orders')
})

test('order snapshots tolerate historical text and submission sends only allowed line fields', () => {
  assert.deepEqual(parseSnapshot('{"receiver":"测试"}'), { receiver: '测试' })
  assert.deepEqual(parseSnapshot('奶糖、豆包'), {})
  assert.deepEqual(
    orderItems([
      { skuId: 1, quantity: 2, petId: 3, costPrice: 8, memberId: 8 },
      { skuId: 2, quantity: 1 },
    ]),
    [
      { skuId: 1, quantity: 2, petId: 3 },
      { skuId: 2, quantity: 1 },
    ],
  )
  assert.equal(statuses[2], '待发货')
  assert.equal(statuses[3], '待收货')
})

test('cancelled orders merge and paginate both status streams beyond 100 records', async () => {
  const data = Object.fromEntries(
    [5, 6].map((status) => [
      status,
      Array.from({ length: 126 }, (_, index) => ({
        orderNo: `${status}-${index}`,
        createTime: String(1000 - (index * 2 + (status - 5))).padStart(4, '0'),
      })),
    ]),
  )
  const fetchPage = async ({ status, pageNum, pageSize }) => ({
    total: data[status].length,
    list: data[status].slice((pageNum - 1) * pageSize, pageNum * pageSize),
  })
  const page = await cancelledPage(fetchPage, 22, 10)
  assert.equal(page.total, 252)
  assert.equal(page.list.length, 10)
  assert.deepEqual(
    page.list.map((row) => row.orderNo),
    Array.from(
      { length: 10 },
      (_, i) => `${(210 + i) % 2 === 0 ? 5 : 6}-${Math.floor((210 + i) / 2)}`,
    ),
  )
})
