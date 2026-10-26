export function unwrap(body, status = 200, retryAfter = 0) {
  if (status >= 200 && status < 300 && (body?.code === 200 || body?.errorCode === 'PET-4001'))
    return body.data
  const message =
    body?.message ||
    body?.msg ||
    (status === 429 ? '请求频繁，请稍后重试' : '服务暂时不可用，请重试')
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
