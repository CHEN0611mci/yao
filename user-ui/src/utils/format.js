export const money = (value) => Number(value ?? 0).toFixed(2)
export const species = { CAT: '猫咪', DOG: '狗狗', SMALL: '小宠', ALL: '通用' }
export const ages = { JUNIOR: '幼年', ADULT: '成年', SENIOR: '老年', ALL: '全阶段' }
export const statuses = {
  0: '待付款',
  1: '待审核',
  2: '待发货',
  3: '待收货',
  4: '已完成',
  5: '已取消',
  6: '已关闭',
  7: '售后中',
  8: '已退款',
}
export const parseSnapshot = (value) => {
  if (value && typeof value === 'object') return value
  try {
    return JSON.parse(value) || {}
  } catch {
    return {}
  }
}
export const petSnapshotName = (value) =>
  parseSnapshot(value).name ||
  (typeof value === 'string' && !value.trim().startsWith('{') ? value : '')
export function messageTarget(value) {
  if (typeof value !== 'string') return '/orders'
  const match = value.match(/^\/(?:api\/)?orders\/([A-Za-z0-9_-]+)$/)
  const legacy = value.match(/^\/pages\/order\/detail\?orderNo=([A-Za-z0-9_-]+)$/)
  return match ? `/orders/${match[1]}` : legacy ? `/orders/${legacy[1]}` : '/orders'
}
export const timeLeft = (value) => {
  const ms = new Date(String(value || '').replace(' ', 'T')).getTime() - Date.now()
  return Number.isFinite(ms) ? Math.max(0, Math.floor(ms / 1000)) : 0
}
export const orderItems = (rows) =>
  (rows || []).map((row) => ({
    skuId: row.skuId,
    quantity: row.quantity,
    ...(row.petId ? { petId: row.petId } : {}),
  }))
