<template>
  <div class="app-container">
    <el-alert type="info" :closable="false" show-icon class="mb8">
      <template #title>
        库存总览与库存流水接口均返回全量数据（无后端分页），数据量大时请用筛选缩小范围；当前总览
        <b>{{ overviewLoading ? '—' : overviewList.length }}</b> 条、流水
        <b>{{ logsLoaded ? logsList.length : '—' }}</b> 条。
      </template>
    </el-alert>

    <el-tabs v-model="activeTab" @tab-change="handleTabChange">
      <!-- ① 库存总览 -->
      <el-tab-pane label="库存总览" name="overview">
        <el-form :model="queryParams" ref="overviewQueryRef" :inline="true" v-show="showSearch">
          <el-form-item label="关键字" prop="keyword">
            <el-input
              v-model="queryParams.keyword"
              placeholder="商品标题 / SKU 编码"
              clearable
              style="width: 220px"
              @keyup.enter="handleOverviewQuery"
            />
          </el-form-item>
          <el-form-item label="商品ID" prop="itemId">
            <el-input-number
              v-model="queryParams.itemId"
              :min="1"
              :precision="0"
              :controls="false"
              placeholder="商品ID"
              style="width: 140px"
            />
          </el-form-item>
          <el-form-item label="商家ID" prop="merchantId">
            <el-input-number
              v-model="queryParams.merchantId"
              :min="1"
              :precision="0"
              :controls="false"
              placeholder="商家ID"
              style="width: 140px"
            />
          </el-form-item>
          <el-form-item label="仅看低库存" prop="lowStock">
            <el-switch v-model="queryParams.lowStock" />
          </el-form-item>
          <el-form-item label="低库存阈值" prop="threshold">
            <el-input-number
              v-model="queryParams.threshold"
              :min="0"
              :precision="0"
              :disabled="!queryParams.lowStock"
              controls-position="right"
              style="width: 120px"
            />
          </el-form-item>
          <el-form-item>
            <el-button type="primary" icon="Search" @click="handleOverviewQuery">搜索</el-button>
            <el-button icon="Refresh" @click="resetOverviewQuery">重置</el-button>
          </el-form-item>
        </el-form>

        <el-row :gutter="10" class="mb8">
          <el-col :span="1.5">
            <span class="total-tip">共 {{ overviewLoading ? '—' : overviewTotal }} 条（全量，无分页）</span>
          </el-col>
          <right-toolbar
            v-model:showSearch="showSearch"
            :columns="columns"
            storage-key="mall-stock"
            @queryTable="getOverview"
          />
        </el-row>

        <el-alert
          v-if="overviewError"
          title="库存总览加载失败"
          type="error"
          :closable="false"
          show-icon
          class="mb8"
        >
          <template #default>
            <el-button link type="primary" icon="Refresh" @click="getOverview">重试</el-button>
          </template>
        </el-alert>

        <el-table
          v-loading="overviewLoading"
          :data="overviewList"
          :row-class-name="overviewRowClassName"
          max-height="560"
        >
          <el-table-column v-if="columns.skuId.visible" label="SKU ID" prop="skuId" width="90" align="center" />
          <el-table-column v-if="columns.itemId.visible" label="商品ID" prop="itemId" width="90" align="center" />
          <el-table-column
            v-if="columns.title.visible"
            label="商品标题"
            prop="title"
            width="220"
            align="left"
            :show-overflow-tooltip="true"
          >
            <template #default="scope">
              <span>{{ scope.row.title || '—' }}</span>
            </template>
          </el-table-column>
          <el-table-column
            v-if="columns.specName.visible"
            label="规格"
            prop="specName"
            width="120"
            align="left"
            :show-overflow-tooltip="true"
          >
            <template #default="scope">
              <span>{{ scope.row.specName || '—' }}</span>
            </template>
          </el-table-column>
          <el-table-column
            v-if="columns.skuCode.visible"
            label="SKU 编码"
            prop="skuCode"
            width="170"
            align="left"
            :show-overflow-tooltip="true"
          >
            <template #default="scope">
              <span>{{ scope.row.skuCode || '—' }}</span>
            </template>
          </el-table-column>
          <el-table-column v-if="columns.price.visible" label="售价" width="100" align="right">
            <template #default="scope">
              <MallMoney :value="scope.row.price" />
            </template>
          </el-table-column>
          <el-table-column v-if="columns.stock.visible" label="库存" prop="stock" width="110" align="right">
            <template #default="scope">
              <span
                class="stock-value"
                :class="{ 'is-low': isLowStock(scope.row), 'is-out': Number(scope.row.stock) === 0 }"
              >{{ scope.row.stock === null || scope.row.stock === undefined ? 0 : scope.row.stock }}</span>
              <el-tag
                v-if="Number(scope.row.stock) === 0"
                type="danger"
                effect="dark"
                size="small"
                class="stock-out-tag"
                disable-transitions
              >缺货</el-tag>
            </template>
          </el-table-column>
          <el-table-column v-if="columns.skuStatus.visible" label="SKU 状态" width="100" align="center">
            <template #default="scope">
              <MallStatusTag :dict="SKU_STATUS" :value="scope.row.skuStatus" />
            </template>
          </el-table-column>
          <el-table-column v-if="columns.itemStatus.visible" label="商品状态" width="100" align="center">
            <template #default="scope">
              <MallStatusTag :dict="ITEM_STATUS" :value="scope.row.itemStatus" />
            </template>
          </el-table-column>
          <el-table-column v-if="columns.auditStatus.visible" label="审核状态" width="100" align="center">
            <template #default="scope">
              <MallStatusTag :dict="AUDIT_STATUS" :value="scope.row.auditStatus" />
            </template>
          </el-table-column>
          <el-table-column v-if="columns.merchantId.visible" label="商家ID" width="100" align="center">
            <template #default="scope">
              <span>{{ scope.row.merchantId === null || scope.row.merchantId === undefined ? '—' : '#' + scope.row.merchantId }}</span>
            </template>
          </el-table-column>
          <el-table-column
            v-if="columns.operation.visible"
            label="操作"
            width="160"
            align="center"
            class-name="small-padding fixed-width"
            fixed="right"
          >
            <template #default="scope">
              <el-button
                link
                type="primary"
                icon="Edit"
                @click="handleAdjust(scope.row)"
                v-hasPermi="['mall:stock:adjust']"
              >调整</el-button>
              <el-button link type="primary" icon="Tickets" @click="handleViewLogs(scope.row)">流水</el-button>
            </template>
          </el-table-column>
          <template #empty>
            <el-empty :image-size="80" description="暂无库存数据">
              <el-button link type="primary" @click="resetOverviewQuery">清空筛选条件</el-button>
            </el-empty>
          </template>
        </el-table>
      </el-tab-pane>

      <!-- ② 库存流水 -->
      <el-tab-pane label="库存流水" name="logs">
        <el-form :model="logParams" ref="logsQueryRef" :inline="true" v-show="showSearch">
          <el-form-item label="SKU ID" prop="skuId">
            <el-input-number
              v-model="logParams.skuId"
              :min="1"
              :precision="0"
              :controls="false"
              placeholder="SKU ID"
              style="width: 140px"
            />
          </el-form-item>
          <el-form-item label="订单号" prop="orderNo">
            <el-input
              v-model="logParams.orderNo"
              placeholder="订单号（精确匹配）"
              clearable
              style="width: 220px"
              @keyup.enter="handleLogsQuery"
            />
          </el-form-item>
          <el-form-item label="类型" prop="type">
            <el-select v-model="logParams.type" placeholder="请选择流水类型" clearable style="width: 160px">
              <el-option
                v-for="item in stockLogTypeOptions"
                :key="item.value"
                :label="item.label"
                :value="item.value"
              />
            </el-select>
          </el-form-item>
          <el-form-item>
            <el-button type="primary" icon="Search" @click="handleLogsQuery">搜索</el-button>
            <el-button icon="Refresh" @click="resetLogsQuery">重置</el-button>
          </el-form-item>
        </el-form>

        <el-row :gutter="10" class="mb8">
          <el-col :span="1.5">
            <span class="total-tip">共 {{ logsLoading ? '—' : logsTotal }} 条（全量，无分页）</span>
          </el-col>
          <right-toolbar
            v-model:showSearch="showSearch"
            :columns="logColumns"
            storage-key="mall-stock-logs"
            @queryTable="getLogs"
          />
        </el-row>

        <el-alert
          v-if="logsError"
          title="库存流水加载失败"
          type="error"
          :closable="false"
          show-icon
          class="mb8"
        >
          <template #default>
            <el-button link type="primary" icon="Refresh" @click="getLogs">重试</el-button>
          </template>
        </el-alert>

        <el-table v-loading="logsLoading" :data="logsList" max-height="520">
          <el-table-column v-if="logColumns.logId.visible" label="流水ID" prop="id" width="90" align="center" />
          <el-table-column v-if="logColumns.logSkuId.visible" label="SKU ID" prop="skuId" width="90" align="center" />
          <el-table-column
            v-if="logColumns.orderNo.visible"
            label="订单号"
            prop="orderNo"
            width="190"
            align="left"
            :show-overflow-tooltip="true"
          >
            <template #default="scope">
              <span>{{ scope.row.orderNo || '手工调整' }}</span>
            </template>
          </el-table-column>
          <el-table-column v-if="logColumns.logType.visible" label="类型" width="110" align="center">
            <template #default="scope">
              <el-tag :type="logTypeTag(scope.row.type)" size="small" disable-transitions>
                {{ logTypeLabel(scope.row.type) }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column v-if="logColumns.changeQty.visible" label="变更量" prop="changeQty" width="100" align="right">
            <template #default="scope">
              <span
                class="change-qty"
                :class="{
                  'is-add': Number(scope.row.changeQty) > 0,
                  'is-minus': Number(scope.row.changeQty) < 0
                }"
              >{{ formatChangeQty(scope.row.changeQty) }}</span>
            </template>
          </el-table-column>
          <el-table-column v-if="logColumns.logChange.visible" label="库存变化" width="140" align="center">
            <template #default="scope">
              <span>{{ scope.row.beforeQty }} → {{ scope.row.afterQty }}</span>
            </template>
          </el-table-column>
          <el-table-column v-if="logColumns.operator.visible" label="操作人" width="120" align="center">
            <template #default="scope">
              <span>{{ formatOperator(scope.row.operator) }}</span>
            </template>
          </el-table-column>
          <el-table-column
            v-if="logColumns.remark.visible"
            label="备注"
            prop="remark"
            width="200"
            align="left"
            :show-overflow-tooltip="true"
          >
            <template #default="scope">
              <span>{{ scope.row.remark || '—' }}</span>
            </template>
          </el-table-column>
          <el-table-column v-if="logColumns.createTime.visible" label="时间" width="160" align="center">
            <template #default="scope">
              <span>{{ parseTime(scope.row.createTime) }}</span>
            </template>
          </el-table-column>
          <template #empty>
            <el-empty :image-size="80" description="暂无库存流水" />
          </template>
        </el-table>
      </el-tab-pane>
    </el-tabs>

    <!-- 库存调整弹窗（复用公共组件，admin 端 merchant=false） -->
    <StockAdjustDialog
      v-model:visible="adjustOpen"
      :row="currentSku"
      :merchant="false"
      @adjusted="handleAdjusted"
    />
  </div>
