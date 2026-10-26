export function readStorage(key, fallback = null, storage = localStorage) {
  try {
    return JSON.parse(storage.getItem(key)) ?? fallback
  } catch {
    return fallback
  }
}
export const writeStorage = (key, value, storage = localStorage) =>
  storage.setItem(key, JSON.stringify(value))
