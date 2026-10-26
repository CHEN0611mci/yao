import request from '@/utils/mallRequest'

// A21 操作审计（只读；beginTime/endTime 为顶层参数，禁用 addDateRange）
export function listAuditLogs(params) {
  return request({ url: '/api/admin/audit-logs', method: 'get', params })
}
