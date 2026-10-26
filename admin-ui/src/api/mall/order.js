import request from '@/utils/mallRequest'

// A13 订单列表（startTime/endTime 为顶层参数，禁用 addDateRange）
export function listOrders(params) {
  return request({ url: '/api/admin/orders', method: 'get', params })
}

// A14 订单详情（orderNo 为字符串主键，含 payment/stockLogs）
export function getOrderDetail(orderNo) {
  return request({ url: `/api/admin/orders/${encodeURIComponent(orderNo)}`, method: 'get' })
}

// A15 平台发货（仅 2→3；重复发货 PET-3002）
export function shipOrder(orderNo, data) {
  return request({ url: `/api/admin/orders/${encodeURIComponent(orderNo)}/ship`, method: 'put', data })
}