</template>

<script setup name="Stock">
import { listStockOverview, listStockLogs } from '@/api/mall/stock'
import {
  STOCK_LOG_TYPE,
  SKU_STATUS,
  ITEM_STATUS,
  AUDIT_STATUS,
  optionsOf,
  dictLabel,
  dictType
} from '@/utils/mallDict'
import MallStatusTag from '@/components/mall/MallStatusTag.vue'
import MallMoney from '@/components/mall/MallMoney.vue'
import StockAdjustDialog from '@/components/mall/StockAdjustDialog.vue'

const { proxy } = getCurrentInstance()
const route = useRoute()
const router = useRouter()
const pagePath = route.path

const stockLogTypeOptions = optionsOf(STOCK_LOG_TYPE)

const showSearch = ref(true)
const activeTab = ref('overview')

const overviewLoading = ref(false)
const overviewError = ref(false)
const overviewList = ref([])
const logsLoading = ref(false)
const logsError = ref(false)
const logsLoaded = ref(false)
const logsList = ref([])

const adjustOpen = ref(false)
const currentSku = ref({})

const columns = ref({
  skuId: { label: 'SKU ID', visible: true },
  itemId: { label: '商品ID', visible: true },
  title: { label: '商品标题', visible: true },
  specName: { label: '规格', visible: true },
  skuCode: { label: 'SKU 编码', visible: true },
  price: { label: '售价', visible: true },
  stock: { label: '库存', visible: true },
  skuStatus: { label: 'SKU 状态', visible: true },
  itemStatus: { label: '商品状态', visible: true },
  auditStatus: { label: '审核状态', visible: true },
  merchantId: { label: '商家ID', visible: true },
  operation: { label: '操作', visible: true }
})

