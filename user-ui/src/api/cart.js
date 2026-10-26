import request from '../utils/request.js'
export const list = () => request({ url: '/api/cart' })
export const add = (data) => request({ url: '/api/cart/items', method: 'post', data })
export const update = (id, data) => request({ url: `/api/cart/items/${id}`, method: 'put', data })
export const remove = (id) => request({ url: `/api/cart/items/${id}`, method: 'delete' })
