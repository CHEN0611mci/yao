import request from '../utils/request.js'
export const settings = () => request({ url: '/api/home/settings' })
export const feedback = (content) =>
  request({ url: '/api/member/feedback', method: 'post', data: { content } })
