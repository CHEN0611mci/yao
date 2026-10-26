import request from '../utils/request.js'
export const mock = (data, key) =>
  request({ url: '/api/pay/mock', method: 'post', data, headers: { 'Idempotency-Key': key } })
export const query = (no) => request({ url: `/api/pay/${encodeURIComponent(no)}` })
