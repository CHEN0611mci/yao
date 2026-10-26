<template>
  <div class="app-container">
    <el-alert
      class="mb8"
      type="info"
      :closable="false"
      show-icon
      title="审核通过 ≠ 上架：发布/编辑后商品进入「待审核 + 已下架」状态，审核通过后请手动上架；编辑在售商品会重新待审并自动下架，前台不可见。"
    />

    <!-- 查询区 -->
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
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
        <div style="width: 220px">
          <category-tree-select
            v-model="queryParams.categoryId"
            :categories="categoryTree"
            :only-leaf="false"
            placeholder="请选择类目"
          />
        </div>
      </el-form-item>
      <el-form-item label="审核状态" prop="auditStatus">
        <el-select v-model="queryParams.auditStatus" placeholder="全部" clearable style="width: 160px">
          <el-option v-for="opt in auditStatusOptions" :key="opt.value" :label="opt.label" :value="opt.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="上下架" prop="status">
        <el-select v-model="queryParams.status" placeholder="全部" clearable style="width: 140px">
          <el-option v-for="opt in itemStatusOptions" :key="opt.value" :label="opt.label" :value="opt.value" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <!-- 操作栏 -->
    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5">
        <el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['mall:merchant:item:add']">发布商品</el-button>
      </el-col>
      <right-toolbar
        v-model:showSearch="showSearch"
        :columns="columns"
        storage-key="mall-merchant-item"
        @queryTable="getList"
      />
    </el-row>

    <!-- 数据区 -->
    <el-table v-loading="loading" :data="itemList" row-key="id">
      <el-table-column v-if="columns.mainImage.visible" label="主图" width="90" align="center">
        <template #default="scope">
          <image-preview
            v-if="scope.row.mainImage"
            :src="scope.row.mainImage"
            width="50px"
            height="50px"
          />
          <span v-else>—</span>
        </template>
      </el-table-column>
      <el-table-column v-if="columns.id.visible" label="商品ID" prop="id" width="80" align="center" />
      <el-table-column v-if="columns.title.visible" label="商品标题" prop="title" width="220" :show-overflow-tooltip="true">
        <template #default="scope">
          <el-link type="primary" :underline="false" @click="handleDetail(scope.row)">{{ scope.row.title || '—' }}</el-link>
        </template>
      </el-table-column>
      <el-table-column v-if="columns.categoryId.visible" label="类目" width="120" :show-overflow-tooltip="true">
        <template #default="scope">{{ categoryName(scope.row.categoryId) }}</template>
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
      <el-table-column v-if="columns.sales.visible" label="销量" prop="sales" width="90" align="right">
        <template #default="scope">{{ scope.row.sales ?? 0 }}</template>
      </el-table-column>
      <el-table-column v-if="columns.updateTime.visible" label="更新时间" width="160" align="center">
        <template #default="scope">
          <span>{{ parseTime(scope.row.updateTime) || '—' }}</span>
        </template>
      </el-table-column>
      <el-table-column label="操作" width="240" align="center" fixed="right" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button link type="primary" icon="View" @click="handleDetail(scope.row)">详情</el-button>
          <el-button
            link
            type="primary"
            icon="Edit"
            v-hasPermi="['mall:merchant:item:edit']"
            @click="handleEdit(scope.row)"
          >编辑</el-button>
          <el-tooltip
            v-if="scope.row.status === 0"
            :disabled="scope.row.auditStatus === 2"
            content="商品未审核通过，不能上架"
            placement="top"
          >
            <span>
              <el-button
                link
                type="success"
                icon="Top"
                v-hasPermi="['mall:merchant:item:status']"
                :disabled="scope.row.auditStatus !== 2"
                :loading="scope.row._statusLoading"
                @click="handleStatusChange(scope.row)"
              >上架</el-button>
            </span>
          </el-tooltip>
          <el-button
            v-else-if="scope.row.status === 1"
            link
            type="warning"
            icon="Bottom"
            v-hasPermi="['mall:merchant:item:status']"
            :loading="scope.row._statusLoading"
            @click="handleStatusChange(scope.row)"
          >下架</el-button>
          <el-button link type="primary" icon="Box" @click="handleOpenStock(scope.row)">库存</el-button>
        </template>
      </el-table-column>

      <template #empty>
        <el-empty v-if="loadError === 'merchant'" description="当前账号未绑定商家，请联系管理员" />
        <el-empty v-else-if="loadError === 'failed'" description="商品列表加载失败">
          <el-button type="primary" icon="Refresh" @click="getList">重试</el-button>
        </el-empty>
        <el-empty v-else-if="hasFilter" description="没有符合条件的商品">
          <el-button icon="Refresh" @click="resetQuery">重置筛选</el-button>
        </el-empty>
        <el-empty v-else description="你还没有发布商品">
          <el-button
            v-if="canAdd"
            type="primary"
            icon="Plus"
            @click="handleAdd"
          >发布商品</el-button>
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

    <!-- ① 发布/编辑表单抽屉（与商品管理共用，mode=merchant 时不提交 merchantId） -->
    <item-form-drawer
      v-model:visible="formDrawer.visible"
      mode="merchant"
      :edit-id="formDrawer.editId"
      :categories="categoryTree"
      :merchant-options="[]"
      @saved="handleFormSaved"
    />

    <!-- ② 只读详情抽屉（M2：skus/images，无 audits） -->
    <el-drawer
      v-model="detailDrawer.visible"
      :title="detailDrawer.detail ? `商品详情 · ${detailDrawer.detail.title}` : '商品详情'"
      size="720px"
      direction="rtl"
      append-to-body
    >
      <div v-loading="detailDrawer.loading" class="drawer-body">
        <template v-if="detailDrawer.detail">
          <el-descriptions :column="2" border>
            <el-descriptions-item label="商品ID">{{ detailDrawer.detail.id }}</el-descriptions-item>
            <el-descriptions-item label="商品标题">{{ detailDrawer.detail.title || '—' }}</el-descriptions-item>
            <el-descriptions-item label="副标题" :span="2">{{ detailDrawer.detail.subtitle || '—' }}</el-descriptions-item>
            <el-descriptions-item label="品牌">{{ detailDrawer.detail.brand || '—' }}</el-descriptions-item>
            <el-descriptions-item label="适用宠物">{{ dictLabel(PET_SPECIES, detailDrawer.detail.petSpecies, '—') }}</el-descriptions-item>
            <el-descriptions-item label="年龄阶段">{{ dictLabel(AGE_STAGE, detailDrawer.detail.ageStage, '—') }}</el-descriptions-item>
            <el-descriptions-item label="重量范围">{{ detailDrawer.detail.weightRange || '—' }}</el-descriptions-item>
            <el-descriptions-item label="类目">{{ categoryName(detailDrawer.detail.categoryId) }}</el-descriptions-item>
            <el-descriptions-item label="价格起">
              <mall-money :value="detailDrawer.detail.priceMin" />
            </el-descriptions-item>
            <el-descriptions-item label="成本价">
              <mall-money :value="detailDrawer.detail.costPrice" />
            </el-descriptions-item>
            <el-descriptions-item label="审核状态">
              <mall-status-tag :dict="AUDIT_STATUS" :value="detailDrawer.detail.auditStatus" />
            </el-descriptions-item>
            <el-descriptions-item label="上下架">
              <mall-status-tag :dict="ITEM_STATUS" :value="detailDrawer.detail.status" />
            </el-descriptions-item>
            <el-descriptions-item label="支持订阅">
              {{ detailDrawer.detail.supportSubscribe === 1 ? '是' : '否' }}
            </el-descriptions-item>
            <el-descriptions-item label="处方商品">
              {{ detailDrawer.detail.isPrescription === 1 ? '是' : '否' }}
            </el-descriptions-item>
            <el-descriptions-item label="销量">{{ detailDrawer.detail.sales ?? 0 }}</el-descriptions-item>
            <el-descriptions-item label="创建时间">{{ parseTime(detailDrawer.detail.createTime) || '—' }}</el-descriptions-item>
            <el-descriptions-item label="更新时间">{{ parseTime(detailDrawer.detail.updateTime) || '—' }}</el-descriptions-item>
            <el-descriptions-item label="商品图片" :span="2">
              <div class="image-list">
                <image-preview
                  v-for="(img, index) in detailImages"
                  :key="index"
                  :src="img"
                  width="60px"
                  height="60px"
                />
                <span v-if="!detailImages.length">—</span>
              </div>
            </el-descriptions-item>
          </el-descriptions>

          <div class="drawer-section-title">SKU 列表</div>
          <el-table :data="detailDrawer.detail.skus || []" size="small" border empty-text="暂无 SKU">
            <el-table-column label="规格" prop="specName" min-width="120" :show-overflow-tooltip="true" />
            <el-table-column label="价格" width="110" align="right">
              <template #default="scope">
                <mall-money :value="scope.row.price" />
              </template>
            </el-table-column>
            <el-table-column label="库存" prop="stock" width="90" align="right" />
            <el-table-column label="SKU 编码" prop="skuCode" min-width="150" :show-overflow-tooltip="true">
              <template #default="scope">{{ scope.row.skuCode || '—' }}</template>
            </el-table-column>
            <el-table-column label="状态" width="100" align="center">
              <template #default="scope">
                <mall-status-tag :dict="SKU_STATUS" :value="scope.row.status" />
              </template>
            </el-table-column>
          </el-table>

          <div class="drawer-section-title">商品详情</div>
          <div v-if="detailDrawer.detail.detail" class="detail-html" v-html="detailDrawer.detail.detail"></div>
          <span v-else>—</span>

          <el-alert
            class="mt16"
            type="info"
            :closable="false"
            title="商家端商品详情不展示平台审核留痕（audits）；审核结果以「审核状态」为准。"
          />
        </template>
      </div>
    </el-drawer>

    <!-- ③ 库存抽屉（M9–M11） -->
    <el-drawer
      v-model="stockDrawer.visible"
      size="720px"
      direction="rtl"
      append-to-body
      @closed="handleStockDrawerClosed"
    >
      <template #header>
        <div class="stock-drawer-header">
          <div>
            <span class="stock-drawer-title">库存 · {{ stockDrawer.title || '商品' }}</span>
            <span class="stock-drawer-sub">商品ID {{ stockDrawer.itemId }}</span>
          </div>
          <el-button link type="primary" icon="Refresh" :loading="stockDrawer.stockLoading" @click="refreshStockTab">刷新</el-button>
        </div>
      </template>

      <el-tabs v-model="stockDrawer.activeTab" @tab-change="handleStockTabChange">
        <el-tab-pane label="SKU 库存" name="sku">
          <el-table
            v-loading="stockDrawer.stockLoading"
            :data="stockDrawer.stockRows"
            size="small"
            border
            empty-text="暂无库存记录"
          >
            <el-table-column label="SKU ID" prop="skuId" width="80" align="center" />
            <el-table-column label="规格" prop="specName" min-width="110" :show-overflow-tooltip="true">
              <template #default="scope">{{ scope.row.specName || '—' }}</template>
            </el-table-column>
            <el-table-column label="SKU 编码" prop="skuCode" min-width="140" :show-overflow-tooltip="true">
              <template #default="scope">{{ scope.row.skuCode || '—' }}</template>
            </el-table-column>
            <el-table-column label="售价" width="100" align="right">
              <template #default="scope">
                <mall-money :value="scope.row.price" />
              </template>
            </el-table-column>
            <el-table-column label="库存" width="90" align="right">
              <template #default="scope">
                <span :class="{ 'stock-zero': Number(scope.row.stock) === 0 }">{{ scope.row.stock ?? 0 }}</span>
              </template>
            </el-table-column>
            <el-table-column label="SKU 状态" width="100" align="center">
              <template #default="scope">
                <mall-status-tag :dict="SKU_STATUS" :value="scope.row.skuStatus" />
              </template>
            </el-table-column>
            <el-table-column label="商品状态" width="100" align="center">
              <template #default="scope">
                <mall-status-tag :dict="ITEM_STATUS" :value="scope.row.itemStatus" />
              </template>
            </el-table-column>
            <el-table-column label="审核状态" width="100" align="center">
              <template #default="scope">
                <mall-status-tag :dict="AUDIT_STATUS" :value="scope.row.auditStatus" />
              </template>
            </el-table-column>
            <el-table-column label="操作" width="90" align="center" fixed="right">
              <template #default="scope">
                <el-button
                  link
                  type="primary"
                  icon="Edit"
                  v-hasPermi="['mall:merchant:item:edit']"
                  @click="handleAdjustStock(scope.row)"
                >调整</el-button>
              </template>
            </el-table-column>
          </el-table>
          <div class="stock-total">共 {{ stockDrawer.stockRows.length }} 条</div>
        </el-tab-pane>

        <el-tab-pane label="库存流水" name="logs">
          <el-form :inline="true" class="logs-query">
            <el-form-item label="SKU">
              <el-select
                v-model="stockDrawer.logsQuery.skuId"
                placeholder="请选择本商品 SKU"
                clearable
                filterable
                style="width: 220px"
              >
                <el-option
                  v-for="sku in stockDrawer.stockRows"
                  :key="sku.skuId"
                  :label="`SKU #${sku.skuId} · ${sku.specName || '默认规格'}`"
                  :value="sku.skuId"
                />
              </el-select>
            </el-form-item>
            <el-form-item label="订单号">
              <el-input
                v-model="stockDrawer.logsQuery.orderNo"
                placeholder="订单号（精确）"
                clearable
                style="width: 190px"
                @keyup.enter="handleLogsQuery"
              />
            </el-form-item>
            <el-form-item label="类型">
              <el-select v-model="stockDrawer.logsQuery.type" placeholder="全部" clearable style="width: 150px">
                <el-option v-for="opt in stockLogTypeOptions" :key="opt.value" :label="opt.label" :value="opt.value" />
              </el-select>
            </el-form-item>
            <el-form-item>
              <el-button type="primary" icon="Search" :disabled="!canQueryLogs" :loading="stockDrawer.logsLoading" @click="handleLogsQuery">查询</el-button>
              <el-button icon="Refresh" @click="resetLogsQuery">重置</el-button>
            </el-form-item>
          </el-form>
          <el-alert
            class="mb8"
            type="warning"
            :closable="false"
            title="为规避越权，库存流水查询必须至少指定「SKU」或「订单号」之一；默认已预填本商品第一个 SKU。"
          />

          <el-table
            v-loading="stockDrawer.logsLoading"
            :data="stockDrawer.logsList"
            size="small"
            border
            :empty-text="stockDrawer.logsLoaded ? '暂无库存流水' : '请选择 SKU 或输入订单号后查询'"
          >
            <el-table-column label="流水ID" prop="id" width="85" align="center" />
            <el-table-column label="SKU ID" prop="skuId" width="80" align="center" />
            <el-table-column label="订单号" min-width="170" :show-overflow-tooltip="true">
              <template #default="scope">{{ scope.row.orderNo || '手工调整' }}</template>
            </el-table-column>
            <el-table-column label="类型" width="110" align="center">
              <template #default="scope">
                <mall-status-tag :dict="STOCK_LOG_TYPE" :value="scope.row.type" :fallback="scope.row.type || ''" />
              </template>
            </el-table-column>
            <el-table-column label="变更量" width="90" align="right">
              <template #default="scope">
                <span :class="qtyClass(scope.row.changeQty)">{{ formatChangeQty(scope.row.changeQty) }}</span>
              </template>
            </el-table-column>
            <el-table-column label="库存变化" width="120" align="center">
              <template #default="scope">{{ scope.row.beforeQty }} → {{ scope.row.afterQty }}</template>
            </el-table-column>
            <el-table-column label="操作人" width="100" align="center">
              <template #default="scope">{{ formatOperator(scope.row.operator) }}</template>
            </el-table-column>
            <el-table-column label="备注" min-width="140" :show-overflow-tooltip="true">
              <template #default="scope">{{ scope.row.remark || '—' }}</template>
            </el-table-column>
            <el-table-column label="时间" width="160" align="center">
              <template #default="scope">{{ parseTime(scope.row.createTime) || '—' }}</template>
            </el-table-column>
          </el-table>
          <div class="stock-total">共 {{ stockDrawer.logsList.length }} 条</div>
        </el-tab-pane>
      </el-tabs>

      <stock-adjust-dialog
        v-model:visible="stockDrawer.adjustVisible"
        :row="stockDrawer.adjustRow || {}"
        :merchant="true"
        @adjusted="handleStockAdjusted"
      />
    </el-drawer>
  </div>
