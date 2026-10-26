// Synthetic accounts only. Redis credentials and session tokens are never written to receipts.
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import crypto from 'node:crypto'
import { execFileSync } from 'node:child_process'
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
const cli = config.REDIS_CLI || 'redis-cli.exe'
const redisArgs = [
  '-h',
  config.REDIS_HOST || '127.0.0.1',
  '-p',
  config.REDIS_PORT || '6379',
  '-n',
  config.REDIS_DATABASE || '0',
  '--no-auth-warning',
]
const redisEnvironment = { ...process.env }
if (config.REDIS_PASSWORD) redisEnvironment.REDISCLI_AUTH = config.REDIS_PASSWORD
else delete redisEnvironment.REDISCLI_AUTH
const redisOptions = {
  encoding: 'utf8',
  windowsHide: true,
  env: redisEnvironment,
  maxBuffer: 32 * 1024 * 1024,
}
const redis = (...args) => {
  const output = execFileSync(cli, [...redisArgs, '--json', ...args.map(String)], redisOptions)
  return args[0] === 'INFO' ? output : JSON.parse(output)
}
const tokenKey = (t) => `member_tokens:${t}`,
  indexKey = (id) => `member_sessions:${id}`
function pipe(commands) {
  const input = commands
    .map(
      (args) =>
        `*${args.length}\r\n` +
        args
          .map((x) => {
            const s = String(x)
            return `$${Buffer.byteLength(s)}\r\n${s}\r\n`
          })
          .join(''),
    )
    .join('')
  const result = execFileSync(cli, [...redisArgs, '--pipe'], { ...redisOptions, input })
  assert.match(result, /errors: 0,/)
}
const base = process.env.USER_UI_BASE || 'http://127.0.0.1:81',
  stamp = Date.now(),
  checks = [],
  fixtures = []
