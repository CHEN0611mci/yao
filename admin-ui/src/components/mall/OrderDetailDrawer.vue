<template>
  <el-drawer
    v-model="drawerVisible"
    :title="drawerTitle"
    size="720px"
    direction="rtl"
    append-to-body
  >
    <div v-loading="loading" class="order-detail" element-loading-text="加载中...">
      <el-empty v-if="!loading && loadError" description="订单详情加载失败">
        <el-button type="primary" icon="Refresh" @click="loadDetail">重试</el-button>
      </el-empty>

      <template v-else-if="detail">
        <!-- 基本信息 -->
        <el-divider content-position="left">基本信息</el-divider>
        <el-descriptions :column="2" border>
          <el-descriptions-item label="订单号">{{ detail.orderNo || '—' }}</el-descriptions-item>
          <el-descriptions-item label="订单状态">
            <mall-status-tag :dict="ORDER_STATUS" :value="detail.status" :fallback="detail.statusText" />
          </el-descriptions-item>
          <el-descriptions-item label="会员ID">{{ memberIdText }}</el-descriptions-item>
          <el-descriptions-item v-if="!merchant" label="商家ID">
            {{ detail.merchantId != null ? `#${detail.merchantId}` : '—' }}
          </el-descriptions-item>
          <el-descriptions-item label="创建时间">{{ textTime(detail.createTime) }}</el-descriptions-item>
          <el-descriptions-item label="更新时间">{{ textTime(detail.updateTime) }}</el-descriptions-item>
          <el-descriptions-item label="备注" :span="2">{{ detail.remark || '—' }}</el-descriptions-item>
          <el-descriptions-item v-if="detail.cancelReason" label="取消原因" :span="2">
            {{ detail.cancelReason }}
          </el-descriptions-item>
        </el-descriptions>

        <!-- 金额明细 -->
        <el-divider content-position="left">金额明细</el-divider>
        <el-descriptions :column="2" border>
          <el-descriptions-item label="商品总额">
            <mall-money :value="detail.totalAmount" />
          </el-descriptions-item>
          <el-descriptions-item label="优惠金额">
            <mall-money :value="detail.discountAmount" />
          </el-descriptions-item>
          <el-descriptions-item label="运费">
            <mall-money :value="detail.freight" />
          </el-descriptions-item>
          <el-descriptions-item label="应付金额">
            <mall-money :value="detail.payAmount" bold />
          </el-descriptions-item>
        </el-descriptions>

        <!-- 收货与物流 -->
        <el-divider content-position="left">收货与物流</el-divider>
        <div class="receiver-toolbar">
          <el-button v-if="!receiverBroken && receiver.receiver" link type="primary" @click="toggleReceiver">
            {{ showFullReceiver ? '隐藏完整收货信息' : '显示完整收货信息' }}
          </el-button>
          <el-button v-if="!receiverBroken && receiver.receiver" link type="primary" @click="copyReceiver">
            复制收货信息
          </el-button>
        </div>
        <el-alert
          v-if="showFullReceiver"
          type="warning"
          :closable="false"
          show-icon
          title="请勿截屏外传"
          class="receiver-alert"
        />
        <el-alert
          v-if="receiverBroken"
          type="warning"
          :closable="false"
          show-icon
          title="收货信息格式异常，以下为原始内容"
          class="receiver-alert"
        />
        <el-descriptions :column="2" border>
          <template v-if="receiverBroken">
            <el-descriptions-item label="收货信息" :span="2">{{ receiverRaw }}</el-descriptions-item>
          </template>
          <template v-else>
            <el-descriptions-item label="收货人">{{ receiverName }}</el-descriptions-item>
            <el-descriptions-item label="手机号">{{ receiverPhone }}</el-descriptions-item>
            <el-descriptions-item label="省市区" :span="2">{{ receiverRegion }}</el-descriptions-item>
            <el-descriptions-item label="详细地址" :span="2">{{ receiverDetail }}</el-descriptions-item>
            <el-descriptions-item label="邮编">{{ receiverPostcode }}</el-descriptions-item>
          </template>
          <el-descriptions-item label="物流公司">
            {{ logistics.company || '未发货' }}
          </el-descriptions-item>
          <el-descriptions-item label="运单号">
            <template v-if="logistics.trackingNo">
              <span class="tracking-no">{{ logistics.trackingNo }}</span>
              <el-button link type="primary" @click="copyTrackingNo">复制</el-button>
            </template>
            <span v-else>—</span>
          </el-descriptions-item>
          <el-descriptions-item label="发货时间" :span="2">
            {{ textTime(logistics.shipTime) }}
          </el-descriptions-item>
        </el-descriptions>

        <!-- 商品明细 -->
        <el-divider content-position="left">商品明细</el-divider>
        <el-table :data="items" size="small" border>
          <el-table-column label="图片" width="70" align="center">
            <template #default="scope">
              <image-preview v-if="scope.row.image" :src="scope.row.image" width="50px" height="50px" />
              <span v-else>—</span>
            </template>
          </el-table-column>
          <el-table-column label="商品" prop="title" min-width="150" :show-overflow-tooltip="true">
            <template #default="scope">{{ scope.row.title || '—' }}</template>
          </el-table-column>
          <el-table-column label="规格" prop="spec" width="100" :show-overflow-tooltip="true">
            <template #default="scope">{{ scope.row.spec || '—' }}</template>
          </el-table-column>
          <el-table-column label="单价" width="90" align="right">
            <template #default="scope"><mall-money :value="scope.row.price" /></template>
          </el-table-column>
          <el-table-column label="数量" prop="quantity" width="70" align="center">
            <template #default="scope">{{ scope.row.quantity ?? '—' }}</template>
          </el-table-column>
          <el-table-column label="小计" width="100" align="right">
            <template #default="scope"><mall-money :value="scope.row.amount" /></template>
          </el-table-column>
          <el-table-column label="宠物" width="100" :show-overflow-tooltip="true">
            <template #default="scope">{{ petText(scope.row.petSnapshot) }}</template>
          </el-table-column>
          <template #empty>
            <span class="empty-text">—</span>
          </template>
        </el-table>

        <!-- 支付信息 -->
        <el-divider content-position="left">支付信息</el-divider>
        <el-descriptions v-if="payment" :column="2" border>
          <el-descriptions-item label="支付单号">{{ payment.paymentNo || '—' }}</el-descriptions-item>
          <el-descriptions-item label="支付渠道">{{ payChannelText }}</el-descriptions-item>
          <el-descriptions-item label="支付金额"><mall-money :value="payment.amount" /></el-descriptions-item>
          <el-descriptions-item label="支付状态">
            <mall-status-tag :dict="PAY_STATUS" :value="payment.status" :fallback="payment.status" />
          </el-descriptions-item>
          <el-descriptions-item label="回调时间">{{ textTime(payment.callbackTime) }}</el-descriptions-item>
          <el-descriptions-item label="创建时间">{{ textTime(payment.createTime) }}</el-descriptions-item>
        </el-descriptions>
        <div v-else class="empty-text">未支付</div>

        <!-- 库存流水 -->
        <el-divider content-position="left">库存流水</el-divider>
        <el-table v-if="stockLogs.length" :data="stockLogs" size="small" border>
          <el-table-column label="类型" width="110" align="center">
            <template #default="scope">
              <mall-status-tag :dict="STOCK_LOG_TYPE" :value="scope.row.type" :fallback="scope.row.type" />
            </template>
          </el-table-column>
          <el-table-column label="变动" width="80" align="center">
            <template #default="scope">
              <span :class="changeClass(scope.row.changeQty)">{{ formatChange(scope.row.changeQty) }}</span>
            </template>
          </el-table-column>
          <el-table-column label="变动前" prop="beforeQty" width="80" align="center">
            <template #default="scope">{{ scope.row.beforeQty ?? '—' }}</template>
          </el-table-column>
          <el-table-column label="变动后" prop="afterQty" width="80" align="center">
            <template #default="scope">{{ scope.row.afterQty ?? '—' }}</template>
          </el-table-column>
          <el-table-column label="操作人" width="100" align="center">
            <template #default="scope">{{ operatorText(scope.row.operator) }}</template>
          </el-table-column>
          <el-table-column label="备注" prop="remark" min-width="110" :show-overflow-tooltip="true">
            <template #default="scope">{{ scope.row.remark || '—' }}</template>
          </el-table-column>
          <el-table-column label="时间" width="160" align="center">
            <template #default="scope">{{ textTime(scope.row.createTime) }}</template>
          </el-table-column>
        </el-table>
        <div v-else class="empty-text">无库存流水</div>

        <!-- 状态时间线 -->
        <el-divider content-position="left">状态时间线</el-divider>
        <el-timeline>
          <el-timeline-item
            v-for="node in timeline"
            :key="node.key"
            :timestamp="node.time ? textTime(node.time) : '未发生'"
            :type="node.time ? 'primary' : 'info'"
            :hollow="!node.time"
            :class="{ 'timeline-inactive': !node.time }"
          >
            {{ node.label }}
          </el-timeline-item>
        </el-timeline>
      </template>
    </div>
  </el-drawer>