</template>

<script setup name="MerchantItems">
import {
  listMyItems,
  getMyItem,
  updateMyItemStatus,
  listMyStock,
  listMyStockLogs
} from '@/api/mall/merchant'
import { listHomeCategories } from '@/api/mall/category'
import {
  AUDIT_STATUS,
  ITEM_STATUS,
  SKU_STATUS,
  STOCK_LOG_TYPE,
  PET_SPECIES,
  AGE_STAGE,
  buildCategoryMap,
  dictLabel,
  optionsOf
} from '@/utils/mallDict'
import ItemFormDrawer from '@/components/mall/ItemFormDrawer.vue'
import StockAdjustDialog from '@/components/mall/StockAdjustDialog.vue'
import MallStatusTag from '@/components/mall/MallStatusTag.vue'
import MallMoney from '@/components/mall/MallMoney.vue'
import CategoryTreeSelect from '@/components/mall/CategoryTreeSelect.vue'

const { proxy } = getCurrentInstance()
const route = useRoute()
const router = useRouter()
const pagePath = route.path

const auditStatusOptions = optionsOf(AUDIT_STATUS)
const itemStatusOptions = optionsOf(ITEM_STATUS)
const stockLogTypeOptions = optionsOf(STOCK_LOG_TYPE)

const loading = ref(false)
const showSearch = ref(true)
const itemList = ref([])
const total = ref(0)
/** 空态原因：'' | 'merchant'（未绑定商家） | 'failed'（加载失败） */
const loadError = ref('')
const categoryTree = ref([])
const categoryMap = ref({})

