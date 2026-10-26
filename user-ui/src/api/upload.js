import request from '../utils/request.js'
export function image(file) {
  if (
    !['image/jpeg', 'image/png', 'image/webp'].includes(file.type) ||
    file.size > 10 * 1024 * 1024
  )
    throw new Error('请选择 10MB 以内的 JPG、PNG 或 WebP 图片')
  const data = new FormData()
  data.append('file', file)
  return request({ url: '/api/member/upload/image', method: 'post', data })
}
