import request from '../utils/request.js'
const base = '/api/member/messages'
export const list = (params) => request({ url: base, params })
export const unread = () => request({ url: `${base}/unread-count` })
export const read = (id) => request({ url: `${base}/${id}/read`, method: 'put' })
export const readAll = () => request({ url: `${base}/read-all`, method: 'put' })