const queryParams = reactive({
  pageNum: 1,
  pageSize: 10,
  keyword: undefined,
  categoryId: undefined,
  auditStatus: undefined,
  status: undefined
})

const columns = ref({
  mainImage: { label: '主图', visible: true },
  id: { label: '商品ID', visible: true },
  title: { label: '商品标题', visible: true },
  categoryId: { label: '类目', visible: true },
  priceMin: { label: '价格起', visible: true },
  auditStatus: { label: '审核状态', visible: true },
  status: { label: '上下架', visible: true },
  sales: { label: '销量', visible: true },
  updateTime: { label: '更新时间', visible: true }
})

/* 发布/编辑抽屉 */
const formDrawer = reactive({
  visible: false,
  editId: null
})

/* 详情抽屉 */
const detailDrawer = reactive({
  visible: false,
  loading: false,
  detail: null
})

/* 库存抽屉（M9–M11） */
const stockDrawer = reactive({
  visible: false,
  itemId: null,
  title: '',
  activeTab: 'sku',
  stockRows: [],
  stockLoading: false,
  logsList: [],
  logsLoading: false,
  logsLoaded: false,
  logsQuery: {
    skuId: undefined,
    orderNo: undefined,
    type: undefined
  },
  adjustVisible: false,
  adjustRow: null
})

