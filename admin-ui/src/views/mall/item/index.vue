<template>
  <div class="app-container">
    <!-- 查询区（后端仅支持 keyword/categoryId/auditStatus/status/merchantId，不放 species） -->
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
        <el-select v-model="queryParams.auditStatus" placeholder="全部" clearable style="width: 160px">
          <el-option v-for="item in auditStatusOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="上下架" prop="status">
        <el-select v-model="queryParams.status" placeholder="全部" clearable style="width: 160px">
          <el-option v-for="item in itemStatusOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item v-if="hasListPermi" label="商家ID" prop="merchantId">
        <el-input-number
          v-model="queryParams.merchantId"
          :min="1"
          :precision="0"
          :controls="false"
          placeholder="商家ID"
          style="width: 160px"
        />
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <!-- 操作栏 -->
    <el-row :gutter="10" class="mb8">
      <el-col v-hasPermi="['mall:item:add']" :span="1.5">
        <el-button type="primary" plain icon="Plus" @click="handleAdd">新增</el-button>
      </el-col>
      <right-toolbar
        v-model:showSearch="showSearch"
        :columns="columns"
        storage-key="mall-item"
        @queryTable="getList"
      />
    </el-row>

    <el-alert v-if="loadFailed" type="error" :closable="false" show-icon class="mb8">
      <template #title>
        商品列表加载失败
        <el-button link type="primary" @click="getList">重试</el-button>
      </template>
    </el-alert>

    <!-- 数据区 -->
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
      <el-table-column v-if="columns.merchantId.visible" label="商家" width="110" align="center">
        <template #default="scope">
          <el-tooltip content="商家账号 dept_id" placement="top">
            <span>{{ merchantLabel(scope.row.merchantId) }}</span>
          </el-tooltip>
        </template>
      </el-table-column>
      <el-table-column v-if="columns.priceMin.visible" label="价格起" width="100" align="right">
        <template #default="scope">
          <mall-money :value="scope.row.priceMin" />
        </template>
      </el-table-column>
      <el-table-column v-if="columns.auditStatus.visible" label="审核状态" width="110" align="center">
        <template #default="scope">
          <mall-status-tag :dict="AUDIT_STATUS" :value="scope.row.auditStatus" />
        </template>
      </el-table-column>
      <el-table-column v-if="columns.status.visible" label="上下架" width="100" align="center">
        <template #default="scope">
          <mall-status-tag :dict="ITEM_STATUS" :value="scope.row.status" />
        </template>
      </el-table-column>
      <el-table-column v-if="columns.sales.visible" label="销量" width="90" align="right">
        <template #default="scope">{{ scope.row.sales ?? 0 }}</template>
      </el-table-column>
      <el-table-column v-if="columns.updateTime.visible" label="更新时间" width="160" align="center">
        <template #default="scope">{{ parseTime(scope.row.updateTime) || '—' }}</template>
      </el-table-column>
      <el-table-column label="操作" width="240" align="center" fixed="right">
        <template #default="scope">
          <el-button link type="primary" icon="View" @click="handleView(scope.row)">详情</el-button>
          <el-button
            v-hasPermi="['mall:item:edit']"
            link
            type="primary"
            icon="Edit"
            @click="handleEdit(scope.row)"
          >编辑</el-button>
          <el-button
            v-if="scope.row.auditStatus === 0"
            v-hasPermi="['mall:item:audit']"
            link
            type="primary"
            icon="Stamp"
            @click="handleAudit(scope.row)"
          >审核</el-button>
          <!-- 上架：auditStatus !== 2 时禁用并 tooltip 说明；下架无前置 -->
          <template v-if="scope.row.status === 1">
            <el-button
              v-hasPermi="['mall:item:status']"
              link
              type="warning"
              icon="Download"
              :loading="scope.row._statusLoading"
              @click="handleToggleStatus(scope.row)"
            >下架</el-button>
          </template>
          <el-tooltip v-else :disabled="scope.row.auditStatus === 2" content="审核通过后才能上架" placement="top">
            <span>
              <el-button
                v-hasPermi="['mall:item:status']"
                link
                type="success"
                icon="Upload"
                :disabled="scope.row.auditStatus !== 2"
                :loading="scope.row._statusLoading"
                @click="handleToggleStatus(scope.row)"
              >上架</el-button>
            </span>
          </el-tooltip>
        </template>
      </el-table-column>
      <template #empty>
        <el-empty :description="hasFilter ? '没有符合条件的商品，请调整筛选条件' : '暂无商品'">
          <el-button v-if="hasFilter" icon="Refresh" @click="resetQuery">重置筛选</el-button>
          <el-button v-else v-hasPermi="['mall:item:add']" type="primary" icon="Plus" @click="handleAdd">新增商品</el-button>
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

    <!-- 新增 / 编辑：统一表单抽屉（admin 模式） -->
    <item-form-drawer
      v-model:visible="formVisible"
      mode="admin"
      :edit-id="editId"
      :categories="categories"
      :merchant-options="merchantOptions"
      @saved="handleSaved"
    />

    <!-- 审核入口：待审商品可直接在商品管理发起审核（§4.4） -->
    <audit-drawer v-model:visible="auditVisible" :item-id="auditItemId" @audited="handleAudited" />

    <!-- 只读详情抽屉（含审核留痕） -->
    <el-drawer v-model="detailVisible" title="商品详情" size="900px" direction="rtl" append-to-body>
      <div v-loading="detailLoading" class="detail-body">
        <template v-if="detail">
          <el-descriptions :column="2" border size="small">
            <el-descriptions-item label="商品ID">{{ detail.id ?? '—' }}</el-descriptions-item>
            <el-descriptions-item label="商家ID">{{ merchantLabel(detail.merchantId) }}</el-descriptions-item>
            <el-descriptions-item label="商品标题" :span="2">{{ detail.title || '—' }}</el-descriptions-item>
            <el-descriptions-item label="副标题" :span="2">{{ detail.subtitle || '—' }}</el-descriptions-item>
            <el-descriptions-item label="类目">{{ categoryName(detail.categoryId) }}</el-descriptions-item>
            <el-descriptions-item label="品牌">{{ detail.brand || '—' }}</el-descriptions-item>
            <el-descriptions-item label="适用宠物">{{ dictLabel(PET_SPECIES, detail.petSpecies, '—') }}</el-descriptions-item>
            <el-descriptions-item label="适用年龄">{{ dictLabel(AGE_STAGE, detail.ageStage, '—') }}</el-descriptions-item>
            <el-descriptions-item label="重量范围">{{ detail.weightRange || '—' }}</el-descriptions-item>
            <el-descriptions-item label="价格起"><mall-money :value="detail.priceMin" /></el-descriptions-item>
            <el-descriptions-item label="成本价"><mall-money :value="detail.costPrice" /></el-descriptions-item>
            <el-descriptions-item label="销量">{{ detail.sales ?? 0 }}</el-descriptions-item>
            <el-descriptions-item label="审核状态">
              <mall-status-tag :dict="AUDIT_STATUS" :value="detail.auditStatus" />
            </el-descriptions-item>
            <el-descriptions-item label="上下架">
              <mall-status-tag :dict="ITEM_STATUS" :value="detail.status" />
            </el-descriptions-item>
            <el-descriptions-item label="商品标记" :span="2">
              <el-tag v-if="detail.supportSubscribe" type="success" size="small" class="mr8">支持订阅</el-tag>
              <el-tag v-if="detail.isPrescription" type="warning" size="small" class="mr8">处方商品</el-tag>
              <span v-if="!detail.supportSubscribe && !detail.isPrescription">—</span>
            </el-descriptions-item>
            <el-descriptions-item label="创建时间">{{ parseTime(detail.createTime) || '—' }}</el-descriptions-item>
            <el-descriptions-item label="更新时间">{{ parseTime(detail.updateTime) || '—' }}</el-descriptions-item>
          </el-descriptions>

          <el-divider content-position="left">商品图片</el-divider>
          <div v-if="detailImages.length" class="image-list">
            <image-preview v-for="(url, index) in detailImages" :key="index" :src="url" width="72px" height="72px" />
          </div>
          <div v-else class="text-muted">暂无图片</div>

          <el-divider content-position="left">SKU 列表</el-divider>
          <el-table :data="detail.skus || []" size="small" border :row-class-name="skuRowClassName" empty-text="暂无 SKU">
            <el-table-column label="规格名" prop="specName" min-width="120" show-overflow-tooltip />
            <el-table-column label="价格" width="100" align="right">
              <template #default="scope"><mall-money :value="scope.row.price" /></template>
            </el-table-column>
            <el-table-column label="库存" prop="stock" width="80" align="center" />
            <el-table-column label="SKU 编码" prop="skuCode" min-width="140" show-overflow-tooltip />
            <el-table-column label="状态" width="90" align="center">
              <template #default="scope"><mall-status-tag :dict="SKU_STATUS" :value="scope.row.status" /></template>
            </el-table-column>
          </el-table>

          <el-divider content-position="left">审核留痕</el-divider>
          <el-timeline v-if="detailAudits.length">
            <el-timeline-item
              v-for="audit in detailAudits"
              :key="audit.id"
              :type="audit.auditStatus === 2 ? 'success' : 'danger'"
              :timestamp="parseTime(audit.createTime) || ''"
              placement="top"
            >
              <div class="audit-history-title">
                <span :class="audit.auditStatus === 2 ? 'text-success' : 'text-danger'">
                  {{ dictLabel(AUDIT_STATUS, audit.auditStatus, '—') }}
                </span>
                <span class="text-muted">审核人：{{ audit.auditor || '—' }}</span>
              </div>
              <div class="audit-history-remark">{{ audit.remark || '无审核意见' }}</div>
            </el-timeline-item>
          </el-timeline>
          <div v-else class="text-muted">暂无审核记录</div>

          <el-divider content-position="left">商品详情</el-divider>
          <div class="detail-html" v-html="detailHtml"></div>
        </template>
      </div>
      <template #footer>
        <div class="drawer-footer">
          <el-button @click="detailVisible = false">关闭</el-button>
          <el-button v-hasPermi="['mall:item:edit']" type="primary" :disabled="!detail" @click="handleEditFromDetail">编辑</el-button>
        </div>
      </template>
    </el-drawer>
  </div>
