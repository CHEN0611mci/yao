/**
 * 商城前端静态自检脚本（管理端）
 *
 * 用途：在 `npm run build:prod` 之前做结构性自检，覆盖设计文档 §9.4 的静态项：
 *  1. 10 个页面文件存在，且 `<script setup name="...">` 与路由名一致；
 *  2. 菜单 component 字符串与 `src/views/**` 文件全等；
 *  3. 所有 `@/components/mall/**`、`@/api/mall/**`、`@/utils/mallDict` 的 import 都能解析；
 *  4. 所有 SFC 能被 @vue/compiler-sfc 解析并编译（模板/脚本语法）；
 *  5. `v-hasPermi` 权限码 ∈ 设计文档 §4.5 的 24 个；
 *  6. 无 console.log / addDateRange / 直接 axios 引用等禁止项。
 *
 * 运行：cd admin-ui && node scripts/mall-check.mjs
 */
import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs'
import { join, dirname, relative, resolve } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { parse, compileScript, compileTemplate } from '@vue/compiler-sfc'

const here = dirname(fileURLToPath(import.meta.url))
const root = resolve(here, '..')
const srcDir = join(root, 'src')

const problems = []
const warnings = []
const fail = msg => problems.push(msg)
const warn = msg => warnings.push(msg)

/* ---------------------------- 1. 页面清单 ---------------------------- */
const PAGES = [
  { file: 'views/mall/dashboard/index.vue', name: 'Dashboard', component: 'mall/dashboard/index', url: '/mall/dashboard' },
  { file: 'views/mall/item/index.vue', name: 'Items', component: 'mall/item/index', url: '/mall/items' },
  { file: 'views/mall/audit/index.vue', name: 'Audit', component: 'mall/audit/index', url: '/mall/audit' },
  { file: 'views/mall/category/index.vue', name: 'Categories', component: 'mall/category/index', url: '/mall/categories' },
  { file: 'views/mall/order/index.vue', name: 'Orders', component: 'mall/order/index', url: '/mall/orders' },
  { file: 'views/mall/member/index.vue', name: 'Members', component: 'mall/member/index', url: '/mall/members' },
  { file: 'views/mall/stock/index.vue', name: 'Stock', component: 'mall/stock/index', url: '/mall/stock' },
  { file: 'views/mall/auditlog/index.vue', name: 'Audit-log', component: 'mall/auditlog/index', url: '/mall/audit-log' },
  { file: 'views/mall/merchant/item/index.vue', name: 'MerchantItems', component: 'mall/merchant/item/index', url: '/merchant/items' },
  { file: 'views/mall/merchant/order/index.vue', name: 'MerchantOrders', component: 'mall/merchant/order/index', url: '/merchant/orders' }
]

/* ------------------------- 2. 权限码全量 ------------------------- */
const PERMISSIONS = new Set([
  'mall:dashboard:view',
  'mall:item:list', 'mall:item:add', 'mall:item:edit', 'mall:item:status', 'mall:item:audit',
  'mall:category:list', 'mall:category:add', 'mall:category:edit', 'mall:category:remove',
  'mall:order:list', 'mall:order:ship',
  'mall:member:list', 'mall:member:status',
  'mall:stock:list', 'mall:stock:adjust',
  'mall:audit:list',
  'mall:job:trigger',
  'mall:merchant:item:list', 'mall:merchant:item:add', 'mall:merchant:item:edit', 'mall:merchant:item:status',
  'mall:merchant:order:list', 'mall:merchant:order:ship'
])

/* ---------------------------- 工具函数 ---------------------------- */
function walk(dir, out = []) {
  if (!existsSync(dir)) return out
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry)
    if (statSync(full).isDirectory()) walk(full, out)
    else out.push(full)
  }
  return out
}

function rel(p) {
  return relative(root, p).replaceAll('\\', '/')
}

