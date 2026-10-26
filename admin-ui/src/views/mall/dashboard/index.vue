<template>
  <div class="app-container">
    <!-- 标题与刷新 -->
    <el-row :gutter="10" class="mb8 dashboard-header" align="middle">
      <el-col :span="12">
        <div class="dashboard-title">今日概览</div>
      </el-col>
      <el-col :span="12" class="dashboard-actions">
        <el-button icon="Refresh" :loading="loading" @click="getSummary">刷新</el-button>
      </el-col>
    </el-row>

    <!-- 指标卡（加载中骨架屏；失败显示错误态 + 重试） -->
    <el-row v-if="!error" :gutter="16" class="metric-row">
      <el-col v-for="card in cards" :key="card.key" :xs="24" :sm="12" :md="8" :lg="4">
        <el-card shadow="hover" class="metric-card">
          <el-skeleton v-if="loading" :rows="2" animated />
          <template v-else>
            <div class="metric-label">
              <el-icon class="metric-icon"><component :is="card.icon" /></el-icon>
              <span>{{ card.label }}</span>
            </div>
            <div class="metric-value">
              <mall-money v-if="card.key === 'todaySales'" :value="metricNumber('todaySales')" />
              <template v-else-if="card.key === 'lowStockSku'">{{ lowStockText }}</template>
              <template v-else>{{ metricNumber(card.key) }}</template>
            </div>
          </template>
        </el-card>
      </el-col>
    </el-row>
    <el-card v-else shadow="never" class="error-card">
      <el-empty description="概览加载失败">
        <el-button type="primary" icon="Refresh" @click="getSummary">重试</el-button>
      </el-empty>
    </el-card>

    <!-- 快捷入口 / 运维任务 -->
    <el-row :gutter="16" class="panel-row">
      <el-col :xs="24" :md="14">
        <el-card shadow="never" class="panel-card">
          <template #header>
            <div class="panel-title">快捷入口</div>
          </template>
          <div class="quick-links">
            <el-button
              v-if="can('mall:order:list')"
              type="primary"
              plain
              icon="Van"
              @click="go('/mall/orders', { status: 2 })"
            >待发货订单</el-button>
            <el-button
              v-if="can('mall:item:audit')"
              type="warning"
              plain
              icon="Stamp"
              @click="go('/mall/audit', { auditStatus: 0 })"
            >待审商品</el-button>
            <el-button
              v-if="can('mall:stock:list')"
              type="danger"
              plain
              icon="Warning"
              @click="go('/mall/stock', { lowStock: true })"
            >低库存</el-button>
            <el-button v-if="can('mall:member:list')" type="success" plain icon="User" @click="go('/mall/members')">
              会员列表
            </el-button>
            <el-button v-if="can('mall:item:list')" plain icon="Goods" @click="go('/mall/items')">商品管理</el-button>
          </div>
        </el-card>
      </el-col>
      <el-col v-if="showJobPanel" :xs="24" :md="10">
        <el-card shadow="never" class="panel-card">
          <template #header>
            <div class="panel-title">运维任务</div>
          </template>
          <div class="job-actions">
            <el-button
              type="primary"
              plain
              icon="Clock"
              v-hasPermi="['mall:job:trigger']"
              :loading="jobLoading.close"
              :disabled="jobLoading.confirm"
              @click="handleCloseTimeout"
            >手动超时关单</el-button>
            <el-button
              type="warning"
              plain
              icon="CircleCheck"
              v-hasPermi="['mall:job:trigger']"
              :loading="jobLoading.confirm"
              :disabled="jobLoading.close"
              @click="handleAutoConfirm"
            >手动自动确认收货</el-button>
          </div>
          <div class="job-tip">仅开发/测试环境可用；执行成功后自动刷新上方指标。</div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup name="Dashboard">
import MallMoney from '@/components/mall/MallMoney.vue'
import { getDashboardSummary, triggerCloseTimeoutOrders, triggerAutoConfirmOrders } from '@/api/mall/dashboard'

const { proxy } = getCurrentInstance()
const router = useRouter()

const loading = ref(false)
const error = ref(false)
const summary = ref({})
const jobLoading = reactive({ close: false, confirm: false })

const cards = [
  { key: 'todayOrders', label: '今日订单数', icon: 'Tickets' },
  { key: 'todaySales', label: '今日销售额', icon: 'Money' },
  { key: 'pendingShipment', label: '待发货', icon: 'Van' },
  { key: 'lowStockSku', label: '低库存 SKU', icon: 'Warning' },
  { key: 'totalMembers', label: '会员总数', icon: 'User' }
]

