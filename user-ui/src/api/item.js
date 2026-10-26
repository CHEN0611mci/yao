import request from '../utils/request.js'
export const categories = () => request({ url: '/api/home/categories' })
export const recommend = (limit = 10) => request({ url: '/api/home/recommend', params: { limit } })
export const list = (params) => request({ url: '/api/items', params })
export const detail = (id) => request({ url: `/api/items/${encodeURIComponent(id)}` })
