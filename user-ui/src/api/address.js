import request from '../utils/request.js'
const base = '/api/member/addresses'
export const list = () => request({ url: base })
export const detail = (id) => request({ url: `${base}/${id}` })
export const create = (data) => request({ url: base, method: 'post', data })
export const update = (id, data) => request({ url: `${base}/${id}`, method: 'put', data })
export const remove = (id) => request({ url: `${base}/${id}`, method: 'delete' })
export const setDefault = (id) => request({ url: `${base}/${id}/default`, method: 'put' })
