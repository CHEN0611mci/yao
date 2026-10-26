import request from '../utils/request.js'
export const login = (data) => request({ url: '/api/member/login', method: 'post', data })
export const register = (data) => request({ url: '/api/member/register', method: 'post', data })
export const logout = () => request({ url: '/api/member/logout', method: 'post' })
export const me = () => request({ url: '/api/member/me' })
export const update = (data) => request({ url: '/api/member/me', method: 'put', data })
export const changePassword = (data) =>
  request({ url: '/api/member/password', method: 'put', data })
export const changePhone = (data) => request({ url: '/api/member/phone', method: 'put', data })
export const preferences = () => request({ url: '/api/member/preferences' })
export const savePreferences = (data) =>
  request({ url: '/api/member/preferences', method: 'put', data })
export const sessions = () => request({ url: '/api/member/sessions' })
export const revokeSession = (id) =>
  request({ url: `/api/member/sessions/${encodeURIComponent(id)}`, method: 'delete' })
export const revokeOthers = () =>
  request({ url: '/api/member/sessions/revoke-others', method: 'post' })