const canAdd = computed(() => proxy.$auth.hasPermi('mall:merchant:item:add'))

const hasFilter = computed(() => {
  return (
    !!queryParams.keyword ||
    (queryParams.categoryId !== undefined && queryParams.categoryId !== null) ||
    (queryParams.auditStatus !== undefined && queryParams.auditStatus !== null) ||
    (queryParams.status !== undefined && queryParams.status !== null)
  )
})

const detailImages = computed(() => {
  const detail = detailDrawer.detail
  if (!detail) return []
  const list = []
  if (detail.mainImage) list.push(detail.mainImage)
  if (Array.isArray(detail.images)) {
    detail.images
      .slice()
      .sort((a, b) => (a?.sort ?? 0) - (b?.sort ?? 0))
      .forEach(img => {
        if (img?.url && !list.includes(img.url)) list.push(img.url)
      })
  }
  return list
})

/* 流水查询必须至少一个条件（skuId 或 orderNo），否则后端无商家过滤会返回全平台流水 */
const canQueryLogs = computed(() => {
  const skuId = stockDrawer.logsQuery.skuId
  const orderNo = (stockDrawer.logsQuery.orderNo || '').trim()
  return !!(skuId || orderNo)
})

/* ------------------------------ 路由 query 同步 ------------------------------ */

