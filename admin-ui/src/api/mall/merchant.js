import request from '@/utils/mallRequest'

/* ------------------------- 商家-我的商品 M1–M5 ------------------------- */

// M1 我的商品列表（服务端强制 merchantId=dept_id，前端不传 merchantId）
export function listMyItems(params) {
  return request({ url: '/api/merchant/items', method: 'get', params })
}

// M2 我的商品详情（skus/images，audits=null；非本人 PET-2003）
export function getMyItem(id) {
  return request({ url: `/api/merchant/items/${id}`, method: 'get' })
}

// M3 发布商品（强制 auditStatus=0、status=0）
export function createMyItem(data) {
  return request({ url: '/api/merchant/items', method: 'post', data })
}

// M4 编辑本人商品（强制重审 + 下架）
export function updateMyItem(id, data) {
  return request({ url: `/api/merchant/items/${id}`, method: 'put', data })
}

// M5 上下架（上架要求 auditStatus=2）
export function updateMyItemStatus(id, status) {
  return request({ url: `/api/merchant/items/${id}/status`, method: 'put', data: { status } })
}

/* ------------------------- 商家-我的订单 M6–M8 ------------------------- */

// M6 我的订单列表（无 memberId/时间参数）
export function listMyOrders(params) {
  return request({ url: '/api/merchant/orders', method: 'get', params })
}

// M7 我的订单详情（非本人 PET-2003）
export function getMyOrder(orderNo) {
  return request({ url: `/api/merchant/orders/${encodeURIComponent(orderNo)}`, method: 'get' })
}

// M8 商家发货
export function shipMyOrder(orderNo, data) {
  return request({ url: `/api/merchant/orders/${encodeURIComponent(orderNo)}/ship`, method: 'put', data })
}

/* ------------------------- 商家-库存 M9–M11 ------------------------- */

// M9 我的库存总览（itemId 锁定本商品）
export function listMyStock(params) {
  return request({ url: '/api/merchant/stock', method: 'get', params })
}

// M10 我的库存流水（skuId/orderNo 至少一个条件，否则后端无商家过滤 → 前端必须拦截）
export function listMyStockLogs(params) {
  return request({ url: '/api/merchant/stock/logs', method: 'get', params })
}

// M11 我的库存调整
export function adjustMyStock(skuId, data) {
  return request({ url: `/api/merchant/stock/${skuId}`, method: 'put', data })
}
