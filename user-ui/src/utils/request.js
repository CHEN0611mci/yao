import axios from 'axios'
import { getToken, clearToken } from './auth.js'
import { unwrap } from './response.js'
const client = axios.create({ timeout: 20000 })
client.interceptors.request.use((config) => {
  // Keep the member token within the storefront API domain.
  if (!/^\/api\/(?:member|home|items|cart|checkout|orders|pay)(?:\/|$)/.test(config.url))
    throw new Error('不支持的商城接口')
  if (getToken()) config.headers.Authorization = `Bearer ${getToken()}`
  return config
})
export default async function request(config) {
  let response
  try {
    response = await client(config)
  } catch (error) {
    if (!error.response)
      throw new Error(
        error.code === 'ECONNABORTED' ? '请求超时，请重试' : '无法连接商城服务，请确认后端已启动',
      )
    response = error.response
  }
  try {
    return unwrap(response.data, response.status, response.headers['retry-after'])
  } catch (error) {
    const expired =
      error.errorCode === 'PET-2001' ||
      error.errorCode === 'PET-2004' ||
      (error.status === 401 && !config.url.endsWith('/login'))
    const sentToken = response.config?.headers?.Authorization
    if (expired && (!getToken() || sentToken === `Bearer ${getToken()}`)) {
      clearToken()
      window.dispatchEvent(new CustomEvent('member-expired', { detail: error.message }))
    }
    throw error
  }
}
