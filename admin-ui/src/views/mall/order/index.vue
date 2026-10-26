<template>
  <div class="app-container">
    <!-- 查询区 -->
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch" label-width="80px">
      <el-form-item label="订单号" prop="orderNo">
        <el-input
          v-model="queryParams.orderNo"
          placeholder="请输入订单号"
          clearable
          style="width: 240px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="会员ID" prop="memberId">
        <el-input-number
          v-model="queryParams.memberId"
          :min="1"
          :controls="false"
          placeholder="请输入会员ID"
          style="width: 160px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="商家ID" prop="merchantId">
        <el-input-number
          v-model="queryParams.merchantId"
          :min="1"
          :controls="false"
          placeholder="请输入商家ID"
          style="width: 160px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="订单状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择订单状态" clearable style="width: 200px">
          <el-option v-for="(item, key) in ORDER_STATUS" :key="key" :label="item.label" :value="Number(key)" />
        </el-select>
      </el-form-item>
      <el-form-item label="创建时间">
        <el-date-picker
          v-model="dateRange"
          type="datetimerange"
          value-format="YYYY-MM-DD HH:mm:ss"
          range-separator="-"
          start-placeholder="开始时间"
          end-placeholder="结束时间"
          :default-time="[new Date(2000, 1, 1, 0, 0, 0), new Date(2000, 1, 1, 23, 59, 59)]"
          style="width: 360px"
        />
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <!-- 操作栏 -->
    <el-row :gutter="10" class="mb8">
      <right-toolbar
        v-model:showSearch="showSearch"
        :columns="columns"
        storage-key="mall-order"
        @queryTable="getList"
      />
    </el-row>

    <!-- 数据区 -->
    <el-table v-loading="loading" :data="list">
      <el-table-column
        v-if="columns.orderNo.visible"
        label="订单号"
        prop="orderNo"
        width="190"
        align="left"
        :show-overflow-tooltip="true"
      >
        <template #default="scope">
          <el-button link type="primary" @click="handleDetail(scope.row)">{{ scope.row.orderNo }}</el-button>
        </template>
      </el-table-column>
      <el-table-column v-if="columns.memberId.visible" label="会员ID" prop="memberId" width="90" align="center">
        <template #default="scope">{{ scope.row.memberId ?? '—' }}</template>
      </el-table-column>
      <el-table-column v-if="columns.merchantId.visible" label="商家ID" prop="merchantId" width="100" align="center">
        <template #default="scope">
          {{ scope.row.merchantId != null ? `#${scope.row.merchantId}` : '—' }}
        </template>
      </el-table-column>
      <el-table-column
        v-if="columns.items.visible"
        label="商品明细"
        width="240"
        align="left"
        :show-overflow-tooltip="true"
      >
        <template #default="scope">{{ itemsSummary(scope.row) }}</template>
      </el-table-column>
      <el-table-column v-if="columns.payAmount.visible" label="应付金额" width="110" align="right">
        <template #default="scope"><mall-money :value="scope.row.payAmount" /></template>
      </el-table-column>
      <el-table-column v-if="columns.status.visible" label="状态" width="100" align="center">
        <template #default="scope">
          <mall-status-tag :dict="ORDER_STATUS" :value="scope.row.status" :fallback="scope.row.statusText" />
        </template>
      </el-table-column>
      <el-table-column v-if="columns.payTime.visible" label="支付时间" width="160" align="center">
        <template #default="scope">{{ textTime(scope.row.payTime) }}</template>
      </el-table-column>
      <el-table-column v-if="columns.shipTime.visible" label="发货时间" width="160" align="center">
        <template #default="scope">{{ textTime(scope.row.shipTime) }}</template>
      </el-table-column>
      <el-table-column v-if="columns.createTime.visible" label="创建时间" width="160" align="center">
        <template #default="scope">{{ textTime(scope.row.createTime) }}</template>
      </el-table-column>
      <el-table-column label="操作" width="150" align="center" fixed="right" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button link type="primary" icon="View" @click="handleDetail(scope.row)">详情</el-button>
          <el-button
            v-if="scope.row.status === 2"
            link
            type="primary"
            icon="Van"
            v-hasPermi="['mall:order:ship']"
            @click="handleShip(scope.row)"
          >发货</el-button>
        </template>
      </el-table-column>
      <template #empty>
        <el-empty v-if="error" description="订单列表加载失败" :image-size="80">
          <el-button type="primary" icon="Refresh" @click="getList">重试</el-button>
        </el-empty>
        <el-empty v-else :description="hasFilter ? '没有符合条件的订单' : '暂无订单'" :image-size="80">
          <el-button v-if="hasFilter" icon="Refresh" @click="resetQuery">重置筛选</el-button>
        </el-empty>
      </template>
    </el-table>

    <pagination
      v-show="total > 0"
      :total="total"
      v-model:page="queryParams.pageNum"
      v-model:limit="queryParams.pageSize"
      @pagination="handlePagination"
    />

    <!-- 详情抽屉 / 发货弹窗 -->
    <order-detail-drawer v-model:visible="detailOpen" :order-no="detailOrderNo" @failed="handleDetailFailed" />
    <ship-dialog v-model:visible="shipOpen" :order-no="shipOrderNo" @shipped="handleShipped" @failed="handleShipFailed" />
  </div>
