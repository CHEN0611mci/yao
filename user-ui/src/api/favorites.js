import request from '../utils/request.js'
const itemUrl = (id) => `/api/member/favorites/${encodeURIComponent(id)}`
export const list = (params) => request({ url: '/api/member/favorites', params })
export const contains = (id) => request({ url: itemUrl(id) })
export const add = (id) => request({ url: itemUrl(id), method: 'put' })
export const remove = (id) => request({ url: itemUrl(id), method: 'delete' })
