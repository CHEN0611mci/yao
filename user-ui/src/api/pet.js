import request from '../utils/request.js'
const base = '/api/member/pets'
export const list = (includeArchived = false) => request({ url: base, params: { includeArchived } })
export const detail = (id) => request({ url: `${base}/${id}` })
export const create = (data) => request({ url: base, method: 'post', data })
export const update = (id, data) => request({ url: `${base}/${id}`, method: 'put', data })
export const archive = (id) => request({ url: `${base}/${id}`, method: 'delete' })
