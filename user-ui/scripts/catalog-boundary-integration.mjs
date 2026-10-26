// Boundary tests operate on new synthetic categories, member and products only.
import assert from 'node:assert/strict'
import fs from 'node:fs'
const base = process.env.USER_UI_BASE || 'http://127.0.0.1:81'
const stamp = Date.now(),
  categories = [],
  checks = []
async function raw(url, method = 'GET', data, token = '') {
  return fetch(base + url, {
    method,
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: data === undefined ? undefined : JSON.stringify(data),
  }).then((r) => r.json())
}
async function api(url, method, data, token) {
  const result = await raw(url, method, data, token)
  assert.equal(result.code, 200, JSON.stringify(result))
  return result.data
}
function rejected(name, result) {
  checks.push({
    name,
    code: result.code,
    errorCode: result.errorCode,
    message: result.message,
    passed: result.errorCode === 'PET-1001',
  })
}
const login = await fetch('http://127.0.0.1:8080/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ username: 'admin', password: 'admin123' }),
}).then((r) => r.json())
assert.ok(login.token)
const token = login.token
const cat = (name, parentId = 0) => ({
  name: `边界验收-${stamp}-${name}`,
  parentId,
  petScope: 'ALL',
  status: 0,
})
try {
  const a = await api('/api/admin/categories', 'POST', cat('A'), token)
  categories.push(a)
  const b = await api('/api/admin/categories', 'POST', cat('B'), token)
  categories.push(b)
  const c = await api('/api/admin/categories', 'POST', cat('C', a.id), token)
  categories.push(c)
  rejected(
    'root with a child cannot be moved below another root',
    await raw(`/api/admin/categories/${a.id}`, 'PUT', cat('A', b.id), token),
  )
  await api(`/api/admin/categories/${a.id}`, 'PUT', cat('A'), token)
  rejected(
    'a third level cannot be created',
    await raw('/api/admin/categories', 'POST', cat('third', c.id), token),
  )
  rejected(
    'a category cannot be its own parent',
    await raw(`/api/admin/categories/${b.id}`, 'PUT', cat('B', b.id), token),
  )
  const member = await api('/api/member/register', 'POST', {
    username: `bound${stamp}`,
    nickname: '边界测试',
    password: 'Boundary_test2026',
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
      detail: '仅用于参数校验',
      isDefault: 1,
    },
    member.token,
  )
  if (!process.env.BEFORE_FIX) {
    const forbidden = await raw('/api/admin/categories', 'GET', undefined, member.token)
    checks.push({
      name: 'member opaque token cannot access admin categories',
      passed: [401, 403].includes(forbidden.code),
    })
    const forged = await raw('/api/admin/categories', 'GET', undefined, '0'.repeat(32))
    checks.push({
      name: 'forged opaque token cannot authenticate an admin',
      passed: [401, 403].includes(forged.code),
    })
  }
  rejected(
    'null order line is a validation error',
    await raw(
      '/api/orders',
      'POST',
      { addressId: address.id, clientToken: crypto.randomUUID(), items: [null] },
      member.token,
    ),
  )
  rejected(
    'null SKU is a validation error',
    await raw(
      '/api/admin/items',
      'POST',
      {
        merchantId: 9001,
        categoryId: a.id,
        title: `边界商品-${stamp}`,
        mainImage: '/images/companions.svg',
        petSpecies: 'ALL',
        ageStage: 'ALL',
        skus: [null],
      },
      token,
    ),
  )
  if (!process.env.BEFORE_FIX) {
    rejected(
      'null product image is a validation error',
      await raw(
        '/api/admin/items',
        'POST',
        {
          merchantId: 9001,
          categoryId: a.id,
          title: `边界商品-${stamp}`,
          mainImage: '/images/companions.svg',
          petSpecies: 'ALL',
          ageStage: 'ALL',
          skus: [{ specName: '测试', price: 0.01, stock: 1 }],
          images: [null],
        },
        token,
      ),
    )
    const x = await api('/api/admin/categories', 'POST', cat('X'), token)
    categories.push(x)
    const y = await api('/api/admin/categories', 'POST', cat('Y'), token)
    categories.push(y)
    const cycle = await Promise.all([
      raw(`/api/admin/categories/${x.id}`, 'PUT', cat('X', y.id), token),
      raw(`/api/admin/categories/${y.id}`, 'PUT', cat('Y', x.id), token),
    ])
    checks.push({
      name: 'concurrent opposing moves cannot create a cycle',
      passed:
        cycle.filter((r) => r.code === 200).length === 1 &&
        cycle.filter((r) => r.errorCode === 'PET-1001').length === 1,
    })
    await api(`/api/admin/categories/${x.id}`, 'PUT', cat('X'), token)
    await api(`/api/admin/categories/${y.id}`, 'PUT', cat('Y'), token)
    const moveAndCreate = await Promise.all([
      raw(`/api/admin/categories/${x.id}`, 'PUT', cat('X', y.id), token),
      raw('/api/admin/categories', 'POST', cat('Z', x.id), token),
    ])
    if (moveAndCreate[1].code === 200) categories.push(moveAndCreate[1].data)
    checks.push({
      name: 'child creation competing with parent move preserves two levels',
      passed:
        moveAndCreate.filter((r) => r.code === 200).length === 1 &&
        moveAndCreate.filter((r) => r.errorCode === 'PET-1001').length === 1,
    })
    await api(`/api/admin/categories/${x.id}`, 'PUT', cat('X'), token)
    const d = await api('/api/admin/categories', 'POST', cat('D'), token)
    categories.push(d)
    const deleteAndCreate = await Promise.all([
      raw(`/api/admin/categories/${d.id}`, 'DELETE', undefined, token),
      raw('/api/admin/categories', 'POST', cat('E', d.id), token),
    ])
    if (deleteAndCreate[0].code === 200)
      categories.splice(
        categories.findIndex((c) => c.id === d.id),
        1,
      )
    if (deleteAndCreate[1].code === 200) categories.push(deleteAndCreate[1].data)
    checks.push({
      name: 'parent deletion competing with child creation cannot orphan a category',
      passed:
        deleteAndCreate.filter((r) => r.code === 200).length === 1 &&
        deleteAndCreate.filter((r) => ['PET-1001', 'PET-1003'].includes(r.errorCode)).length === 1,
    })
    const tree = await api('/api/admin/categories', 'GET', undefined, token)
    const ids = new Set(categories.map((c) => c.id))
    const seen = new Set()
    const visit = (nodes, depth) => {
      for (const node of nodes) {
        if (ids.has(node.id)) {
          assert.ok(depth <= 2)
          assert.ok(!seen.has(node.id))
          seen.add(node.id)
        }
        visit(node.children || [], depth + 1)
      }
    }
    visit(tree, 1)
    assert.equal(seen.size, ids.size)
    checks.push({ name: 'all test categories remain reachable within two levels', passed: true })
  }
} finally {
  for (const c of categories.reverse())
    await api(`/api/admin/categories/${c.id}`, 'DELETE', undefined, token)
  fs.mkdirSync('../verify/catalog-boundary', { recursive: true })
  const receipt = { at: new Date().toISOString(), checks }
  fs.writeFileSync(
    `../verify/catalog-boundary/${process.env.BEFORE_FIX ? 'before-fix' : 'receipt'}.json`,
    JSON.stringify(receipt, null, 2),
  )
  console.log(JSON.stringify(receipt, null, 2))
}
if (!process.env.BEFORE_FIX) assert.ok(checks.every((c) => c.passed))
