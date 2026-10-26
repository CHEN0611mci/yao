<template>
  <div class="app-container">
    <el-alert
      title="只读审计视图（sys_oper_log）：不支持删除 / 修改 / 导出；如需系统级审计请前往「系统监控 → 操作日志」。"
      type="info"
      :closable="false"
      show-icon
      class="mb8"
    />

    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch" label-width="80px">
      <el-form-item label="系统模块" prop="title">
        <el-select
          v-model="queryParams.title"
          placeholder="请选择或输入系统模块"
          clearable
          filterable
          allow-create
          default-first-option
          style="width: 220px"
        >
          <el-option v-for="item in moduleOptions" :key="item" :label="item" :value="item" />
        </el-select>
      </el-form-item>
      <el-form-item label="操作人" prop="operName">
        <el-input
          v-model="queryParams.operName"
          placeholder="请输入操作人登录名"
          clearable
          style="width: 180px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="操作类型" prop="businessType">
        <el-select v-model="queryParams.businessType" placeholder="请选择操作类型" clearable style="width: 160px">
          <el-option
            v-for="item in businessTypeOptions"
            :key="item.value"
            :label="item.label"
            :value="item.value"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择状态" clearable style="width: 140px">
          <el-option
            v-for="item in statusOptions"
            :key="item.value"
            :label="item.label"
            :value="item.value"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="操作时间">
        <el-date-picker
          v-model="dateRange"
          value-format="YYYY-MM-DD HH:mm:ss"
          type="datetimerange"
          range-separator="-"
          start-placeholder="开始时间"
          end-placeholder="结束时间"
          :default-time="[new Date(2000, 0, 1, 0, 0, 0), new Date(2000, 0, 1, 23, 59, 59)]"
          style="width: 380px"
        />
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5">
        <el-button plain icon="Refresh" @click="getList">刷新</el-button>
      </el-col>
      <right-toolbar
        v-model:showSearch="showSearch"
        :columns="columns"
        storage-key="mall-auditlog"
        @queryTable="getList"
      />
    </el-row>

    <el-alert
      v-if="loadError"
      title="审计日志加载失败"
      type="error"
      :closable="false"
      show-icon
      class="mb8"
    >
      <template #default>
        <el-button link type="primary" icon="Refresh" @click="getList">重试</el-button>
      </template>
    </el-alert>

    <el-table v-loading="loading" :data="list">
      <el-table-column v-if="columns.operId.visible" label="日志ID" prop="operId" width="90" align="center" />
      <el-table-column
        v-if="columns.title.visible"
        label="系统模块"
        prop="title"
        width="150"
        align="left"
        :show-overflow-tooltip="true"
      />
      <el-table-column v-if="columns.businessType.visible" label="操作类型" width="110" align="center">
        <template #default="scope">
          <dict-tag :options="sys_oper_type" :value="scope.row.businessType" />
        </template>
      </el-table-column>
      <el-table-column
        v-if="columns.operName.visible"
        label="操作人"
        prop="operName"
        width="110"
        align="center"
        :show-overflow-tooltip="true"
      />
      <el-table-column
        v-if="columns.deptName.visible"
        label="部门"
        prop="deptName"
        width="130"
        align="left"
        :show-overflow-tooltip="true"
      />
      <el-table-column
        v-if="columns.requestMethod.visible"
        label="请求方式"
        prop="requestMethod"
        width="90"
        align="center"
      />
      <el-table-column v-if="columns.operIp.visible" label="操作地址" width="130" align="center">
        <template #default="scope">
          <el-tooltip v-if="scope.row.operLocation" :content="scope.row.operLocation" placement="top">
            <span>{{ scope.row.operIp || '—' }}</span>
          </el-tooltip>
          <span v-else>{{ scope.row.operIp || '—' }}</span>
        </template>
      </el-table-column>
      <el-table-column v-if="columns.status.visible" label="状态" width="90" align="center">
        <template #default="scope">
          <dict-tag :options="sys_common_status" :value="scope.row.status" />
        </template>
      </el-table-column>
      <el-table-column v-if="columns.operTime.visible" label="操作时间" width="160" align="center">
        <template #default="scope">
          <span>{{ parseTime(scope.row.operTime) }}</span>
        </template>
      </el-table-column>
      <el-table-column v-if="columns.costTime.visible" label="耗时" prop="costTime" width="90" align="right">
        <template #default="scope">
          <span>{{ scope.row.costTime === null || scope.row.costTime === undefined ? '—' : scope.row.costTime + ' ms' }}</span>
        </template>
      </el-table-column>
      <el-table-column
        v-if="columns.operation.visible"
        label="操作"
        width="90"
        align="center"
        class-name="small-padding fixed-width"
        fixed="right"
      >
        <template #default="scope">
          <el-button
            link
            type="primary"
            icon="View"
            @click="handleDetail(scope.row)"
            v-hasPermi="['mall:audit:list']"
          >详情</el-button>
        </template>
      </el-table-column>
      <template #empty>
        <el-empty :image-size="80" description="暂无审计日志">
          <div class="empty-tip">建议按操作时间范围或系统模块查询</div>
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

    <!-- 只读详情抽屉（使用当前行数据，不额外请求） -->
    <el-drawer v-model="detailOpen" title="审计日志详情" size="720px" direction="rtl" append-to-body>
      <div v-if="currentRow" class="audit-detail">
        <div class="detail-section-title">请求信息</div>
        <el-descriptions :column="2" border size="small">
          <el-descriptions-item label="日志ID">{{ currentRow.operId ?? '—' }}</el-descriptions-item>
          <el-descriptions-item label="系统模块">{{ currentRow.title || '—' }}</el-descriptions-item>
          <el-descriptions-item label="操作类型">
            <dict-tag :options="sys_oper_type" :value="currentRow.businessType" />
          </el-descriptions-item>
          <el-descriptions-item label="操作状态">
            <dict-tag :options="sys_common_status" :value="currentRow.status" />
          </el-descriptions-item>
          <el-descriptions-item label="请求方式">{{ currentRow.requestMethod || '—' }}</el-descriptions-item>
          <el-descriptions-item label="操作人">{{ currentRow.operName || '—' }}</el-descriptions-item>
          <el-descriptions-item label="所属部门">{{ currentRow.deptName || '—' }}</el-descriptions-item>
          <el-descriptions-item label="操作者类型">{{ operatorTypeLabel(currentRow.operatorType) }}</el-descriptions-item>
          <el-descriptions-item label="请求地址" :span="2">{{ currentRow.operUrl || '—' }}</el-descriptions-item>
          <el-descriptions-item label="操作方法" :span="2">
            <span class="mono">{{ currentRow.method || '—' }}</span>
          </el-descriptions-item>
        </el-descriptions>

        <div class="detail-section-title">来源 / 元信息</div>
        <el-descriptions :column="2" border size="small">
          <el-descriptions-item label="操作IP">{{ currentRow.operIp || '—' }}</el-descriptions-item>
          <el-descriptions-item label="操作地点">{{ currentRow.operLocation || '—' }}</el-descriptions-item>
          <el-descriptions-item label="操作时间">{{ parseTime(currentRow.operTime) }}</el-descriptions-item>
          <el-descriptions-item label="耗时">
            {{ currentRow.costTime === null || currentRow.costTime === undefined ? '—' : currentRow.costTime + ' ms' }}
          </el-descriptions-item>
        </el-descriptions>

        <div class="detail-section-title">请求参数</div>
        <el-scrollbar max-height="240px" class="json-scroll">
          <pre class="json-block">{{ formatJson(currentRow.operParam) }}</pre>
        </el-scrollbar>

        <div class="detail-section-title">返回结果</div>
        <el-scrollbar max-height="240px" class="json-scroll">
          <pre class="json-block">{{ formatJson(currentRow.jsonResult) }}</pre>
        </el-scrollbar>

        <template v-if="Number(currentRow.status) === 1">
          <div class="detail-section-title">异常信息</div>
          <el-alert type="error" :closable="false" show-icon>
            <template #title>
              <pre class="error-block">{{ currentRow.errorMsg || '—' }}</pre>
            </template>
          </el-alert>
        </template>
      </div>
      <el-empty v-else description="暂无日志数据" />
    </el-drawer>
  </div>
