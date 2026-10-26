<template>
  <div class="app-container">
    <!-- 后果提示常驻（§5.4.2、§5.1.9 硬规则 2/3） -->
    <el-alert type="info" :closable="false" show-icon class="mb8">
      <template #title>
        审核通过 ≠ 自动上架：通过后仍需到「商品管理」页手动上架；驳回将同时强制下架该商品。审核结果会写入商品审核留痕（pet_item_audit）。
      </template>
    </el-alert>

    <!-- 查询区：默认待审队列（auditStatus=0），本页不做 status/merchantId 筛选 -->
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch" label-width="88px">
      <el-form-item label="关键字" prop="keyword">
        <el-input
          v-model="queryParams.keyword"
          placeholder="商品标题 / 品牌"
          clearable
          style="width: 220px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="类目" prop="categoryId">
        <category-tree-select
          v-model="queryParams.categoryId"
          :categories="categories"
          :only-leaf="false"
          placeholder="全部类目"
          style="width: 220px"
        />
      </el-form-item>
      <el-form-item label="审核状态" prop="auditStatus">
        <el-select v-model="queryParams.auditStatus" placeholder="审核状态" style="width: 180px">
          <el-option v-for="item in auditStatusOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <!-- 操作栏：无新增/批量（§5.4.5） -->
    <el-row :gutter="10" class="mb8">
      <right-toolbar
        v-model:showSearch="showSearch"
        :columns="columns"
        storage-key="mall-audit"
        @queryTable="getList"
      />
    </el-row>

    <el-alert v-if="loadFailed" type="error" :closable="false" show-icon class="mb8">
      <template #title>
        待审列表加载失败
        <el-button link type="primary" @click="getList">重试</el-button>
      </template>
    </el-alert>

    <!-- 数据区：审核状态与上下架分两列两标签 -->
    <el-table v-loading="loading" :data="list" border>
      <el-table-column v-if="columns.mainImage.visible" label="主图" width="90" align="center">
        <template #default="scope">
          <image-preview v-if="scope.row.mainImage" :src="scope.row.mainImage" width="50px" height="50px" />
          <span v-else>—</span>
        </template>
      </el-table-column>
      <el-table-column v-if="columns.id.visible" label="商品ID" prop="id" width="80" align="center" />
      <el-table-column v-if="columns.title.visible" label="商品标题" min-width="220" show-overflow-tooltip>
        <template #default="scope">
          <el-link type="primary" :underline="false" @click="handleView(scope.row)">{{ scope.row.title || '—' }}</el-link>
        </template>
      </el-table-column>
      <el-table-column v-if="columns.categoryId.visible" label="类目" min-width="120">
        <template #default="scope">{{ categoryName(scope.row.categoryId) }}</template>
      </el-table-column>
      <el-table-column v-if="columns.merchantId.visible" label="商家" width="100" align="center">
        <template #default="scope">
          <el-tooltip content="商家账号 dept_id" placement="top">
            <span>{{ merchantLabel(scope.row.merchantId) }}</span>
          </el-tooltip>
        </template>
      </el-table-column>
      <el-table-column v-if="columns.priceMin.visible" label="价格起" width="100" align="right">
        <template #default="scope"><mall-money :value="scope.row.priceMin" /></template>
      </el-table-column>
      <el-table-column v-if="columns.createTime.visible" label="提交时间" width="160" align="center">
        <template #default="scope">{{ parseTime(scope.row.createTime) || '—' }}</template>
      </el-table-column>
      <el-table-column v-if="columns.auditStatus.visible" label="审核状态" width="110" align="center">
        <template #default="scope"><mall-status-tag :dict="AUDIT_STATUS" :value="scope.row.auditStatus" /></template>
      </el-table-column>
      <el-table-column v-if="columns.status.visible" label="上下架" width="100" align="center">
        <template #default="scope"><mall-status-tag :dict="ITEM_STATUS" :value="scope.row.status" /></template>
      </el-table-column>
      <el-table-column label="操作" width="160" align="center" fixed="right">
        <template #default="scope">
          <el-button
            v-if="scope.row.auditStatus === 0"
            v-hasPermi="['mall:item:audit']"
            link
            type="primary"
            icon="Stamp"
            @click="handleAudit(scope.row)"
          >审核</el-button>
          <el-button link type="primary" icon="View" @click="handleView(scope.row)">查看</el-button>
        </template>
      </el-table-column>
      <template #empty>
        <el-empty :description="emptyText">
          <el-button icon="Refresh" @click="getList">刷新</el-button>
          <el-button v-if="hasFilter" icon="RefreshLeft" @click="resetQuery">重置</el-button>
        </el-empty>
      </template>
    </el-table>

    <pagination
      v-show="total > 0"
      :total="total"
      v-model:page="queryParams.pageNum"
      v-model:limit="queryParams.pageSize"
      @pagination="getList"
    />

    <!-- 审核抽屉：待审可提交通过/驳回，已审只读（§5.4.6） -->
    <audit-drawer v-model:visible="auditVisible" :item-id="auditItemId" :readonly="readonlyMode" @audited="handleAudited" />
  </div>