</template>

<script setup>
import {
  ORDER_STATUS,
  PAY_STATUS,
  PAY_CHANNEL,
  STOCK_LOG_TYPE,
  parseSnapshot,
  maskPhone,
  maskName,
  copyText
} from '@/utils/mallDict'
import { getOrderDetail } from '@/api/mall/order'
import { getMyOrder } from '@/api/mall/merchant'
import MallStatusTag from '@/components/mall/MallStatusTag.vue'
import MallMoney from '@/components/mall/MallMoney.vue'

const props = defineProps({
  /* 是否显示抽屉 */
  visible: {
    type: Boolean,
    default: false
  },
  /* 订单号（字符串主键） */
  orderNo: {
    type: String,
    default: ''
  },
  /* 是否商家端（走 /api/merchant/orders/{orderNo}，收货信息更严格脱敏） */
  merchant: {
    type: Boolean,
    default: false
  }
})

const emit = defineEmits(['update:visible', 'failed'])

const { proxy } = getCurrentInstance()

const loading = ref(false)
const loadError = ref(false)
const detail = ref(null)
const showFullReceiver = ref(false)

const drawerVisible = computed({
  get: () => props.visible,
  set: value => emit('update:visible', value)
})

const drawerTitle = computed(() => (props.orderNo ? `订单详情 · ${props.orderNo}` : '订单详情'))