const logColumns = ref({
  logId: { label: '流水ID', visible: true },
  logSkuId: { label: 'SKU ID', visible: true },
  orderNo: { label: '订单号', visible: true },
  logType: { label: '类型', visible: true },
  changeQty: { label: '变更量', visible: true },
  logChange: { label: '库存变化', visible: true },
  operator: { label: '操作人', visible: true },
  remark: { label: '备注', visible: true },
  createTime: { label: '时间', visible: true }
})

/** URL query → 数字 */
function queryNumber(value) {
  if (value === undefined || value === null || value === '') return undefined
  const num = Number(value)
  return Number.isNaN(num) ? undefined : num
}

/** 去掉空串/null 参数，避免后端把空参数当作筛选条件 */
function cleanParams(source) {
  const params = {}
  Object.keys(source || {}).forEach(key => {
    const value = source[key]
    if (value === undefined || value === null || value === '') return
    params[key] = value
  })
  return params
}

/** 筛选状态（进页 / 同页 query 变化统一由 initQueryFromRoute 回填） */
const queryParams = reactive({
  keyword: undefined,
  itemId: undefined,
  merchantId: undefined,
  lowStock: false,
  threshold: 10
})
const logParams = reactive({
  skuId: undefined,
  orderNo: undefined,
  type: undefined
})

