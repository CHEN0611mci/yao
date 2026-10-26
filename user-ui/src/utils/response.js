export function unwrap(body, status = 200, retryAfter = 0) {
  if (status >= 200 && status < 300 && (body?.code === 200 || body?.errorCode === 'PET-4001'))
    return body.data
  const message =
    body?.message ||
    body?.msg ||
    (typeof body === 'string' && /<!doctype|<html/i.test(body)
      ? '接口返回了网页，请检查后端代理配置，并使用项目启动脚本启动商城'
      : status === 429
        ? '请求频繁，请稍后重试'
        : status >= 500
          ? '商城后端未就绪，请运行 start-mall.bat 并检查 MySQL、Redis 与后端日志'
          : '服务响应异常，请重新加载')
  const error = new Error(
    `${message}${body?.errorCode ? ` · ${body.errorCode}` : ''}${body?.traceId ? ` · 追踪 ${body.traceId.slice(-6)}` : ''}`,
  )
  Object.assign(error, {
    status,
    errorCode: body?.errorCode,
    traceId: body?.traceId,
    retryAfter: Number(retryAfter) || 60,
    data: body?.data,
  })
  throw error
}