</template>

<script setup name="Orders">
import { ORDER_STATUS } from '@/utils/mallDict'
import { listOrders } from '@/api/mall/order'
import MallStatusTag from '@/components/mall/MallStatusTag.vue'
import MallMoney from '@/components/mall/MallMoney.vue'
import OrderDetailDrawer from '@/components/mall/OrderDetailDrawer.vue'
import ShipDialog from '@/components/mall/ShipDialog.vue'

const { proxy } = getCurrentInstance()
const route = useRoute()
const router = useRouter()
const pagePath = route.path

const list = ref([])
const loading = ref(false)
const error = ref(false)
const total = ref(0)
const showSearch = ref(true)
const dateRange = ref([])

// 详情 / 发货状态
const detailOpen = ref(false)
const detailOrderNo = ref('')
const shipOpen = ref(false)
const shipOrderNo = ref('')

const queryParams = reactive({
  pageNum: 1,
  pageSize: 10,
  orderNo: undefined,
  memberId: undefined,
  merchantId: undefined,
  status: undefined
})

// 列显隐（storage-key="mall-order" 记忆）
const columns = ref({
  orderNo: { label: '订单号', visible: true },
  memberId: { label: '会员ID', visible: true },
  merchantId: { label: '商家ID', visible: true },
  items: { label: '商品明细', visible: true },
  payAmount: { label: '应付金额', visible: true },
  status: { label: '订单状态', visible: true },
  payTime: { label: '支付时间', visible: true },
  shipTime: { label: '发货时间', visible: true },
  createTime: { label: '创建时间', visible: true }
})

const hasFilter = computed(() => {
  return !!(
    queryParams.orderNo ||
    queryParams.memberId != null ||
    queryParams.merchantId != null ||
    queryParams.status != null ||
    (dateRange.value && dateRange.value.length === 2)
  )
})

/** 组装查询参数：日期必须是顶层 startTime/endTime（不走基座日期范围工具） */
function buildParams() {
  return {
    pageNum: queryParams.pageNum,
    pageSize: queryParams.pageSize,
    orderNo: queryParams.orderNo || undefined,
    memberId: queryParams.memberId ?? undefined,
    merchantId: queryParams.merchantId ?? undefined,
    status: queryParams.status ?? undefined,
    startTime: dateRange.value?.[0] || undefined,
    endTime: dateRange.value?.[1] || undefined
  }
}

/** 查询订单列表 */
async function getList() {
  loading.value = true
  error.value = false
  try {
    const res = await listOrders(buildParams())
    list.value = res?.list || []
    total.value = res?.total || 0
  } catch (e) {
    list.value = []
    total.value = 0
    error.value = true
  } finally {
    loading.value = false
  }
}

/** 搜索 */
function handleQuery() {
  queryParams.pageNum = 1
  syncQuery()
  getList()
}

/** 重置 */
function resetQuery() {
  dateRange.value = []
  proxy.resetForm('queryRef')
  queryParams.pageNum = 1
  queryParams.pageSize = 10
  syncQuery()
  getList()
}

