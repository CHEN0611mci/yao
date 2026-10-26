import request from '@/utils/mallRequest'

// A16 会员列表（phone 已脱敏，不可逆，不要二次脱敏）
export function listMembers(params) {
  return request({ url: '/api/admin/members', method: 'get', params })
}

// A17 会员禁用/启用（status 0 正常 / 1 禁用；禁用立即失效会员 Token）
export function updateMemberStatus(id, status) {
  return request({ url: `/api/admin/members/${id}/status`, method: 'put', data: { status } })
}
