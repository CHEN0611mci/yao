import request from '@/utils/mallRequest'

// A1 工作台概览
export function getDashboardSummary() {
  return request({ url: '/api/admin/dashboard/summary', method: 'get' })
}

// A22 手动超时关单（补偿任务）
export function triggerCloseTimeoutOrders() {
  return request({ url: '/api/admin/jobs/close-timeout-orders', method: 'post' })
}

// A23 手动自动确认收货（补偿任务）
export function triggerAutoConfirmOrders() {
  return request({ url: '/api/admin/jobs/auto-confirm-orders', method: 'post' })
}