/** 分页变化：同步 URL 后查询 */
function handlePagination() {
  syncQuery()
  getList()
}

/** 进页回填 URL query（含清空旧筛选，供路由 query 变化时复用） */
function initQueryFromRoute() {
  const query = route.query || {}
  queryParams.orderNo = query.orderNo ? String(query.orderNo) : undefined
  queryParams.memberId = toPositiveNumber(query.memberId)
  queryParams.merchantId = toPositiveNumber(query.merchantId)
  const status = toNumber(query.status)
  queryParams.status = status == null ? undefined : status
  dateRange.value = query.startTime && query.endTime ? [String(query.startTime), String(query.endTime)] : []
  queryParams.pageNum = toPositiveNumber(query.pageNum) ?? 1
  queryParams.pageSize = toPositiveNumber(query.pageSize) ?? 10
}

/** 当前筛选对应的 URL query */
function currentQuery() {
  const query = {}
  if (queryParams.orderNo) query.orderNo = queryParams.orderNo
  if (queryParams.memberId != null) query.memberId = String(queryParams.memberId)
  if (queryParams.merchantId != null) query.merchantId = String(queryParams.merchantId)
  if (queryParams.status != null) query.status = String(queryParams.status)
  if (dateRange.value?.[0]) query.startTime = dateRange.value[0]
  if (dateRange.value?.[1]) query.endTime = dateRange.value[1]
  query.pageNum = String(queryParams.pageNum)
  query.pageSize = String(queryParams.pageSize)
  return query
}

/** 筛选/分页同步到 URL（刷新保持） */
function syncQuery() {
  router.replace({ path: route.path, query: currentQuery() }).catch(() => {})
}

/** 是否与当前筛选一致（避免自身写 URL 触发重复查询） */
function isSameQuery(query, target) {
  const keys = Object.keys(query)
  if (keys.length !== Object.keys(target).length) return false
  return keys.every(key => String(query[key]) === String(target[key]))
}

function toNumber(value) {
  if (value == null || value === '') return null
  const num = Number(value)
  return Number.isNaN(num) ? null : num
}

function toPositiveNumber(value) {
  const num = toNumber(value)
  return num != null && num > 0 ? num : null
}

/** 商品明细摘要 */
function itemsSummary(row) {
  const items = row?.items || []
  if (!items.length) return '—'
  return items.map(item => `${item.title || '商品'}×${item.quantity ?? 1}`).join('；')
}

/** 时间展示 */
function textTime(value) {
  if (!value) return '—'
  return proxy.parseTime(value) || String(value)
}

/** 打开详情抽屉 */
function handleDetail(row) {
  detailOrderNo.value = row.orderNo
  detailOpen.value = true
}

/** 详情加载失败：订单不存在/越权时刷新列表 */
function handleDetailFailed(e) {
  if (e?.errorCode === 'PET-4003' || e?.errorCode === 'PET-2003') {
    getList()
  }
}

/** 打开发货弹窗 */
function handleShip(row) {
  shipOrderNo.value = row.orderNo
  shipOpen.value = true
}

/** 发货成功：刷新列表，抽屉打开则重拉详情 */
function handleShipped() {
  getList()
  refreshDetail()
}

/** 发货失败：状态已变化/订单不存在时强制刷新 */
function handleShipFailed(e) {
  if (e?.errorCode === 'PET-3002' || e?.errorCode === 'PET-4003' || e?.errorCode === 'PET-2003') {
    getList()
    refreshDetail()
  }
}

/** 抽屉打开时刷新详情 */
function refreshDetail() {
  if (!detailOpen.value) return
  detailOpen.value = false
  nextTick(() => {
    detailOpen.value = true
  })
}

// 同页 query 变化（如工作台「待发货」快捷入口跳转）时回填并重查
watch(
  () => route.fullPath,
  () => {
    if (route.path !== pagePath) return
    if (isSameQuery(route.query, currentQuery())) return
    initQueryFromRoute()
    getList()
  }
)

// 先回填 URL query 再取数（在 mounted 后执行，保证「重置」能回到空筛选）
onMounted(() => {
  initQueryFromRoute()
  getList()
})
</script>