// 收集具名导出（export function / export const / export { a, b }）
function collectExports(file) {
  // .vue 单文件组件：<script setup> 由编译器生成 default 导出
  if (file.endsWith('.vue')) return new Set(['default'])
  const code = readFileSync(file, 'utf8')
  const names = new Set()
  for (const m of code.matchAll(/export\s+(?:async\s+)?(?:function|const|let|var|class)\s+([A-Za-z_$][\w$]*)/g)) names.add(m[1])
  const defaultMatch = /export\s+default\s+/.test(code)
  if (defaultMatch) names.add('default')
  for (const m of code.matchAll(/export\s*\{([^}]*)\}/g)) {
    m[1].split(',').forEach(part => {
      const name = part.trim().split(/\s+as\s+/).pop()
      if (name) names.add(name.trim())
    })
  }
  return names
}

// 解析单文件 import 语句
function parseImports(code) {
  const imports = []
  const re = /import\s+([^'"]*?)\s+from\s+['"]([^'"]+)['"]/g
  let m
  while ((m = re.exec(code))) {
    imports.push({ clause: m[1].trim(), spec: m[2] })
  }
  return imports
}

function resolveAlias(spec) {
  if (!spec.startsWith('@/')) return null
  const relPath = spec.slice(2)
  const candidates = [relPath, `${relPath}.js`, `${relPath}.vue`, join(relPath, 'index.js'), join(relPath, 'index.vue')]
  for (const cand of candidates) {
    const full = join(srcDir, cand)
    if (existsSync(full) && statSync(full).isFile()) return full
  }
  return null
}

function importedNames(clause) {
  // 支持 default、{a, b as c}、* as ns
  const names = []
  const brace = clause.match(/\{([^}]*)\}/)
  if (brace) {
    brace[1].split(',').forEach(part => {
      const name = part.trim().split(/\s+as\s+/)[0]
      if (name) names.push(name)
    })
  }
  const def = clause.replace(/\{[^}]*\}/g, '').replace(/,/g, ' ').trim()
  if (def && !def.startsWith('*')) names.push('default')
  if (/^\*\s+as\s+/.test(def)) names.push('*')
  return names
}

/* ------------------------ 3. 页面存在与命名 ------------------------ */
for (const page of PAGES) {
  const full = join(srcDir, page.file)
  if (!existsSync(full)) {
    fail(`[缺失] 页面文件不存在：src/${page.file}（对应 ${page.url} / component=${page.component}）`)
    continue
  }
  const code = readFileSync(full, 'utf8')
  if (!/src\/views\/|views\/mall/.test(page.file)) {
    // 占位
  }
  const nameMatch = code.match(/<script\s+setup\s+name="([^"]+)"/)
  if (!nameMatch) {
    fail(`[命名] src/${page.file} 缺少 <script setup name="...">`)
  } else if (nameMatch[1] !== page.name) {
    fail(`[命名] src/${page.file} 页面 name=${nameMatch[1]}，期望 ${page.name}（与路由名一致）`)
  }
}

/* ------------------- 4. 组件 component 字符串全等 ------------------- */
const viewsDir = join(srcDir, 'views')
for (const page of PAGES) {
  const expectFile = join(viewsDir, `${page.component}.vue`)
  if (!existsSync(expectFile)) {
    fail(`[路由] component=${page.component} 找不到 src/views/${page.component}.vue`)
  }
}

/* --------------------------- 5. SFC 编译 --------------------------- */
const mallVueFiles = [
  ...walk(join(srcDir, 'views', 'mall')),
  ...walk(join(srcDir, 'components', 'mall'))
].filter(f => f.endsWith('.vue'))

