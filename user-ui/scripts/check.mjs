import fs from 'node:fs'
import path from 'node:path'
import assert from 'node:assert/strict'
import { parse, compileScript, compileTemplate } from '@vue/compiler-sfc'
function files(dir) {
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .flatMap((file) =>
      file.isDirectory() ? files(path.join(dir, file.name)) : [path.join(dir, file.name)],
    )
}
const all = files('src'),
  views = all.filter(
    (file) => file.includes(`${path.sep}views${path.sep}`) && file.endsWith('.vue'),
  )
assert.equal(views.length, 19, '19 页面应全部实现')
for (const file of all) {
  const content = fs.readFileSync(file, 'utf8')
  if (file.endsWith('.vue')) {
    const { descriptor, errors } = parse(content, { filename: file })
    assert.equal(errors.length, 0, `${file}: ${errors}`)
    const script = descriptor.scriptSetup ? compileScript(descriptor, { id: file }) : null
    const result = compileTemplate({
      source: descriptor.template?.content || '',
      filename: file,
      id: file,
      compilerOptions: { bindingMetadata: script?.bindings },
    })
    assert.equal(result.errors.length, 0, `${file}: ${result.errors}`)
  }
  assert.ok(!/v-html\s*=/.test(content), `${file}: unsafe HTML binding`)
  assert.ok(
    !/Admin-Token|\/api\/admin|\/api\/merchant/.test(content),
    `${file}: member/admin domain leak`,
  )
  for (const match of content.matchAll(/from\s+['"](\.[^'"]+)['"]/g))
    assert.ok(
      fs.existsSync(path.resolve(path.dirname(file), match[1])),
      `${file}: missing ${match[1]}`,
    )
}
console.log(
  `PASS ${views.length} pages; ${all.filter((file) => file.endsWith('.vue')).length} Vue files compiled; imports and domain boundaries checked`,
)