/**
 * 回填 URL query（stock 页 query 键：tab/keyword/itemId/merchantId/lowStock/threshold/logSkuId/logOrderNo/logType）
 * keep-alive 下再次从快捷入口跳到本页时也复用它，必须先整体重置再按 query 覆盖
 */
function initQueryFromRoute() {
  const query = route.query || {}
  queryParams.keyword = query.keyword ? String(query.keyword) : undefined
  queryParams.itemId = queryNumber(query.itemId)
  queryParams.merchantId = queryNumber(query.merchantId)
  queryParams.lowStock = query.lowStock === 'true' || query.lowStock === '1'
  const threshold = queryNumber(query.threshold)
  queryParams.threshold = threshold === undefined ? 10 : threshold
  logParams.skuId = queryNumber(query.logSkuId)
  logParams.orderNo = query.logOrderNo ? String(query.logOrderNo) : undefined
  logParams.type = query.logType ? String(query.logType) : undefined
  activeTab.value = query.tab === 'logs' ? 'logs' : 'overview'
  logsLoaded.value = false
}

const overviewTotal = computed(() => overviewList.value.length)
const logsTotal = computed(() => logsList.value.length)

/** 低库存阈值（lowStock 关闭时仍用于行高亮；空值回退后端默认 10） */
const thresholdValue = computed(() => {
  const raw = queryParams.threshold
  if (raw === null || raw === undefined || raw === '') return 10
  const num = Number(raw)
  return Number.isNaN(num) ? 10 : num
})

