import request from '../utils/request.js'
export const login = (data) => request({ url: '/api/member/login', method: 'post', data })
export const register = (data) => request({ url: '/api/member/register', method: 'post', data })
export const logout = () => request({ url: '/api/member/logout', method: 'post' })
export const me = () => request({ url: '/api/member/me' })
export const update = (data) => request({ url: '/api/member/me', method: 'put', data })
export const changePassword = (data) =>
  request({ url: '/api/member/password', method: 'put', data })
