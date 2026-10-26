<template>
  <div class="app-container">
    <el-alert
      type="info"
      :closable="false"
      show-icon
      class="mb8"
      title="仅显示包含本人商品的订单；收货信息默认脱敏，发货核对时可临时查看完整信息，请勿截屏外传。"
    />

    <!-- 查询区（商家端只有订单号/状态两个有效筛选） -->
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
      <el-form-item label="订单状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择订单状态" clearable style="width: 200px">
          <el-option v-for="(item, key) in ORDER_STATUS" :key="key" :label="item.label" :value="Number(key)" />
        </el-select>
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
        storage-key="mall-merchant-order"
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
      <el-table-column v-if="columns.status.visible" label="状态" width="100" align="center">
        <template #default="scope">
          <mall-status-tag :dict="ORDER_STATUS" :value="scope.row.status" :fallback="scope.row.statusText" />
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
            v-hasPermi="['mall:merchant:order:ship']"
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

    <!-- 详情抽屉（脱敏模式）/ 发货弹窗（商家接口） -->
    <order-detail-drawer v-model:visible="detailOpen" :order-no="detailOrderNo" merchant @failed="handleDetailFailed" />
    <ship-dialog
      v-model:visible="shipOpen"
      :order-no="shipOrderNo"
      merchant
      @shipped="handleShipped"
      @failed="handleShipFailed"
    />
  </div>
</template>

<script setup name="MerchantOrders">
import { ORDER_STATUS } from '@/utils/mallDict'
import { listMyOrders } from '@/api/mall/merchant'
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

const detailOpen = ref(false)
const detailOrderNo = ref('')
const shipOpen = ref(false)
const shipOrderNo = ref('')

// 只保留后端支持的 orderNo/status，不传 memberId/日期（商家端无这些能力）
const queryParams = reactive({
  pageNum: 1,
  pageSize: 10,
  orderNo: undefined,
  status: undefined
})

const columns = ref({
  orderNo: { label: '订单号', visible: true },
  status: { label: '订单状态', visible: true },
  items: { label: '商品明细', visible: true },
  payAmount: { label: '应付金额', visible: true },
  payTime: { label: '支付时间', visible: true },
  shipTime: { label: '发货时间', visible: true },
  createTime: { label: '创建时间', visible: true }
})

const hasFilter = computed(() => !!(queryParams.orderNo || queryParams.status != null))

/** 组装查询参数 */
function buildParams() {
  return {
    pageNum: queryParams.pageNum,
    pageSize: queryParams.pageSize,
    orderNo: queryParams.orderNo || undefined,
    status: queryParams.status ?? undefined
  }
}

/** 查询我的订单 */
async function getList() {
  loading.value = true
  error.value = false
  try {
    const res = await listMyOrders(buildParams())
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
  proxy.resetForm('queryRef')
  queryParams.pageNum = 1
  queryParams.pageSize = 10
  syncQuery()
  getList()
}

/** 分页变化 */
function handlePagination() {
  syncQuery()
  getList()
}

/** 进页回填 URL query（含清空旧筛选，供路由 query 变化时复用） */
function initQueryFromRoute() {
  const query = route.query || {}
  queryParams.orderNo = query.orderNo ? String(query.orderNo) : undefined
  const status = toNumber(query.status)
  queryParams.status = status == null ? undefined : status
  queryParams.pageNum = toPositiveNumber(query.pageNum) ?? 1
  queryParams.pageSize = toPositiveNumber(query.pageSize) ?? 10
}

/** 当前筛选对应的 URL query */
function currentQuery() {
  const query = {}
  if (queryParams.orderNo) query.orderNo = queryParams.orderNo
  if (queryParams.status != null) query.status = String(queryParams.status)
  query.pageNum = String(queryParams.pageNum)
  query.pageSize = String(queryParams.pageSize)
  return query
}

/** 筛选/分页同步到 URL */
function syncQuery() {
  router.replace({ path: pagePath, query: currentQuery() }).catch(() => {})
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

/** 详情加载失败：越权/不存在时刷新列表 */
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

/** 发货失败：状态已变化/不存在/越权时强制刷新 */
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

// 同页 query 变化时回填并重查
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