</template>

<script setup name="Items">
/**
 * 商品管理（/mall/items，§5.3）
 *
 * - 列表：GET /api/admin/items（keyword/categoryId/auditStatus/status/merchantId/pageNum/pageSize）
 * - 详情：GET /api/admin/items/{id}（skus/images/audits）
 * - 新增/编辑：ItemFormDrawer（mode=admin）→ POST/PUT /api/admin/items
 * - 上下架：PUT /api/admin/items/{id}/status（上架要求 auditStatus=2）
 * - 审核入口：AuditDrawer（仅 auditStatus=0，权限 mall:item:audit）
 * - 审核状态与上下架两列两标签；admin 编辑不重审（提示见抽屉）
 */
import { getItemDetail, listItems, updateItemStatus } from '@/api/mall/item'
import { listCategories } from '@/api/mall/category'
import {
  AGE_STAGE,
  AUDIT_STATUS,
  ITEM_STATUS,
  PET_SPECIES,
  SKU_STATUS,
  buildCategoryMap,
  dictLabel,
  optionsOf
} from '@/utils/mallDict'
import CategoryTreeSelect from '@/components/mall/CategoryTreeSelect.vue'
import ItemFormDrawer from '@/components/mall/ItemFormDrawer.vue'
import AuditDrawer from '@/components/mall/AuditDrawer.vue'
import MallMoney from '@/components/mall/MallMoney.vue'
import MallStatusTag from '@/components/mall/MallStatusTag.vue'