function isLowStock(row) {
  const stock = Number(row?.stock)
  if (Number.isNaN(stock)) return false
  return stock <= thresholdValue.value
}

/** 低库存标黄、缺货标红（行级提示；库存单元格另有红色加粗样式） */
function overviewRowClassName({ row }) {
  const stock = Number(row?.stock)
  if (stock === 0) return 'stock-row-out'
  if (!Number.isNaN(stock) && stock <= thresholdValue.value) return 'stock-row-low'
  return ''
}

/** 当前筛选 / tab 对应的 URL query（接口无分页，只同步筛选键与 tab） */
function currentQuery() {
  const query = { tab: activeTab.value }
  if (queryParams.keyword) query.keyword = queryParams.keyword
  if (queryParams.itemId !== undefined && queryParams.itemId !== null) query.itemId = String(queryParams.itemId)
  if (queryParams.merchantId !== undefined && queryParams.merchantId !== null) query.merchantId = String(queryParams.merchantId)
  if (queryParams.lowStock) query.lowStock = 'true'
  if (queryParams.threshold !== undefined && queryParams.threshold !== null && Number(queryParams.threshold) !== 10) {
    query.threshold = String(queryParams.threshold)
  }
  if (logParams.skuId !== undefined && logParams.skuId !== null) query.logSkuId = String(logParams.skuId)
  if (logParams.orderNo) query.logOrderNo = logParams.orderNo
  if (logParams.type) query.logType = logParams.type
  return query
}

/** 是否与当前筛选一致（String 归一化比较，避免自身写 URL 触发 watch 死循环） */
function isSameQuery(query, target) {
  const keys = Object.keys(query || {})
  if (keys.length !== Object.keys(target || {}).length) return false
  return keys.every(key => String(query[key]) === String(target[key]))
}

/** 筛选 / tab 同步到 URL（刷新保持） */
function syncUrl() {
  router.replace({ path: pagePath, query: currentQuery() }).catch(() => {})
}

/** 库存总览（A18，无分页 List<Map>） */
async function getOverview() {
  overviewLoading.value = true
  overviewError.value = false
  try {
    const res = await listStockOverview(cleanParams(queryParams))
    overviewList.value = Array.isArray(res) ? res : []
  } catch (e) {
    overviewList.value = []
    overviewError.value = true
  } finally {
    overviewLoading.value = false
  }
}

/** 库存流水（A19，无分页 List<PetStockLog>） */
async function getLogs() {
  logsLoading.value = true
  logsError.value = false
  try {
    const res = await listStockLogs(cleanParams(logParams))
    logsList.value = Array.isArray(res) ? res : []
    logsLoaded.value = true
  } catch (e) {
    logsList.value = []
    logsError.value = true
  } finally {
    logsLoading.value = false
  }
}

function handleOverviewQuery() {
  syncUrl()
  getOverview()
}

function resetOverviewQuery() {
  proxy.resetForm('overviewQueryRef')
  queryParams.keyword = undefined
  queryParams.itemId = undefined
  queryParams.merchantId = undefined
  queryParams.lowStock = false
  queryParams.threshold = 10
  syncUrl()
  getOverview()
}

function handleLogsQuery() {
  syncUrl()
  getLogs()
}

function resetLogsQuery() {
  proxy.resetForm('logsQueryRef')
  logParams.skuId = undefined
  logParams.orderNo = undefined
  logParams.type = undefined
  syncUrl()
  getLogs()
}

function handleTabChange(name) {
  activeTab.value = name
  syncUrl()
  if (name === 'logs' && !logsLoaded.value) {
    getLogs()
  }
}