</template>

<script setup name="Audit">
/**
 * 商品审核（/mall/audit，§5.4）
 *
 * - 默认 auditStatus=0 待审队列；可切 1（已驳回）/2（审核通过）复查历史
 * - 列表/详情权限：后端 hasAnyPermi('mall:item:list,mall:item:audit')，reviewer 无 mall:item:list 也可查
 * - 本页不渲染编辑/上下架/新增按钮（单一职责，reviewer 也无对应权限）
 * - 审核动作在 AuditDrawer 内完成（GET /{id} 展示型取数 + PUT /{id}/audit），成功后 emit audited → 刷新队列
 */
import { listItems } from '@/api/mall/item'
import { listCategories, listHomeCategories } from '@/api/mall/category'
import { AUDIT_STATUS, ITEM_STATUS, buildCategoryMap, optionsOf } from '@/utils/mallDict'
import CategoryTreeSelect from '@/components/mall/CategoryTreeSelect.vue'
import AuditDrawer from '@/components/mall/AuditDrawer.vue'
import MallMoney from '@/components/mall/MallMoney.vue'
import MallStatusTag from '@/components/mall/MallStatusTag.vue'

const { proxy } = getCurrentInstance()
const route = useRoute()
const router = useRouter()
// 本页路由 path（keep-alive 缓存的组件在其他页面 query 变化时用于过滤）
const pagePath = route.path

const loading = ref(false)
const loadFailed = ref(false)
const showSearch = ref(true)
const list = ref([])
const total = ref(0)

const columns = ref({
  mainImage: { label: '主图', visible: true },
  id: { label: '商品ID', visible: true },
  title: { label: '商品标题', visible: true },
  categoryId: { label: '类目', visible: true },
  merchantId: { label: '商家', visible: true },
  priceMin: { label: '价格起', visible: true },
  createTime: { label: '提交时间', visible: true },
  auditStatus: { label: '审核状态', visible: true },
  status: { label: '上下架', visible: true }
})

// 默认待审队列（§5.4.3）
const queryParams = reactive({
  pageNum: 1,
  pageSize: 10,
  keyword: undefined,
  categoryId: undefined,
  auditStatus: 0
})

const categories = ref([])
const categoryMap = ref({})
const auditStatusOptions = optionsOf(AUDIT_STATUS)

const auditVisible = ref(false)
const auditItemId = ref(null)
// true=只读查看，false=可提交审核（§5.4.5）
const readonlyMode = ref(false)

const hasFilter = computed(() => {
  const q = queryParams
  const hasValue = value => value !== undefined && value !== null && value !== ''
  // 默认待审队列（auditStatus=0）不算筛选条件
  return !!(hasValue(q.keyword) || hasValue(q.categoryId) || (hasValue(q.auditStatus) && q.auditStatus !== 0))
})

const emptyText = computed(() => (queryParams.auditStatus === 0 ? '暂无待审商品' : '暂无商品'))

function categoryName(categoryId) {
  if (categoryId === null || categoryId === undefined) return '—'
  return categoryMap.value[categoryId] || `#${categoryId}`
}

function merchantLabel(merchantId) {
  return merchantId === null || merchantId === undefined || merchantId === '' ? '—' : `#${merchantId}`
}