const { proxy } = getCurrentInstance()
const route = useRoute()
const router = useRouter()

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
  auditStatus: { label: '审核状态', visible: true },
  status: { label: '上下架', visible: true },
  sales: { label: '销量', visible: true },
  updateTime: { label: '更新时间', visible: true }
})

// 查询条件（商品列表不接受 species，后端会静默忽略）
const queryParams = reactive({
  pageNum: 1,
  pageSize: 10,
  keyword: undefined,
  categoryId: undefined,
  auditStatus: undefined,
  status: undefined,
  merchantId: undefined
})

const categories = ref([])
const categoryMap = ref({})
// 一期无商家列表接口：默认空数组 → 表单内 el-input-number 手填（演示 9001）
const merchantOptions = ref([])

const auditStatusOptions = optionsOf(AUDIT_STATUS)
const itemStatusOptions = optionsOf(ITEM_STATUS)

// 商家筛选仅 admin（reviewer 只进审核页）
const hasListPermi = computed(() => proxy.$auth.hasPermi('mall:item:list'))

// 新增/编辑抽屉
const formVisible = ref(false)
const editId = ref(null)

// 审核抽屉
const auditVisible = ref(false)
const auditItemId = ref(null)

// 只读详情抽屉
const detailVisible = ref(false)
const detailLoading = ref(false)
const detail = ref(null)