const items = computed(() => detail.value?.items || [])
const stockLogs = computed(() => detail.value?.stockLogs || [])
const payment = computed(() => detail.value?.payment || null)

const payChannelText = computed(() => {
  const channel = payment.value?.channel
  if (!channel) return '—'
  return PAY_CHANNEL[channel] || channel
})

// 收货快照是 JSON 字符串；解析失败降级原文，不阻断详情其余分区
const receiverInfo = computed(() => {
  const raw = detail.value?.receiverSnapshot
  if (!raw) return { data: null, raw: '', broken: false }
  const parsed = parseSnapshot(raw)
  if (parsed && typeof parsed === 'object' && !('raw' in parsed)) {
    return { data: parsed, raw: '', broken: false }
  }
  const fallback = parsed && typeof parsed === 'object' ? parsed.raw : parsed
  return { data: null, raw: String(fallback ?? raw), broken: true }
})

const receiver = computed(() => receiverInfo.value.data || {})
const receiverBroken = computed(() => receiverInfo.value.broken)
const receiverRaw = computed(() => receiverInfo.value.raw || '—')
const logistics = computed(() => receiver.value.logistics || {})

const receiverName = computed(() => {
  const value = receiver.value.receiver
  if (!value) return '—'
  return showFullReceiver.value ? value : maskName(value)
})

const receiverPhone = computed(() => {
  const value = receiver.value.phone
  if (!value) return '—'
  return showFullReceiver.value ? value : maskPhone(value)
})

const receiverRegion = computed(() => {
  const region = [receiver.value.province, receiver.value.city, receiver.value.district].filter(Boolean).join(' ')
  return region || '—'
})

const receiverDetail = computed(() => {
  const value = receiver.value.detail
  if (!value) return '—'
  return showFullReceiver.value ? value : '******'
})

const receiverPostcode = computed(() => {
  const value = receiver.value.postcode
  if (!value) return '—'
  return showFullReceiver.value ? value : '******'
})

const memberIdText = computed(() => {
  const value = detail.value?.memberId
  if (value == null) return '—'
  return props.merchant ? maskId(value) : String(value)
})

const timeline = computed(() => [
  { key: 'create', label: '创建订单', time: detail.value?.createTime },
  { key: 'pay', label: '支付', time: detail.value?.payTime },
  { key: 'ship', label: '发货', time: detail.value?.shipTime },
  { key: 'receive', label: '确认收货', time: detail.value?.receiveTime },
  { key: 'close', label: '关闭', time: detail.value?.closeTime }
])