function pickNumber(value) {
  if (value === undefined || value === null || value === '') return undefined
  const num = Number(value)
  return Number.isNaN(num) ? undefined : num
}

function initQueryFromRoute() {
  const q = route.query
  queryParams.keyword = typeof q.keyword === 'string' && q.keyword ? q.keyword : undefined
  queryParams.categoryId = pickNumber(q.categoryId)
  queryParams.auditStatus = pickNumber(q.auditStatus)
  queryParams.status = pickNumber(q.status)
  queryParams.pageNum = pickNumber(q.pageNum) || 1
  queryParams.pageSize = pickNumber(q.pageSize) || 10
}

/** 当前筛选对应的 URL query（值统一为字符串） */
function currentQuery() {
  const query = {
    pageNum: String(queryParams.pageNum),
    pageSize: String(queryParams.pageSize)
  }
  if (queryParams.keyword) query.keyword = String(queryParams.keyword)
  if (queryParams.categoryId !== undefined && queryParams.categoryId !== null && queryParams.categoryId !== '') {
    query.categoryId = String(queryParams.categoryId)
  }
  if (queryParams.auditStatus !== undefined && queryParams.auditStatus !== null && queryParams.auditStatus !== '') {
    query.auditStatus = String(queryParams.auditStatus)
  }
  if (queryParams.status !== undefined && queryParams.status !== null && queryParams.status !== '') {
    query.status = String(queryParams.status)
  }
  return query
}