const detailImages = computed(() => {
  const item = detail.value
  if (!item) return []
  const urls = []
  if (item.mainImage) urls.push(item.mainImage)
  ;(item.images || [])
    .slice()
    .sort((a, b) => (a.sort ?? 0) - (b.sort ?? 0))
    .forEach(image => {
      if (image?.url && !urls.includes(image.url)) urls.push(image.url)
    })
  return urls
})

const detailAudits = computed(() => {
  const audits = detail.value?.audits || []
  return audits
    .slice()
    .sort((a, b) => String(b.createTime || '').localeCompare(String(a.createTime || '')))
})

const detailHtml = computed(() => detail.value?.detail || '<p class="text-muted">暂无商品详情</p>')

const hasFilter = computed(() => {
  const q = queryParams
  const hasValue = value => value !== undefined && value !== null && value !== ''
  return !!(hasValue(q.keyword) || hasValue(q.categoryId) || hasValue(q.auditStatus) || hasValue(q.status) || hasValue(q.merchantId))
})

function categoryName(categoryId) {
  if (categoryId === null || categoryId === undefined) return '—'
  return categoryMap.value[categoryId] || `#${categoryId}`
}

function merchantLabel(merchantId) {
  return merchantId === null || merchantId === undefined || merchantId === '' ? '—' : `#${merchantId}`
}

function skuRowClassName({ row }) {
  return row && row.status === 0 ? 'sku-row-disabled' : ''
}

/** 构造请求参数：空值丢弃，keyword 去首尾空格 */
function buildQueryParams() {
  const params = {
    pageNum: queryParams.pageNum,
    pageSize: queryParams.pageSize
  }
  const keyword = String(queryParams.keyword ?? '').trim()
  if (keyword) params.keyword = keyword
  ;['categoryId', 'auditStatus', 'status', 'merchantId'].forEach(key => {
    const value = queryParams[key]
    if (value !== undefined && value !== null && value !== '') params[key] = value
  })
  return params
}

/** 查询条件同步到 URL（刷新保持，§5.1.5） */
function syncQueryToUrl() {
  const params = buildQueryParams()
  const query = {}
  Object.keys(params).forEach(key => {
    query[key] = String(params[key])
  })
  router.replace({ path: route.path, query }).catch(() => {})
}

