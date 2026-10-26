/**
 * 商城枚举常量与通用工具
 *
 * 背景：数据库 `sys_dict_type/sys_dict_data` 没有商城枚举，一期统一使用本文件常量；
 * 二期补 `mall.*` 字典后可替换为 useDict。
 *
 * 取值来源：后端源码 / DDL / seed（详见设计文档 §6.3、附录 B），必须逐字一致并保留未知值兜底。
 */

/* ------------------------------ 枚举常量 ------------------------------ */

// 订单状态 0-8（B.1）
export const ORDER_STATUS = {
  0: { label: '待付款', type: 'warning' },
  1: { label: '待审核', type: 'primary' },
  2: { label: '待发货', type: 'primary' },
  3: { label: '待收货', type: 'success' },
  4: { label: '已完成', type: 'info' },
  5: { label: '已取消', type: 'info' },
  6: { label: '已关闭', type: 'info' },
  7: { label: '售后中', type: 'danger' },
  8: { label: '已退款', type: 'danger' }
}

// 商品审核状态（B.2）：0 待审核 / 1 已驳回 / 2 审核通过
export const AUDIT_STATUS = {
  0: { label: '待审核', type: 'warning' },
  1: { label: '已驳回', type: 'danger' },
  2: { label: '审核通过', type: 'success' }
}

// 商品上下架状态（B.2）：0 已下架 / 1 在售
export const ITEM_STATUS = {
  0: { label: '已下架', type: 'info' },
  1: { label: '在售', type: 'success' }
}

// SKU 状态
export const SKU_STATUS = {
  0: { label: '已停用', type: 'info' },
  1: { label: '启用', type: 'success' }
}

// 支付状态（B.3，兼容历史 FAIL 值）
export const PAY_STATUS = {
  SUCCESS: { label: '支付成功', type: 'success' },
  FAILED: { label: '支付失败', type: 'danger' },
  FAIL: { label: '支付失败', type: 'danger' },
  TIMEOUT: { label: '支付超时', type: 'info' },
  UNPAID: { label: '未支付', type: 'warning' }
}

// 支付渠道
export const PAY_CHANNEL = {
  WECHAT: '微信支付',
  ALIPAY: '支付宝',
  BALANCE: '余额支付'
}

// 库存流水类型：兼容运行时 ORDER_DEDUCT/ORDER_ROLLBACK/MANUAL、种子 ADJUST、DDL 注释 DEDUCT/ROLLBACK/ADJUST
export const STOCK_LOG_TYPE = {
  ORDER_DEDUCT: { label: '下单扣减', type: 'danger' },
  ORDER_ROLLBACK: { label: '取消回滚', type: 'success' },
  MANUAL: { label: '人工调整', type: 'warning' },
  ADJUST: { label: '初始/调整', type: 'warning' },
  DEDUCT: { label: '扣减', type: 'danger' },
  ROLLBACK: { label: '回滚', type: 'success' }
}

// 会员状态：0 正常 / 1 已禁用
export const MEMBER_STATUS = {
  0: { label: '正常', type: 'success' },
  1: { label: '已禁用', type: 'danger' }
}

// 适用宠物
export const PET_SPECIES = {
  CAT: '猫',
  DOG: '犬',
  SMALL: '小宠',
  ALL: '通用'
}

// 年龄阶段
export const AGE_STAGE = {
  JUNIOR: '幼年',
  ADULT: '成年',
  SENIOR: '老年',
  ALL: '通用'
}

// 类目适用宠物范围（空字符串/null 等同通用）
export const PET_SCOPE = {
  CAT: '猫',
  DOG: '犬',
  SMALL: '小宠',
  ALL: '通用',
  '': '通用'
}

// 若依操作日志业务类型（与 sys_oper_type 一致）
export const BUSINESS_TYPE = {
  0: '其它',
  1: '新增',
  2: '修改',
  3: '删除',
  4: '授权',
  5: '导出',
  6: '导入',
  7: '强退',
  8: '生成代码',
  9: '清空数据'
}

// 若依操作日志状态（与 sys_common_status 一致）
export const OPER_STATUS = {
  0: '正常',
  1: '异常'
}

// 常用物流公司（发货弹窗：可选可手输）
export const SHIP_COMPANIES = [
  '顺丰速运',
  '中通快递',
  '圆通速递',
  '韵达快递',
  '京东物流',
  'EMS',
  '极兔速递',
  '邮政快递包裹'
]

/* ------------------------------ 取值工具 ------------------------------ */