// 运维任务仅 dev/test 且具备 mall:job:trigger 时渲染
const showJobPanel = computed(() => {
  return import.meta.env.VITE_APP_ENV !== 'production' && proxy.$auth.hasPermi('mall:job:trigger')
})

const lowStockText = computed(() => {
  const num = Number(summary.value?.lowStockSku ?? 0)
  return num >= 1000 ? '1000+' : String(num)
})

/** 权限判断（快捷入口按权限渲染） */
function can(permission) {
  return proxy.$auth.hasPermi(permission)
}

/** 指标数值，空值按 0 展示 */
function metricNumber(key) {
  const value = summary.value?.[key]
  return value == null ? 0 : value
}

/** 工作台概览（单请求） */
async function getSummary() {
  loading.value = true
  error.value = false
  try {
    const data = await getDashboardSummary()
    summary.value = data || {}
  } catch (e) {
    summary.value = {}
    error.value = true
  } finally {
    loading.value = false
  }
}

/** 快捷入口跳转（query 与目标页筛选参数同名） */
function go(path, query = {}) {
  router.push({ path, query })
}

/** 手动超时关单 */
async function handleCloseTimeout() {
  if (jobLoading.close || jobLoading.confirm) return
  const confirmed = await proxy.$modal
    .confirm('将关闭超时待付款订单并回滚库存，确认执行？')
    .then(() => true)
    .catch(() => false)
  if (!confirmed) return
  jobLoading.close = true
  try {
    const res = await triggerCloseTimeoutOrders()
    const closed = Number(res?.closed ?? 0)
    if (closed > 0) {
      proxy.$modal.msgSuccess(`${closed} 笔订单已关闭`)
    } else {
      proxy.$modal.msgWarning('本次没有满足条件的超时待付款订单')
    }
    await getSummary()
  } catch (e) {
    // 错误文案由请求层统一提示；失败不刷新，可再次点击重试
  } finally {
    jobLoading.close = false
  }
}

/** 手动自动确认收货 */
async function handleAutoConfirm() {
  if (jobLoading.confirm || jobLoading.close) return
  const confirmed = await proxy.$modal
    .confirm('将发货超期订单置为已完成，确认执行？')
    .then(() => true)
    .catch(() => false)
  if (!confirmed) return
  jobLoading.confirm = true
  try {
    const res = await triggerAutoConfirmOrders()
    const count = Number(res?.confirmed ?? 0)
    if (count > 0) {
      proxy.$modal.msgSuccess(`${count} 笔订单已自动确认`)
    } else {
      proxy.$modal.msgWarning('本次没有满足条件的待收货订单')
    }
    await getSummary()
  } catch (e) {
    // 错误文案由请求层统一提示；失败不刷新，可再次点击重试
  } finally {
    jobLoading.confirm = false
  }
}

// 切回工作台（keep-alive 激活）时重拉指标；首次激活与初始加载重复，跳过一次
let activatedOnce = false
onActivated(() => {
  if (!activatedOnce) {
    activatedOnce = true
    return
  }
  getSummary()
})

getSummary()
</script>

<style lang="scss" scoped>
.dashboard-header {
  padding-bottom: 4px;
}
.dashboard-title {
  font-size: 18px;
  font-weight: 600;
  color: #303133;
}
.dashboard-actions {
  text-align: right;
}
.metric-row {
  margin-bottom: 8px;
}
.metric-card {
  margin-bottom: 16px;
  min-height: 112px;
}
.metric-label {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  color: #909399;
  margin-bottom: 12px;
}
.metric-icon {
  font-size: 16px;
  color: #409eff;
}
.metric-value {
  font-size: 24px;
  font-weight: 600;
  color: #303133;
  line-height: 1.2;
}
.error-card {
  margin-bottom: 16px;
}
.panel-row {
  margin-top: 8px;
}
.panel-card {
  margin-bottom: 16px;
  min-height: 180px;
}
.panel-title {
  font-size: 15px;
  font-weight: 600;
  color: #303133;
}
.quick-links {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}
.quick-links .el-button {
  margin-left: 0;
}
.job-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-bottom: 10px;
}
.job-actions .el-button {
  margin-left: 0;
}
.job-tip {
  font-size: 12px;
  color: #909399;
}
</style>