/** 是否与当前筛选一致（避免自身写 URL 触发重复查询/死循环） */
function isSameQuery(query, target) {
  const keys = Object.keys(query)
  if (keys.length !== Object.keys(target).length) return false
  return keys.every(key => String(query[key]) === String(target[key]))
}

/** 筛选/分页同步到 URL（刷新保持） */
function syncQueryToRoute() {
  const query = currentQuery()
  if (isSameQuery(route.query, query)) return
  router.replace({ path: pagePath, query }).catch(() => {})
}

/* ------------------------------ 数据加载 ------------------------------ */

/** 类目树/映射统一用匿名公开接口（商家无 mall:category:list，禁止调 /api/admin/categories） */
async function loadCategories() {
  try {
    const res = await listHomeCategories()
    categoryTree.value = Array.isArray(res) ? res : []
    categoryMap.value = buildCategoryMap(categoryTree.value)
  } catch (error) {
    categoryTree.value = []
    categoryMap.value = {}
  }
}

async function getList() {
  loading.value = true
  loadError.value = ''
  syncQueryToRoute()
  try {
    const res = await listMyItems(cleanParams(queryParams))
    itemList.value = Array.isArray(res?.list) ? res.list : []
    total.value = Number(res?.total) || 0
  } catch (error) {
    itemList.value = []
    total.value = 0
    loadError.value = error?.errorCode === 'PET-2003' ? 'merchant' : 'failed'
  } finally {
    loading.value = false
  }
}

/** 去掉空串/null/undefined，避免 axios 序列化出空参数（后端按未传处理） */
function cleanParams(params) {
  const result = {}
  Object.keys(params).forEach(key => {
    const value = params[key]
    if (value !== undefined && value !== null && value !== '') {
      result[key] = value
    }
  })
  return result
}

function categoryName(categoryId) {
  if (categoryId === null || categoryId === undefined || categoryId === '') return '—'
  return categoryMap.value[categoryId] || `#${categoryId}`
}

/* ------------------------------ 查询/重置/分页 ------------------------------ */

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
  queryParams.pageNum = 1
  getList()
}

/* ------------------------------ 发布 / 编辑 ------------------------------ */

function handleAdd() {
  formDrawer.editId = null
  formDrawer.visible = true
}

function handleEdit(row) {
  const open = () => {
    formDrawer.editId = row.id
    formDrawer.visible = true
  }
  if (row.status === 1) {
    proxy.$modal
      .confirm('编辑在售商品将重新待审并自动下架，前台不可见。确认继续编辑？')
      .then(open)
      .catch(() => {})
  } else {
    open()
  }
}

