import request from '../utils/request.js'
export const preview = (data) => request({ url: '/api/checkout/preview', method: 'post', data })
export const submit = (data) => request({ url: '/api/orders', method: 'post', data })
export const list = (params) => request({ url: '/api/orders', params })
export const detail = (no) => request({ url: `/api/orders/${encodeURIComponent(no)}` })
export const changeAddress = (no, addressId) =>
  request({
    url: `/api/orders/${encodeURIComponent(no)}/address`,
    method: 'put',
    data: { addressId },
  })
export const cancel = (no, reason) =>
  request({ url: `/api/orders/${encodeURIComponent(no)}/cancel`, method: 'post', data: { reason } })
export const confirm = (no) =>
  request({ url: `/api/orders/${encodeURIComponent(no)}/confirm`, method: 'post' })