/** 进页回填 URL 查询条件 */
function initQueryFromRoute() {
  const query = route.query || {}
  if (query.keyword) queryParams.keyword = String(query.keyword)
  const categoryId = Number(query.categoryId)
  if (Number.isInteger(categoryId) && categoryId > 0) queryParams.categoryId = categoryId
  const auditStatus = Number(query.auditStatus)
  if (query.auditStatus !== undefined && query.auditStatus !== '' && !Number.isNaN(auditStatus)) {
    queryParams.auditStatus = auditStatus
  }
  const status = Number(query.status)
  if (query.status !== undefined && query.status !== '' && !Number.isNaN(status)) {
    queryParams.status = status
  }
  const merchantId = Number(query.merchantId)
  if (Number.isInteger(merchantId) && merchantId > 0) queryParams.merchantId = merchantId
  const pageNum = Number(query.pageNum)
  if (Number.isInteger(pageNum) && pageNum > 0) queryParams.pageNum = pageNum
  const pageSize = Number(query.pageSize)
  if (Number.isInteger(pageSize) && pageSize > 0) queryParams.pageSize = pageSize
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
    const data = await listCategories()
    categories.value = Array.isArray(data) ? data : []
    categoryMap.value = buildCategoryMap(categories.value)
  } catch (e) {
    // 降级：列表类目列显示 #categoryId（§5.3.2）
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
  queryParams.auditStatus = undefined
  queryParams.status = undefined
  queryParams.merchantId = undefined
  handleQuery()
}

function handleAdd() {
  editId.value = null
  formVisible.value = true
}

function handleEdit(row) {
  if (!row) return
  editId.value = row.id
  formVisible.value = true
}

async function handleView(row) {
  if (!row) return
  detailVisible.value = true
  detailLoading.value = true
  detail.value = null
  try {
    detail.value = await getItemDetail(row.id)
  } catch (e) {
    // 商品不存在/不可售：关闭抽屉并刷新列表（PET-3003，§5.3.5）
    detailVisible.value = false
    if (e?.errorCode === 'PET-3003' || e?.errorCode === 'PET-2003') getList()
  } finally {
    detailLoading.value = false
  }
}

function handleEditFromDetail() {
  if (!detail.value) return
  detailVisible.value = false
  editId.value = detail.value.id
  formVisible.value = true
}

function handleSaved() {
  getList()
}

function handleAudit(row) {
  if (!row) return
  auditItemId.value = row.id
  auditVisible.value = true
}

function handleAudited() {
  getList()
}

/** 上架 / 下架（上架需 auditStatus=2，按钮已前置 disabled） */
function handleToggleStatus(row) {
  if (!row || row._statusLoading) return
  const targetStatus = row.status === 1 ? 0 : 1
  const message = targetStatus === 1
    ? `确认上架「${row.title || ''}」？上架后前台可见。`
    : `确认下架「${row.title || ''}」？下架后前台不可见。`
  proxy.$modal
    .confirm(message)
    .then(async () => {
      row._statusLoading = true
      try {
        await updateItemStatus(row.id, targetStatus)
        proxy.$modal.msgSuccess(targetStatus === 1 ? '上架成功' : '下架成功')
        getList()
      } catch (e) {
        // PET-3003 未过审不可上架 / PET-3002 状态已变化：刷新同步（提示由请求层统一）
        if (e?.errorCode === 'PET-3003' || e?.errorCode === 'PET-3002') {
          getList()
        }
      } finally {
        row._statusLoading = false
      }
    })
    .catch(() => {})
}

onMounted(() => {
  initQueryFromRoute()
  loadCategories()
  getList()
})
</script>

<style scoped>
.image-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.detail-html {
  max-height: 320px;
  overflow-y: auto;
  padding: 8px 12px;
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 4px;
  line-height: 1.6;
  word-break: break-word;
}

.detail-body {
  min-height: 200px;
}

.audit-history-title {
  display: flex;
  align-items: center;
  gap: 12px;
  font-weight: 500;
}

.audit-history-remark {
  margin-top: 4px;
  color: var(--el-text-color-regular);
  word-break: break-word;
}

.drawer-footer {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

.text-muted {
  color: var(--el-text-color-secondary);
}

.text-success {
  color: var(--el-color-success);
}

.text-danger {
  color: var(--el-color-danger);
}

.mr8 {
  margin-right: 8px;
}

:deep(.sku-row-disabled) {
  color: #b1b3b8;
  background-color: #fafafa;
}

:deep(.detail-html p.text-muted) {
  color: var(--el-text-color-secondary);
}
</style>