</template>

<script setup name="Audit-log">
import { listAuditLogs } from '@/api/mall/auditLog'
import { BUSINESS_TYPE, OPER_STATUS, optionsOf } from '@/utils/mallDict'

const { proxy } = getCurrentInstance()
const route = useRoute()
const router = useRouter()

// 系统字典（走若依请求层 /system/dict/data/type/*）：操作类型 sys_oper_type、状态 sys_common_status
const { sys_oper_type, sys_common_status } = useDict('sys_oper_type', 'sys_common_status')

// 系统模块候选（el-select filterable + allow-create，允许手输其它模块名）
const moduleOptions = [
  '商城-商品管理',
  '商城-商品审核',
  '商城-商家商品',
  '商城-类目管理',
  '商城-订单管理',
  '商城-商家订单',
  '商城-会员管理',
  '商城-库存管理',
  '商城-商家库存',
  '商城-补偿任务'
]

// 操作者类型（SysOperLog.operatorType，若依口径）
const OPERATOR_TYPE = { 0: '其他', 1: '后台用户', 2: '手机端用户' }

// 筛选下拉选项：优先用系统字典；字典未加载（为空）时回退常量，两个来源不混用同一列
const businessTypeOptions = computed(() => {
  const dicts = sys_oper_type.value || []
  if (dicts.length) {
    return dicts.map(item => ({ value: Number(item.value), label: item.label }))
  }
  return optionsOf(BUSINESS_TYPE)
})
const statusOptions = computed(() => {
  const dicts = sys_common_status.value || []
  if (dicts.length) {
    return dicts.map(item => ({ value: Number(item.value), label: item.label }))
  }
  return optionsOf(OPER_STATUS)
})