const password = 'Session_test2026'
async function api(url, method = 'GET', data, token = '', expected) {
  const options = {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: data === undefined ? undefined : JSON.stringify(data),
  }
  let response
  try {
    response = await fetch(base + url, options)
  } catch (error) {
    if (method !== 'GET') throw new Error(`Transport failed: ${method} ${url}`, { cause: error })
    // A read immediately after a real restart may reuse a socket closed by the old process.
    response = await fetch(base + url, options)
  }
  const b = await response.json()
  assert.equal(expected ? b.errorCode : b.code, expected || 200, `${url}: ${b.message}`)
  return b.data
}
const sessionId = (token) => {
  const bytes = crypto
    .createHash('md5')
    .update('session:' + token)
    .digest()
  bytes[6] = (bytes[6] & 15) | 48
  bytes[8] = (bytes[8] & 63) | 128
  const h = bytes.toString('hex')
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`
}
const stats = () =>
  Object.fromEntries(
    redis('INFO', 'commandstats')
      .split(/\r?\n/)
      .filter((x) => x.startsWith('cmdstat_'))
      .map((x) => {
        const [key, value] = x.split(':')
        return [key.slice(8), Number(value.match(/calls=(\d+)/)[1])]
      }),
  )
// Fastjson's existing typed cache format writes Java long literals with an L suffix.
const cachedSession = (token) =>
  JSON.parse(redis('GET', tokenKey(token)).replace(/(:\s*-?\d+)L(?=[,}])/g, '$1'))
const delta = (before, after, key) => (after[key] || 0) - (before[key] || 0)
let main, other, second, legacy
try {
  main = await api('/api/member/register', 'POST', {
    username: `session${stamp}`,
    nickname: '会话索引验收',
    password,
  })
  other = await api('/api/member/register', 'POST', {
    username: `foreign${stamp}`,
    nickname: '隔离验收',
    password,
  })
  second = (await api('/api/member/login', 'POST', { username: main.member.username, password }))
    .token
  const memberId = main.member.id,
    otherId = other.member.id
  assert.equal(redis('HLEN', indexKey(memberId)), 2)
  checks.push('new sessions atomically indexed: PASS')
  legacy = crypto.randomBytes(16).toString('hex')
  const historical = cachedSession(main.token)
  historical.token = legacy
  delete historical.sessionId
  historical.client = 'Legacy Migration Test'
  redis('SET', tokenKey(legacy), JSON.stringify(historical), 'PX', 2 * 86400000)
  const legacyTtl = redis('PTTL', tokenKey(legacy))
  // Restart verifies the actual packaged runtime's startup migration, not a mocked helper.
  execFileSync(
    'powershell.exe',
    [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      path.join(root, 'setup/stop-backend.ps1'),
    ],
    { stdio: 'ignore', windowsHide: true },
  )
  execFileSync(
    'powershell.exe',
    [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      path.join(root, 'setup/start-backend.ps1'),
      '-SkipBuild',
    ],
    { stdio: 'ignore', windowsHide: true },
  )
  await api('/api/member/me', 'GET', undefined, main.token)
  await api('/api/member/me', 'GET', undefined, legacy)
  assert.equal(redis('HGET', indexKey(memberId), sessionId(legacy)), legacy)
  assert.ok(
    redis('PTTL', tokenKey(legacy)) <= legacyTtl &&
      redis('PTTL', tokenKey(legacy)) > legacyTtl - 120000,
  )
  let sessions = await api('/api/member/sessions', 'GET', undefined, main.token)
  assert.equal(sessions.length, 3)
  assert.ok(
    sessions.some((s) => s.id === sessionId(legacy) && s.client === 'Legacy Migration Test'),
  )
  assert.ok(
    !JSON.stringify(sessions).includes(main.token) && !JSON.stringify(sessions).includes(legacy),
  )
  checks.push(
    'restart migrates legacy UUID-less session without extending TTL or exposing tokens: PASS',
  )
  console.log('Session index test: restart migration passed')
  const sample = async (count) => {
    const before = stats(),
      times = []
    for (let i = 0; i < count; i++) {
      const start = performance.now()
      assert.equal((await api('/api/member/sessions', 'GET', undefined, main.token)).length, 3)
      times.push(performance.now() - start)
    }
    const after = stats()
    times.sort((a, b) => a - b)
    return {
      requests: count,
      medianMs: Number(times[Math.floor(count / 2)].toFixed(2)),
      p95Ms: Number(times[Math.ceil(count * 0.95) - 1].toFixed(2)),
      getCalls: delta(before, after, 'get'),
      keysCalls: delta(before, after, 'keys'),
      scanCalls: delta(before, after, 'scan'),
    }
  }
  const baseline = await sample(10)
  const foreignSession = cachedSession(other.token)
  for (let i = 0; i < 5000; i++)
    fixtures.push({ token: crypto.randomBytes(16).toString('hex'), id: crypto.randomUUID() })
  pipe(
    fixtures.flatMap((f) => [
      [
        'SET',
        tokenKey(f.token),
        JSON.stringify({
          ...foreignSession,
          token: f.token,
          sessionId: f.id,
          client: 'Synthetic load fixture',
        }),
        'PX',
        '300000',
      ],
      ['HSET', indexKey(otherId), f.id, f.token],
    ]),
  )
  const loaded = await sample(20)
  console.log('Session index test: 5000 foreign sessions sampled')
  assert.equal(loaded.keysCalls, 0)
  assert.equal(loaded.scanCalls, 0)
  assert.ok(
    loaded.getCalls <= loaded.requests * 5,
    'Device list must read only its three own sessions plus authentication',
  )
  assert.ok(loaded.getCalls / loaded.requests <= baseline.getCalls / baseline.requests + 1)
  checks.push(
    '5000 foreign sessions do not add per-request token reads; KEYS/SCAN calls stay zero: PASS',
  )
  await api(
    `/api/member/sessions/${sessionId(legacy)}`,
    'DELETE',
    undefined,
    other.token,
    'PET-2003',
  )
  await api(`/api/member/sessions/${sessionId(legacy)}`, 'DELETE', undefined, main.token)
  await api('/api/member/me', 'GET', undefined, legacy, 'PET-2001')
  checks.push('single-session revoke is owned and immediately invalidates authentication: PASS')
  redis('PEXPIRE', tokenKey(second), '1')
  await new Promise((resolve) => setTimeout(resolve, 20))
  assert.equal((await api('/api/member/sessions', 'GET', undefined, main.token)).length, 1)
  assert.equal(redis('HLEN', indexKey(memberId)), 1)
  checks.push('expired session is pruned from member index: PASS')
  redis('PEXPIRE', tokenKey(main.token), '3600000')
  await api('/api/member/me', 'GET', undefined, main.token)
  assert.ok(redis('PTTL', tokenKey(main.token)) > 6 * 86400000)
  assert.ok(redis('PTTL', indexKey(memberId)) >= redis('PTTL', tokenKey(main.token)) - 1000)
  checks.push('sliding renewal updates token and index lifetimes together: PASS')
  const racer = (
    await api('/api/member/login', 'POST', { username: main.member.username, password })
  ).token
  const raceId = cachedSession(racer).sessionId
  redis('PEXPIRE', tokenKey(racer), '3600000')
  await Promise.all([
    api(`/api/member/sessions/${raceId}`, 'DELETE', undefined, main.token),
    ...Array.from({ length: 16 }, async () => {
      const result = await fetch(base + '/api/member/me', {
        headers: { Authorization: `Bearer ${racer}` },
      }).then((r) => r.json())
      assert.ok(result.code === 200 || result.errorCode === 'PET-2001')
    }),
  ])
  await api('/api/member/me', 'GET', undefined, racer, 'PET-2001')
  assert.equal(redis('EXISTS', tokenKey(racer)), 0)
  assert.equal(redis('HGET', indexKey(memberId), raceId), null)
  checks.push('concurrent renewal and revoke cannot recreate the revoked session: PASS')
  const extra = (
    await api('/api/member/login', 'POST', { username: main.member.username, password })
  ).token
  assert.equal(await api('/api/member/sessions/revoke-others', 'POST', undefined, main.token), 1)
  await api('/api/member/me', 'GET', undefined, extra, 'PET-2001')
  assert.equal(redis('EXISTS', tokenKey(fixtures[0].token)), 1)
  checks.push('revoke-others preserves current and foreign sessions: PASS')
  await api(
    '/api/member/password',
    'PUT',
    { oldPassword: password, newPassword: 'Session_changed2026' },
    main.token,
  )
  await api('/api/member/me', 'GET', undefined, main.token, 'PET-2001')
  assert.equal(redis('EXISTS', indexKey(memberId)), 0)
  assert.equal(redis('EXISTS', tokenKey(fixtures[0].token)), 1)
  assert.equal(redis('HLEN', indexKey(otherId)), fixtures.length + 1)
  checks.push(
    'password change removes own index and sessions without touching foreign sessions: PASS',
  )
  await api('/api/member/logout', 'POST', undefined, other.token)
  await api('/api/member/me', 'GET', undefined, other.token, 'PET-2001')
  checks.push('logout invalidates session immediately: PASS')
  const receipt = {
    at: new Date().toISOString(),
    checks,
    baseline,
    with5000ForeignSessions: loaded,
    note: 'Timings are local samples, not production capacity measurements. No secrets in receipt.',
  }
  fs.mkdirSync(path.join(root, 'verify/session-index'), { recursive: true })
  fs.writeFileSync(
    path.join(root, 'verify/session-index/receipt.json'),
    JSON.stringify(receipt, null, 2),
  )
  console.log(JSON.stringify(receipt, null, 2))
} finally {
  for (let i = 0; i < fixtures.length; i += 256) {
    const batch = fixtures.slice(i, i + 256)
    pipe([
      ['DEL', ...batch.map((f) => tokenKey(f.token))],
      ['HDEL', indexKey(other.member.id), ...batch.map((f) => f.id)],
    ])
  }
  for (const value of [main?.token, other?.token, second, legacy])
    if (value) redis('DEL', tokenKey(value))
  for (const value of [main?.member?.id, other?.member?.id])
    if (value) redis('DEL', indexKey(value))
}
