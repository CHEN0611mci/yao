import { readStorage, writeStorage } from './storage.js'
const key = 'petmall_search_history'
export function history() {
  const value = readStorage(key, [])
  return Array.isArray(value) ? value.filter((x) => typeof x === 'string').slice(0, 10) : []
}
export function remember(term) {
  const text = term.trim().slice(0, 100)
  if (text) writeStorage(key, [text, ...history().filter((x) => x !== text)].slice(0, 10))
}
export function forget(term) {
  writeStorage(key, term ? history().filter((x) => x !== term) : [])
}