/**
 * 取枚举文案
 * @param {Object} dict 枚举常量对象（值可为 {label,type} 或字符串）
 * @param {*} value 原始值
 * @param {*} fallback 未命中时的兜底文案，默认 '-'
 */
export function dictLabel(dict, value, fallback = '-') {
  if (value === null || value === undefined || value === '') return fallback
  const item = dict?.[value]
  if (item && typeof item === 'object') return item.label ?? fallback
  if (typeof item === 'string') return item
  return fallback
}

/**
 * 取枚举标签颜色（Element Plus el-tag type）
 * @param {Object} dict 枚举常量对象
 * @param {*} value 原始值
 * @param {String} fallback 未命中时的颜色，默认 info
 */
export function dictType(dict, value, fallback = 'info') {
  const item = dict?.[value]
  if (item && typeof item === 'object') return item.type || fallback
  return fallback
}

/**
 * 枚举对象 → [{ value, label, type }]，供 el-select 的 options 使用
 * 数字键会转换为 Number，便于与后端整型字段比较
 */
export function optionsOf(dict) {
  if (!dict) return []
  return Object.keys(dict).map(key => {
    const item = dict[key]
    const value = /^\d+$/.test(key) ? Number(key) : key
    if (item && typeof item === 'object') {
      return { value, label: item.label, type: item.type }
    }
    return { value, label: String(item), type: 'info' }
  })
}

/* ------------------------------ 通用工具 ------------------------------ */

/** 金额展示：空值返回 '—'（与页面空值规范一致），其余保留两位小数 */
export function formatMoney(value) {
  if (value === null || value === undefined || value === '') return '—'
  const num = Number(value)
  if (Number.isNaN(num)) return '—'
  return num.toFixed(2)
}

/**
 * 解析 JSON 字符串快照（receiverSnapshot / petSnapshot 等）
 * 解析失败降级为 { raw: 原文 }，调用方展示 raw
 */
export function parseSnapshot(snapshot) {
  if (snapshot === null || snapshot === undefined || snapshot === '') return { raw: '' }
  if (typeof snapshot === 'object') return snapshot
  try {
    const parsed = JSON.parse(snapshot)
    return parsed && typeof parsed === 'object' ? parsed : { raw: String(snapshot) }
  } catch (e) {
    return { raw: String(snapshot) }
  }
}

/** 类目树 → { [id]: name } 映射（商品列表类目列使用） */
export function buildCategoryMap(tree) {
  const map = {}
  const walk = nodes => {
    if (!Array.isArray(nodes)) return
    nodes.forEach(node => {
      if (!node) return
      map[node.id] = node.name
      if (node.children && node.children.length) walk(node.children)
    })
  }
  walk(tree)
  return map
}

/**
 * 日期范围 → 后端顶层参数（禁止使用 addDateRange，它生成 params[beginTime] 与商城接口不匹配）
 * @param {Array} range [start, end]
 * @param {String} startKey 开始时间参数名
 * @param {String} endKey 结束时间参数名
 */
export function dateRangeToParams(range, startKey = 'startTime', endKey = 'endTime') {
  const params = { [startKey]: undefined, [endKey]: undefined }
  if (Array.isArray(range) && range.length === 2) {
    params[startKey] = range[0] || undefined
    params[endKey] = range[1] || undefined
  }
  return params
}

/** 复制文本到剪贴板（订单号/运单号） */
export function copyText(text) {
  const value = String(text ?? '')
  if (!value) return Promise.reject(new Error('empty'))
  if (navigator.clipboard && window.isSecureContext) {
    return navigator.clipboard.writeText(value)
  }
  return new Promise((resolve, reject) => {
    try {
      const textarea = document.createElement('textarea')
      textarea.value = value
      textarea.style.position = 'fixed'
      textarea.style.opacity = '0'
      document.body.appendChild(textarea)
      textarea.select()
      document.execCommand('copy')
      document.body.removeChild(textarea)
      resolve()
    } catch (e) {
      reject(e)
    }
  })
}

/** 手机号脱敏：13800138001 → 138****8001 */
export function maskPhone(phone) {
  if (!phone) return '-'
  const value = String(phone)
  if (value.includes('*')) return value
  if (value.length < 7) return value
  return value.replace(/^(\d{3})\d{4}(\d{4})$/, '$1****$2')
}

/** 姓名脱敏：张小明 → 张** */
export function maskName(name) {
  if (!name) return '-'
  const value = String(name)
  if (value.includes('*')) return value
  return value.slice(0, 1) + '*'.repeat(Math.max(value.length - 1, 1))
}