function handleFormSaved() {
  // 成功提示由 ItemFormDrawer 统一处理（admin/merchant 文案不同），页面只负责刷新
  formDrawer.visible = false
  formDrawer.editId = null
  getList()
}

/* ------------------------------ 详情抽屉 ------------------------------ */

async function handleDetail(row) {
  detailDrawer.detail = null
  detailDrawer.visible = true
  detailDrawer.loading = true
  try {
    const res = await getMyItem(row.id)
    detailDrawer.detail = res || null
  } catch (error) {
    detailDrawer.visible = false
    if (error?.errorCode === 'PET-2003' || error?.errorCode === 'PET-3003') {
      getList()
    }
  } finally {
    detailDrawer.loading = false
  }
}

/* ------------------------------ 上下架 ------------------------------ */

async function handleStatusChange(row) {
  const targetStatus = row.status === 1 ? 0 : 1
  if (targetStatus === 1 && row.auditStatus !== 2) {
    proxy.$modal.msgWarning('商品未审核通过，不能上架')
    return
  }
  const actionName = targetStatus === 1 ? '上架' : '下架'
  const tip =
    targetStatus === 1
      ? `确认上架「${row.title}」？上架后前台可见。`
      : `确认下架「${row.title}」？下架后前台不可见。`
  try {
    await proxy.$modal.confirm(tip)
  } catch (error) {
    return
  }
  row._statusLoading = true
  try {
    await updateMyItemStatus(row.id, targetStatus)
    proxy.$modal.msgSuccess(`${actionName}成功`)
    getList()
  } catch (error) {
    // 请求层已提示；状态类错误刷新列表同步真实状态
    if (['PET-3003', 'PET-2003', 'PET-3002'].includes(error?.errorCode)) {
      getList()
    }
  } finally {
    row._statusLoading = false
  }
}

/* ------------------------------ 库存抽屉（M9–M11） ------------------------------ */

async function handleOpenStock(row) {
  stockDrawer.itemId = row.id
  stockDrawer.title = row.title
  stockDrawer.activeTab = 'sku'
  stockDrawer.stockRows = []
  stockDrawer.logsList = []
  stockDrawer.logsLoaded = false
  stockDrawer.logsQuery.skuId = undefined
  stockDrawer.logsQuery.orderNo = undefined
  stockDrawer.logsQuery.type = undefined
  stockDrawer.adjustRow = null
  stockDrawer.adjustVisible = false
  stockDrawer.visible = true
  await loadStockRows()
}

function handleStockDrawerClosed() {
  stockDrawer.adjustVisible = false
  stockDrawer.adjustRow = null
}

async function loadStockRows() {
  if (!stockDrawer.itemId) return
  stockDrawer.stockLoading = true
  try {
    const res = await listMyStock({ itemId: stockDrawer.itemId })
    stockDrawer.stockRows = Array.isArray(res) ? res : []
    // 流水查询默认预填本商品第一个 SKU（仍允许手选/改订单号）
    if (!stockDrawer.logsQuery.skuId && stockDrawer.stockRows.length > 0) {
      stockDrawer.logsQuery.skuId = stockDrawer.stockRows[0].skuId
    }
    // 用户在 SKU 加载完成前已切到流水 tab：预填后补一次查询（避免空态停留）
    if (stockDrawer.activeTab === 'logs' && !stockDrawer.logsLoaded && canQueryLogs.value) {
      getStockLogs()
    }
  } catch (error) {
    stockDrawer.stockRows = []
  } finally {
    stockDrawer.stockLoading = false
  }
}

function refreshStockTab() {
  if (stockDrawer.activeTab === 'logs') {
    if (canQueryLogs.value) {
      getStockLogs()
    }
  } else {
    loadStockRows()
  }
}

function handleStockTabChange(name) {
  if (name === 'logs' && !stockDrawer.logsLoaded && canQueryLogs.value) {
    getStockLogs()
  }
}

function handleAdjustStock(row) {
  stockDrawer.adjustRow = row
  stockDrawer.adjustVisible = true
}