watch(
  () => [props.visible, props.orderNo],
  ([visible]) => {
    if (visible && props.orderNo) {
      showFullReceiver.value = false
      loadDetail()
    }
  },
  { immediate: true }
)

/** 拉取订单详情（商家/管理端接口二选一） */
async function loadDetail() {
  if (!props.orderNo) return
  loading.value = true
  loadError.value = false
  try {
    const data = props.merchant ? await getMyOrder(props.orderNo) : await getOrderDetail(props.orderNo)
    detail.value = data || null
    if (!detail.value) loadError.value = true
  } catch (e) {
    detail.value = null
    loadError.value = true
    // 订单不存在/越权：关闭抽屉，由页面刷新列表
    if (e?.errorCode === 'PET-4003' || e?.errorCode === 'PET-2003') {
      emit('update:visible', false)
    }
    emit('failed', e)
  } finally {
    loading.value = false
  }
}

/** 时间展示，空值统一 — */
function textTime(value) {
  if (!value) return '—'
  return proxy.parseTime(value) || String(value)
}

/** 明细宠物快照：可能为 JSON 或纯文本，解析失败展示原文 */
function petText(value) {
  if (value == null || value === '') return '—'
  const parsed = parseSnapshot(value)
  if (!parsed) return String(value)
  if (typeof parsed === 'string') return parsed
  if ('raw' in parsed && Object.keys(parsed).length === 1) {
    return parsed.raw == null || parsed.raw === '' ? '—' : String(parsed.raw)
  }
  return parsed.name || parsed.petName || parsed.title || String(value)
}

/** 商家端会员 ID 中段脱敏 */
function maskId(id) {
  const text = String(id)
  if (text.length <= 2) return '*'.repeat(text.length)
  if (text.length <= 4) return `${text.slice(0, 1)}${'*'.repeat(text.length - 2)}${text.slice(-1)}`
  return `${text.slice(0, 2)}${'*'.repeat(text.length - 4)}${text.slice(-2)}`
}

/** 收货信息展示切换（仅前端展示，不改接口数据） */
function toggleReceiver() {
  showFullReceiver.value = !showFullReceiver.value
}

/** 复制完整收货信息（发货核对用） */
function copyReceiver() {
  const info = receiver.value
  if (!info || !info.receiver) {
    proxy.$modal.msgWarning('暂无可复制的收货信息')
    return
  }
  const address = [info.province, info.city, info.district, info.detail].filter(Boolean).join('')
  const lines = [
    `收货人：${info.receiver}`,
    `手机号：${info.phone || ''}`,
    `地址：${address}`,
    info.postcode ? `邮编：${info.postcode}` : ''
  ].filter(Boolean)
  Promise.resolve(copyText(lines.join('\n')))
    .then(() => proxy.$modal.msgSuccess('收货信息已复制'))
    .catch(() => proxy.$modal.msgWarning('复制失败，请手动选择复制'))
}

/** 复制运单号 */
function copyTrackingNo() {
  const trackingNo = logistics.value.trackingNo
  if (!trackingNo) return
  Promise.resolve(copyText(trackingNo))
    .then(() => proxy.$modal.msgSuccess('运单号已复制'))
    .catch(() => proxy.$modal.msgWarning('复制失败，请手动选择复制'))
}

/** 库存流水变动值展示 */
function formatChange(value) {
  if (value == null || value === '') return '—'
  return Number(value) > 0 ? `+${value}` : String(value)
}

function changeClass(value) {
  const num = Number(value)
  if (num > 0) return 'stock-in'
  if (num < 0) return 'stock-out'
  return ''
}

/** 流水操作人：系统账号显示「系统」 */
function operatorText(value) {
  if (!value) return '—'
  return value === 'system' ? '系统' : value
}
</script>

<style lang="scss" scoped>
.order-detail {
  min-height: 200px;
  padding-bottom: 12px;
}
.receiver-toolbar {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}
.receiver-alert {
  margin-bottom: 8px;
}
.empty-text {
  color: #909399;
  font-size: 13px;
  padding: 6px 0;
}
.tracking-no {
  margin-right: 8px;
}
.stock-in {
  color: #67c23a;
}
.stock-out {
  color: #f56c6c;
}
:deep(.timeline-inactive) {
  color: #c0c4cc;
}
</style>
