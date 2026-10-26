export const getToken = () => localStorage.getItem('member_token') || ''
export const setToken = (token) => localStorage.setItem('member_token', token)
export const clearToken = () => localStorage.removeItem('member_token')
export function safeRedirect(value, fallback = '/') {
  return typeof value === 'string' &&
    /^\/(?!\/)/.test(value) &&
    !/[\\\x00-\x1f]/.test(value) &&
    !/^\/(login|register)(?:[/?#]|$)/.test(value)
    ? value
    : fallback
}