/** 总览行 → 打开库存调整弹窗 */
function handleAdjust(row) {
  currentSku.value = row
  adjustOpen.value = true
}

/** 总览行 → 切到流水 tab 并按该 SKU 查询 */
function handleViewLogs(row) {
  logParams.skuId = row.skuId
  activeTab.value = 'logs'
  syncUrl()
  getLogs()
}

/**
 * 调整完成（成功 / PET-3001 库存不足 emit null）：
 * 重拉总览后按 skuId 把最新行回填给弹窗（弹窗保持打开时「当前库存 / 差异预览」与后端一致）；
 * 找不到该行时提示并关闭弹窗，避免继续展示过期库存；流水已加载则按当前条件同步重拉。
 */
async function handleAdjusted() {
  const skuId = currentSku.value?.skuId
  await getOverview()
  if (skuId !== undefined && skuId !== null) {
    const latest = overviewList.value.find(row => Number(row.skuId) === Number(skuId))
    if (latest) {
      currentSku.value = latest
    } else if (adjustOpen.value) {
      adjustOpen.value = false
      proxy.$modal.msgWarning('未找到该 SKU 的最新库存数据，请刷新后重试')
    }
  }
  if (logsLoaded.value) {
    getLogs()
  }
}

/** 流水类型：映射文案，未知值兜底原文 */
function logTypeLabel(type) {
  return dictLabel(STOCK_LOG_TYPE, type, type === null || type === undefined || type === '' ? '—' : String(type))
}

function logTypeTag(type) {
  return dictType(STOCK_LOG_TYPE, type, 'info')
}

function formatChangeQty(value) {
  const num = Number(value)
  if (value === null || value === undefined || Number.isNaN(num)) return '—'
  return num > 0 ? `+${num}` : String(num)
}

/** 操作人：system→系统、seed→初始化、其余原样 */
function formatOperator(operator) {
  if (operator === null || operator === undefined || operator === '') return '—'
  if (operator === 'system') return '系统'
  if (operator === 'seed') return '初始化'
  return String(operator)
}

// 同页 query 变化（如工作台「低库存」快捷入口再次跳 /mall/stock?lowStock=true）时重新回填并重查；
// keep-alive 下组件已存在、onMounted 不再触发，必须监听 route.fullPath，且用 isSameQuery 防止自身 syncUrl 死循环
watch(
  () => route.fullPath,
  () => {
    if (route.path !== pagePath) return
    if (isSameQuery(route.query, currentQuery())) return
    initQueryFromRoute()
    if (activeTab.value === 'logs') {
      getLogs()
    } else {
      getOverview()
    }
  }
)

// 先回填 URL query 再取数（初始化只执行一次）
initQueryFromRoute()
getOverview()
if (activeTab.value === 'logs') {
  getLogs()
}
</script>

<style scoped lang="scss">
.total-tip {
  color: var(--el-text-color-regular);
  font-size: 13px;
  line-height: 32px;
}

.stock-value.is-low {
  color: var(--el-color-danger);
  font-weight: 700;
}

.stock-value.is-out {
  color: var(--el-color-danger);
  font-weight: 700;
}

.stock-out-tag {
  margin-left: 6px;
}

.change-qty.is-add {
  color: var(--el-color-success);
  font-weight: 600;
}

.change-qty.is-minus {
  color: var(--el-color-danger);
  font-weight: 600;
}

:deep(.el-table__body tr.stock-row-low > td.el-table__cell) {
  background-color: var(--el-color-warning-light-9);
}

:deep(.el-table__body tr.stock-row-out > td.el-table__cell) {
  background-color: var(--el-color-danger-light-9);
}

:deep(.el-table__body tr.stock-row-low:hover > td.el-table__cell) {
  background-color: var(--el-color-warning-light-8);
}

:deep(.el-table__body tr.stock-row-out:hover > td.el-table__cell) {
  background-color: var(--el-color-danger-light-8);
}
</style>