const loading = ref(false)
const loadError = ref(false)
const showSearch = ref(true)
const list = ref([])
const total = ref(0)
const dateRange = ref([])
const detailOpen = ref(false)
const currentRow = ref(null)

const columns = ref({
  operId: { label: '日志ID', visible: true },
  title: { label: '系统模块', visible: true },
  businessType: { label: '操作类型', visible: true },
  operName: { label: '操作人', visible: true },
  deptName: { label: '部门', visible: true },
  requestMethod: { label: '请求方式', visible: true },
  operIp: { label: '操作地址', visible: true },
  status: { label: '状态', visible: true },
  operTime: { label: '操作时间', visible: true },
  costTime: { label: '耗时', visible: true },
  operation: { label: '操作', visible: true }
})

/** URL query → 数字（空值返回 undefined） */
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

/** URL query 回填（进页只读一次） */
function initQuery() {
  const query = route.query || {}
  const pageNum = queryNumber(query.pageNum)
  const pageSize = queryNumber(query.pageSize)
  return {
    pageNum: pageNum && pageNum > 0 ? pageNum : 1,
    pageSize: pageSize && pageSize > 0 ? pageSize : 10,
    title: query.title || undefined,
    operName: query.operName || undefined,
    businessType: queryNumber(query.businessType),
    status: queryNumber(query.status)
  }
}

const queryParams = reactive({
  ...initQuery(),
  beginTime: undefined,
  endTime: undefined
})

/** 日期范围回填：beginTime/endTime 必须是顶层参数（若依的 params[...] 日期包装不适用） */
function initDateRange() {
  const { beginTime, endTime } = route.query || {}
  return beginTime && endTime ? [String(beginTime), String(endTime)] : []
}

dateRange.value = initDateRange()