async function handleStockAdjusted() {
  // 调整成功 / PET-3001 并发不足：重拉库存并同步弹窗当前行（弹窗可能保持打开），
  // 流水已查询过则按当前条件同步重拉
  const adjustingSkuId = stockDrawer.adjustRow?.skuId
  await loadStockRows()
  if (adjustingSkuId !== undefined && adjustingSkuId !== null) {
    const latest = stockDrawer.stockRows.find(row => row.skuId === adjustingSkuId)
    if (latest) stockDrawer.adjustRow = latest
  }
  if (stockDrawer.logsLoaded && canQueryLogs.value) {
    getStockLogs()
  }
}

async function getStockLogs() {
  const skuId = stockDrawer.logsQuery.skuId
  const orderNo = (stockDrawer.logsQuery.orderNo || '').trim()
  if (!skuId && !orderNo) {
    stockDrawer.logsList = []
    return
  }
  stockDrawer.logsLoading = true
  stockDrawer.logsLoaded = true
  try {
    const res = await listMyStockLogs({
      skuId: skuId || undefined,
      orderNo: orderNo || undefined,
      type: stockDrawer.logsQuery.type || undefined
    })
    stockDrawer.logsList = Array.isArray(res) ? res : []
  } catch (error) {
    stockDrawer.logsList = []
  } finally {
    stockDrawer.logsLoading = false
  }
}

function handleLogsQuery() {
  if (!canQueryLogs.value) {
    proxy.$modal.msgWarning('请先选择 SKU 或输入订单号（至少一个条件）')
    return
  }
  getStockLogs()
}

function resetLogsQuery() {
  stockDrawer.logsQuery.skuId = stockDrawer.stockRows.length > 0 ? stockDrawer.stockRows[0].skuId : undefined
  stockDrawer.logsQuery.orderNo = undefined
  stockDrawer.logsQuery.type = undefined
  stockDrawer.logsList = []
  stockDrawer.logsLoaded = false
}

/* ------------------------------ 流水展示辅助 ------------------------------ */

function formatChangeQty(value) {
  const num = Number(value)
  if (Number.isNaN(num) || num === 0) return '0'
  return num > 0 ? `+${num}` : `${num}`
}

function qtyClass(value) {
  const num = Number(value)
  if (Number.isNaN(num) || num === 0) return ''
  return num > 0 ? 'qty-plus' : 'qty-minus'
}

function formatOperator(operator) {
  if (!operator) return '—'
  if (operator === 'system') return '系统'
  if (operator === 'seed') return '初始化'
  return operator
}

// keep-alive 下再次带参跳转（工作台/其他页 → 本页，如 /merchant/items?auditStatus=0）时回填并重查
watch(
  () => route.fullPath,
  () => {
    if (route.path !== pagePath) return
    if (isSameQuery(route.query, currentQuery())) return
    initQueryFromRoute()
    getList()
  }
)

initQueryFromRoute()
onMounted(loadCategories)
getList()
</script>

<style lang="scss" scoped>
.image-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.drawer-body {
  min-height: 200px;
}

.drawer-section-title {
  margin: 18px 0 10px;
  font-weight: 600;
  color: var(--el-text-color-primary);
}

.detail-html {
  max-height: 320px;
  overflow: auto;
  padding: 8px 12px;
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 4px;
  line-height: 1.7;
  color: var(--el-text-color-regular);
  word-break: break-word;
}

.stock-drawer-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-right: 24px;
}

.stock-drawer-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--el-text-color-primary);
}

.stock-drawer-sub {
  margin-left: 10px;
  font-size: 12px;
  color: var(--el-text-color-secondary);
}

.stock-total {
  margin-top: 8px;
  font-size: 12px;
  color: var(--el-text-color-secondary);
  text-align: right;
}

.stock-zero {
  font-weight: 600;
  color: var(--el-color-danger);
}

.logs-query {
  margin-bottom: 4px;
}

.qty-plus {
  color: var(--el-color-success);
  font-weight: 600;
}

.qty-minus {
  color: var(--el-color-danger);
  font-weight: 600;
}

.mt16 {
  margin-top: 16px;
}
</style>