function buildQueryParams() {
  const params = {
    pageNum: queryParams.pageNum,
    pageSize: queryParams.pageSize
  }
  const keyword = String(queryParams.keyword ?? '').trim()
  if (keyword) params.keyword = keyword
  ;['categoryId', 'auditStatus'].forEach(key => {
    const value = queryParams[key]
    if (value !== undefined && value !== null && value !== '') params[key] = value
  })
  return params
}

/** 当前筛选对应的 URL query（字段与 buildQueryParams 一致，值统一为字符串） */
function currentQuery() {
  const params = buildQueryParams()
  const query = {}
  Object.keys(params).forEach(key => {
    query[key] = String(params[key])
  })
  return query
}

/** 查询条件同步到 URL（刷新保持，§5.1.5） */
function syncQueryToUrl() {
  router.replace({ path: pagePath, query: currentQuery() }).catch(() => {})
}

/** 是否与当前筛选一致（避免自身写 URL 触发重复查询/死循环） */
function isSameQuery(query, target) {
  const keys = Object.keys(query || {})
  if (keys.length !== Object.keys(target).length) return false
  return keys.every(key => String(query[key]) === String(target[key]))
}

/** 进页/keep-alive 下路由 query 变化时回填（先清空旧筛选，再按 URL 重建） */
function initQueryFromRoute() {
  const query = route.query || {}
  queryParams.keyword = query.keyword ? String(query.keyword) : undefined
  queryParams.categoryId = toPositiveNumber(query.categoryId)
  const auditStatus = toNumber(query.auditStatus)
  // 本页无「全部」选项：URL 未带 auditStatus 时回到默认待审队列（§5.4.3）
  queryParams.auditStatus = auditStatus === undefined ? 0 : auditStatus
  queryParams.pageNum = toPositiveNumber(query.pageNum) ?? 1
  queryParams.pageSize = toPositiveNumber(query.pageSize) ?? 10
}

function toNumber(value) {
  if (value === undefined || value === null || value === '') return undefined
  const num = Number(value)
  return Number.isNaN(num) ? undefined : num
}

function toPositiveNumber(value) {
  const num = toNumber(value)
  return num !== undefined && num > 0 ? num : undefined
}

async function getList() {
  loading.value = true
  loadFailed.value = false
  try {
    const res = await listItems(buildQueryParams())
    list.value = res?.list || []
    total.value = res?.total || 0
    syncQueryToUrl()
  } catch (e) {
    loadFailed.value = true
    list.value = []
    total.value = 0
  } finally {
    loading.value = false
  }
}

async function loadCategories() {
  try {
    // reviewer 只有 mall:item:audit / mall:audit:list，无 mall:category:list：
    // 有权限用管理端类目树（含停用），无权限用匿名公开类目树，避免每次进页 403 提示
    const data = proxy.$auth.hasPermi('mall:category:list')
      ? await listCategories()
      : await listHomeCategories()
    categories.value = Array.isArray(data) ? data : []
    categoryMap.value = buildCategoryMap(categories.value)
  } catch (e) {
    // 类目拉取失败降级为 #categoryId（§5.4.7）
    categories.value = []
    categoryMap.value = {}
  }
}

function handleQuery() {
  queryParams.pageNum = 1
  getList()
}

function resetQuery() {
  proxy.resetForm('queryRef')
  queryParams.keyword = undefined
  queryParams.categoryId = undefined
  queryParams.auditStatus = 0
  handleQuery()
}

function handleAudit(row) {
  if (!row) return
  readonlyMode.value = false
  auditItemId.value = row.id
  auditVisible.value = true
}

function handleView(row) {
  if (!row) return
  readonlyMode.value = true
  auditItemId.value = row.id
  auditVisible.value = true
}

function handleAudited() {
  getList()
}

// keep-alive 下从快捷入口再次带参跳转（如 /mall/audit?auditStatus=0）时回填并重查
watch(
  () => route.fullPath,
  () => {
    if (route.path !== pagePath) return
    if (isSameQuery(route.query, currentQuery())) return
    initQueryFromRoute()
    getList()
  }
)

onMounted(() => {
  initQueryFromRoute()
  loadCategories()
  getList()
})
</script>

<style scoped>
/* 审核页无新增按钮，工具条右对齐 */
.mb8 {
  margin-bottom: 8px;
}
</style>
