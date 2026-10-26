/**
 * 商城专用请求层（管理端消费口径）
 *
 * 与若依 `@/utils/request` 的差异：
 *  - 商城统一响应为 `Result{code,message,data,traceId,errorCode}`，成功返回 `body.data`（不解包整个 body）
 *  - 商城业务失败为 HTTP 4xx/5xx + `Result`，需要从 `err.response.data` 读取 message/errorCode/traceId
 *  - 若依 @PreAuthorize 拒绝可能返回 HTTP 200 + `{code:403,msg}`
 *
 * 使用范围：仅 `/api/admin/**`、`/api/merchant/**`、`/api/upload/**`、`/api/home/**`
 * 若依接口（/login、/getInfo、/getRouters、/logout、/system/**）仍走 `@/utils/request`
 */
import axios from 'axios'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getToken } from '@/utils/auth'

const service = axios.create({
  baseURL: import.meta.env.VITE_APP_BASE_API,
  timeout: 15000
})

// 登录过期只弹一次，避免并发请求弹出多个框
let reloginShown = false

// 统一错误提示（同内容折叠，避免并发重复提示）
function notifyError(message) {
  ElMessage({
    message,
    type: 'error',
    duration: 5000,
    grouping: true,
    showClose: true
  })
}

// 失败文案：message + errorCode + traceId 后 6 位
function formatError(body) {
  const message = body?.message || body?.msg || '操作失败'
  const code = body?.errorCode ? `（${body.errorCode}）` : ''
  const trace = body?.traceId ? ` [${String(body.traceId).slice(-6)}]` : ''
  return `${message}${code}${trace}`
}

// 登录过期处理：清态并回到登录页（复用若依 user store）
function handleRelogin() {
  if (reloginShown) return
  reloginShown = true
  ElMessageBox.confirm('登录状态已过期，您可以继续留在该页面，或者重新登录', '系统提示', {
    confirmButtonText: '重新登录',
    cancelButtonText: '取消',
    type: 'warning'
  }).then(() => {
    import('@/store/modules/user').then(({ default: useUserStore }) => {
      Promise.resolve()
        .then(() => useUserStore().logOut())
        .catch(() => {})
        .finally(() => {
          import('@/utils/auth').then(({ removeToken }) => removeToken())
          location.href = '/index'
        })
    }).catch(() => {
      location.href = '/index'
    })
  }).catch(() => {
    reloginShown = false
  })
}

service.interceptors.request.use(
  config => {
    const token = getToken()
    if (token && config.headers) {
      config.headers['Authorization'] = 'Bearer ' + token
    }
    return config
  },
  error => Promise.reject(error)
)

service.interceptors.response.use(
  res => {
    // 二进制（上传回显/下载）不按 JSON 解包
    if (res.config?.responseType === 'blob' || res.config?.responseType === 'arraybuffer') {
      return res.data
    }
    const body = res.data
    // 非商城 Result（例如直接返回字符串），原样返回
    if (!body || typeof body !== 'object' || typeof body.code === 'undefined') {
      return body
    }
    // 成功：解包 data；4001 幂等重复按成功处理
    if (body.code === 200 || body.code === 4001) {
      return body.data
    }
    // HTTP 200 但业务码失败（兜底，商城通常是 HTTP 4xx）
    if (body.code === 401 || body.code === 2001) {
      handleRelogin()
      return Promise.reject(body)
    }
    if (body.code === 403 || body.code === 2003) {
      notifyError(body.message || body.msg || '没有权限，请联系管理员授权')
      return Promise.reject(body)
    }
    notifyError(formatError(body))
    return Promise.reject(body)
  },
  err => {
    const resp = err.response
    const body = resp?.data || {}
    const status = resp?.status

    // JWT 失效（若依链路 / 会员域错误码）
    if (status === 401 || body.code === 401 || body.code === 2001) {
      handleRelogin()
      return Promise.reject(body || err)
    }
    // 限流：按 Retry-After 提示
    if (status === 429 || body.code === 4290) {
      const retryAfter = Number(resp?.headers?.['retry-after'] || 3)
      ElMessage.warning(`操作过于频繁，请 ${Number.isFinite(retryAfter) ? retryAfter : 3} 秒后再试`)
      return Promise.reject(body || err)
    }
    // 越权 / 无权限
    if (status === 403 || body.code === 403 || body.code === 2003) {
      notifyError(body.message || body.msg || '无访问权限')
      return Promise.reject(body || err)
    }
    // 商城业务失败：message + PET-xxxx + traceId 后 6 位
    if (body.message || body.msg) {
      notifyError(formatError(body))
      return Promise.reject(body)
    }
    // 网络/超时/无 body
    if (err.message?.includes('timeout')) {
      notifyError('请求超时，请稍后重试')
    } else if (err.message === 'Network Error') {
      notifyError('后端接口连接异常，请检查服务是否启动')
    } else {
      notifyError(`系统接口${status || ''}异常，请稍后重试`)
    }
    return Promise.reject(err)
  }
)

export default service
