import fs from 'node:fs'
import path from 'node:path'
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
const result = execFileSync(
  config.MYSQL_EXE || 'mysql.exe',
  [
    '--host=' + (config.DB_HOST || '127.0.0.1'),
    '--port=' + (config.DB_PORT || '3306'),
    '--user=' + (config.DB_USERNAME || 'root'),
    '--database=' + (config.DB_NAME || 'shop'),
    '--default-character-set=utf8mb4',
    '-B',
  ],
  {
    input: fs.readFileSync(path.join(root, 'db/verify_runtime.sql')),
    encoding: 'utf8',
    env: { ...process.env, MYSQL_PWD: config.DB_PASSWORD },
    windowsHide: true,
  },
)
fs.mkdirSync(path.join(root, 'verify/member-features'), { recursive: true })
fs.writeFileSync(path.join(root, 'verify/member-features/runtime-db.txt'), result)
console.log(result)
if (/FAIL/.test(result)) process.exitCode = 1
