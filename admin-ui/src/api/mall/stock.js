import request from '@/utils/mallRequest'

// A18 库存总览（无分页，返回 Map 数组，11 个 key）
export function listStockOverview(params) {
  return request({ url: '/api/admin/stock', method: 'get', params })
}

// A19 库存流水（无分页）
export function listStockLogs(params) {
  return request({ url: '/api/admin/stock/logs', method: 'get', params })
}

// A20 库存调整（目标库存，非增量；不足 PET-3001）
export function adjustStock(skuId, data) {
  return request({ url: `/api/admin/stock/${skuId}`, method: 'put', data })
}