for (const file of mallVueFiles) {
  const source = readFileSync(file, 'utf8')
  const id = rel(file)
  try {
    const { descriptor, errors } = parse(source, { filename: file })
    if (errors && errors.length) {
      errors.forEach(e => fail(`[SFC] ${id}: ${e.message || e}`))
      continue
    }
    if (descriptor.scriptSetup) {
      compileScript(descriptor, { id, isProd: false })
    }
    if (descriptor.template) {
      const result = compileTemplate({
        source: descriptor.template.content,
        filename: file,
        id,
        compilerOptions: { mode: 'module' }
      })
      if (result.errors && result.errors.length) {
        result.errors.forEach(e => fail(`[模板] ${id}: ${e.message || e}`))
      }
    }
  } catch (e) {
    fail(`[编译] ${id}: ${e.message}`)
  }

  /* ------------------------ 6. 禁止项检查 ------------------------ */
  if (/console\.(log|debug|warn)\(/.test(source)) fail(`[禁止] ${id} 含 console 输出`)
  if (/addDateRange\s*\(/.test(source) && !source.includes('不要') && !source.includes('禁止')) {
    fail(`[禁止] ${id} 使用了 addDateRange（商城接口日期为顶层参数）`)
  }
  if (/from\s+['"]axios['"]/.test(source)) fail(`[禁止] ${id} 直接 import axios`)
  if (/from\s+['"]@\/utils\/request['"]/.test(source) && /api\/(admin|merchant|upload|home)/.test(source)) {
    warn(`[提示] ${id} 同时引用若依 request 与商城接口路径，请确认未混用`)
  }

  /* --------------------- 7. 权限码校验（v-hasPermi） --------------------- */
  for (const m of source.matchAll(/v-hasPermi\s*=\s*["']\[([^\]]*)\]["']/g)) {
    for (const q of m[1].matchAll(/['"]([^'"]+)['"]/g)) {
      if (!PERMISSIONS.has(q[1])) fail(`[权限] ${id} 权限码 ${q[1]} 不在 24 个 mall:* 内`)
    }
  }
  for (const m of source.matchAll(/hasPermi(?:Or)?\(\s*\[([^\]]*)\]/g)) {
    for (const q of m[1].matchAll(/['"]([^'"]+)['"]/g)) {
      if (!PERMISSIONS.has(q[1])) fail(`[权限] ${id} 权限码 ${q[1]} 不在 24 个 mall:* 内`)
    }
  }
}

/* ------------------- 8. import 解析与导出名校验 ------------------- */
const checkFiles = [...mallVueFiles, ...walk(join(srcDir, 'api', 'mall')).filter(f => f.endsWith('.js'))]
const exportCache = new Map()
function exportsOf(file) {
  if (!exportCache.has(file)) exportCache.set(file, collectExports(file))
  return exportCache.get(file)
}

for (const file of checkFiles) {
  const code = readFileSync(file, 'utf8')
  const id = rel(file)
  for (const { clause, spec } of parseImports(code)) {
    if (spec.startsWith('@/')) {
      const target = resolveAlias(spec)
      if (!target) {
        fail(`[import] ${id}: 无法解析 ${spec}`)
        continue
      }
      const names = importedNames(clause)
      const available = exportsOf(target)
      for (const name of names) {
        if (name === '*' || name === 'default') {
          if (name === 'default' && !available.has('default')) fail(`[import] ${id}: ${spec} 无 default 导出`)
          continue
        }
        if (!available.has(name)) fail(`[import] ${id}: ${spec} 未导出 ${name}`)
      }
    }
  }
}

/* ------------------- 9. 设计文档要求的公共文件齐全 ------------------- */
const REQUIRED = [
  'utils/mallRequest.js',
  'utils/mallDict.js',
  'api/mall/dashboard.js', 'api/mall/item.js', 'api/mall/category.js', 'api/mall/order.js',
  'api/mall/member.js', 'api/mall/stock.js', 'api/mall/auditLog.js', 'api/mall/merchant.js',
  'api/mall/upload.js',
  'components/mall/MallStatusTag.vue', 'components/mall/MallMoney.vue', 'components/mall/MallImageUpload.vue',
  'components/mall/SkuEditor.vue', 'components/mall/CategoryTreeSelect.vue',
  'components/mall/OrderDetailDrawer.vue', 'components/mall/AuditDrawer.vue', 'components/mall/StockAdjustDialog.vue'
]
REQUIRED.forEach(p => {
  if (!existsSync(join(srcDir, p))) fail(`[缺失] 公共文件不存在：src/${p}`)
})

/* ------------------------------- 输出 ------------------------------- */
console.log('==== 商城管理端前端静态自检 ====')
console.log(`检查页面：${PAGES.length} 个；检查 SFC：${mallVueFiles.length} 个`)
if (warnings.length) {
  console.log(`\n警告 ${warnings.length} 条：`)
  warnings.forEach(w => console.log('  ! ' + w))
}
if (problems.length) {
  console.log(`\n失败 ${problems.length} 条：`)
  problems.forEach(p => console.log('  × ' + p))
  process.exit(1)
}
console.log('\n全部静态检查通过 ✔')
