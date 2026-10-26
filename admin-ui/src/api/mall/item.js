import request from '@/utils/mallRequest'

// A2 商品列表（管理端/审核共用，权限 hasAnyPermi('mall:item:list,mall:item:audit')）
export function listItems(params) {
  return request({ url: '/api/admin/items', method: 'get', params })
}

// A3 商品详情（含 skus/images/audits）
export function getItemDetail(id) {
  return request({ url: `/api/admin/items/${id}`, method: 'get' })
}

// A4 新建商品（admin 新建直接 auditStatus=2、status=0）
export function createItem(data) {
  return request({ url: '/api/admin/items', method: 'post', data })
}

// A5 编辑商品（admin 不重审，不改上下架）
export function updateItem(id, data) {
  return request({ url: `/api/admin/items/${id}`, method: 'put', data })
}

// A6 上下架（上架要求 auditStatus=2，否则 PET-3003）
export function updateItemStatus(id, status) {
  return request({ url: `/api/admin/items/${id}/status`, method: 'put', data: { status } })
}

// A7 审核（auditStatus 1 驳回 / 2 通过；驳回 remark 必填且强制下架）
export function auditItem(id, data) {
  return request({ url: `/api/admin/items/${id}/audit`, method: 'put', data })
}
