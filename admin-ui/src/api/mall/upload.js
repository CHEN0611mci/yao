import request from '@/utils/mallRequest'

// A24 图片上传（登录即可，无权限码；字段名 file；响应 data={url,fileName,newFileName,originalFilename}）
export function uploadImage(file) {
  const formData = new FormData()
  formData.append('file', file)
  return request({
    url: '/api/upload/image',
    method: 'post',
    data: formData,
    timeout: 60000
  })
}