/** 筛选 / 分页同步到 URL（刷新保持） */
function syncQuery() {
  const query = {}
  if (queryParams.title) query.title = queryParams.title
  if (queryParams.operName) query.operName = queryParams.operName
  if (queryParams.businessType !== undefined && queryParams.businessType !== null && queryParams.businessType !== '') {
    query.businessType = String(queryParams.businessType)
  }
  if (queryParams.status !== undefined && queryParams.status !== null && queryParams.status !== '') {
    query.status = String(queryParams.status)
  }
  if (queryParams.beginTime) query.beginTime = queryParams.beginTime
  if (queryParams.endTime) query.endTime = queryParams.endTime
  if (queryParams.pageNum > 1) query.pageNum = String(queryParams.pageNum)
  if (queryParams.pageSize !== 10) query.pageSize = String(queryParams.pageSize)
  router.replace({ path: route.path, query }).catch(() => {})
}

/** 查询审计日志（A21，PageResult：res.list/res.total） */
async function getList() {
  loading.value = true
  loadError.value = false
  // 日期放顶层参数：只传 10 位日期时后端补 00:00:00 / 23:59:59
  queryParams.beginTime = Array.isArray(dateRange.value) && dateRange.value.length === 2 ? dateRange.value[0] : undefined
  queryParams.endTime = Array.isArray(dateRange.value) && dateRange.value.length === 2 ? dateRange.value[1] : undefined
  syncQuery()
  try {
    const params = cleanParams({
      pageNum: queryParams.pageNum,
      pageSize: queryParams.pageSize,
      title: queryParams.title,
      operName: queryParams.operName,
      businessType: queryParams.businessType,
      status: queryParams.status,
      beginTime: queryParams.beginTime,
      endTime: queryParams.endTime
    })
    const res = await listAuditLogs(params)
    list.value = res?.list || []
    total.value = res?.total || 0
  } catch (e) {
    list.value = []
    total.value = 0
    loadError.value = true
  } finally {
    loading.value = false
  }
}

/** 搜索 */
function handleQuery() {
  queryParams.pageNum = 1
  getList()
}

/** 重置（日期范围 + 查询条件；日期仍以顶层参数传，不做 params 包装） */
function resetQuery() {
  proxy.resetForm('queryRef')
  dateRange.value = []
  queryParams.title = undefined
  queryParams.operName = undefined
  queryParams.businessType = undefined
  queryParams.status = undefined
  queryParams.beginTime = undefined
  queryParams.endTime = undefined
  queryParams.pageNum = 1
  getList()
}

/** 详情：使用当前行数据，不额外请求 */
function handleDetail(row) {
  currentRow.value = row
  detailOpen.value = true
}

function operatorTypeLabel(value) {
  if (value === null || value === undefined || value === '') return '—'
  return OPERATOR_TYPE[value] || String(value)
}

/** JSON 美化，解析失败降级展示原文 */
function formatJson(str) {
  if (str === null || str === undefined || str === '') return '—'
  if (typeof str === 'object') {
    try {
      return JSON.stringify(str, null, 2)
    } catch (e) {
      return String(str)
    }
  }
  try {
    return JSON.stringify(JSON.parse(str), null, 2)
  } catch (e) {
    return String(str)
  }
}

onMounted(() => {
  getList()
})
</script>

<style scoped lang="scss">
.audit-detail {
  padding: 0 4px 24px;
}

.detail-section-title {
  margin: 18px 0 10px;
  padding-left: 8px;
  border-left: 3px solid var(--el-color-primary);
  font-weight: 600;
  line-height: 1.2;
}

.detail-section-title:first-child {
  margin-top: 0;
}

.json-scroll {
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 4px;
  background-color: var(--el-fill-color-lighter);
}

.json-block {
  margin: 0;
  padding: 10px 12px;
  font-family: Consolas, Monaco, "Courier New", monospace;
  font-size: 12px;
  line-height: 1.6;
  white-space: pre-wrap;
  word-break: break-all;
  color: var(--el-text-color-primary);
}

.error-block {
  margin: 0;
  font-family: Consolas, Monaco, "Courier New", monospace;
  font-size: 12px;
  white-space: pre-wrap;
  word-break: break-all;
}

.mono {
  font-family: Consolas, Monaco, "Courier New", monospace;
  font-size: 12px;
}

.empty-tip {
  color: #909399;
  font-size: 12px;
}
</style>
