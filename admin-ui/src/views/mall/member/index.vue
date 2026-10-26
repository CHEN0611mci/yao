<template>
  <div class="app-container">
    <!-- 查询区 -->
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="关键字" prop="keyword">
        <el-input
          v-model="queryParams.keyword"
          placeholder="用户名 / 昵称 / 手机号"
          clearable
          style="width: 240px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="全部" clearable style="width: 160px">
          <el-option v-for="opt in memberStatusOptions" :key="opt.value" :label="opt.label" :value="opt.value" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <!-- 操作栏：无新增/无导出，仅刷新与列显隐 -->
    <el-row :gutter="10" class="mb8">
      <right-toolbar
        v-model:showSearch="showSearch"
        :columns="columns"
        storage-key="mall-member"
        @queryTable="getList"
      />
    </el-row>

    <!-- 数据区 -->
    <el-table v-loading="loading" :data="memberList" row-key="id">
      <el-table-column v-if="columns.id.visible" label="会员ID" prop="id" width="90" align="center" />
      <el-table-column v-if="columns.username.visible" label="用户名" width="130">
        <template #default="scope">
          <el-link type="primary" :underline="false" @click="handleDetail(scope.row)">{{ scope.row.username || '—' }}</el-link>
        </template>
      </el-table-column>
      <el-table-column v-if="columns.nickname.visible" label="昵称" prop="nickname" width="140" :show-overflow-tooltip="true">
        <template #default="scope">{{ scope.row.nickname || '—' }}</template>
      </el-table-column>
      <el-table-column v-if="columns.phone.visible" label="手机号" width="140" align="center">
        <template #header>
          <el-tooltip content="手机号由后端脱敏且不可逆，前台只展示脱敏串" placement="top">
            <span>手机号</span>
          </el-tooltip>
        </template>
        <template #default="scope">{{ scope.row.phone || '—' }}</template>
      </el-table-column>
      <el-table-column v-if="columns.avatar.visible" label="头像" width="80" align="center">
        <template #default="scope">
          <image-preview v-if="scope.row.avatar" :src="scope.row.avatar" width="32px" height="32px" />
          <span v-else>—</span>
        </template>
      </el-table-column>
      <el-table-column v-if="columns.status.visible" label="状态" width="100" align="center">
        <template #default="scope">
          <mall-status-tag :dict="MEMBER_STATUS" :value="scope.row.status" />
        </template>
      </el-table-column>
      <el-table-column v-if="columns.createTime.visible" label="注册时间" width="160" align="center">
        <template #default="scope">{{ parseTime(scope.row.createTime) || '—' }}</template>
      </el-table-column>
      <el-table-column v-if="columns.updateTime.visible" label="更新时间" width="160" align="center">
        <template #default="scope">{{ parseTime(scope.row.updateTime) || '—' }}</template>
      </el-table-column>
      <el-table-column label="操作" width="150" align="center" fixed="right" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button link type="primary" icon="View" @click="handleDetail(scope.row)">详情</el-button>
          <el-button
            v-if="scope.row.status === 0"
            link
            type="danger"
            icon="CircleClose"
            v-hasPermi="['mall:member:status']"
            :loading="statusLoadingId === scope.row.id"
            @click="handleStatusChange(scope.row)"
          >禁用</el-button>
          <el-button
            v-else-if="scope.row.status === 1"
            link
            type="success"
            icon="CircleCheck"
            v-hasPermi="['mall:member:status']"
            :loading="statusLoadingId === scope.row.id"
            @click="handleStatusChange(scope.row)"
          >启用</el-button>
        </template>
      </el-table-column>

      <template #empty>
        <el-empty v-if="loadError" description="会员列表加载失败">
          <el-button type="primary" icon="Refresh" @click="getList">重试</el-button>
        </el-empty>
        <el-empty v-else-if="hasFilter" description="没有符合条件的会员">
          <el-button icon="Refresh" @click="resetQuery">重置筛选</el-button>
        </el-empty>
        <el-empty v-else description="暂无会员" />
      </template>
    </el-table>

    <pagination
      v-show="total > 0"
      :total="total"
      v-model:page="queryParams.pageNum"
      v-model:limit="queryParams.pageSize"
      @pagination="getList"
    />

    <!-- 只读详情抽屉：后端无会员详情接口，仅展示当前列表行数据，不发起请求 -->
    <el-drawer
      v-model="detailDrawer.visible"
      :title="detailDrawer.row ? `会员详情 · ${detailDrawer.row.username || detailDrawer.row.id}` : '会员详情'"
      size="600px"
      direction="rtl"
      append-to-body
    >
      <div v-if="detailDrawer.row" class="drawer-body">
        <el-descriptions :column="2" border>
          <el-descriptions-item label="会员ID">{{ detailDrawer.row.id }}</el-descriptions-item>
          <el-descriptions-item label="状态">
            <mall-status-tag :dict="MEMBER_STATUS" :value="detailDrawer.row.status" />
          </el-descriptions-item>
          <el-descriptions-item label="用户名">{{ detailDrawer.row.username || '—' }}</el-descriptions-item>
          <el-descriptions-item label="昵称">{{ detailDrawer.row.nickname || '—' }}</el-descriptions-item>
          <el-descriptions-item label="手机号">{{ detailDrawer.row.phone || '—' }}</el-descriptions-item>
          <el-descriptions-item label="头像">
            <image-preview v-if="detailDrawer.row.avatar" :src="detailDrawer.row.avatar" width="40px" height="40px" />
            <span v-else>—</span>
          </el-descriptions-item>
          <el-descriptions-item label="注册时间">{{ parseTime(detailDrawer.row.createTime) || '—' }}</el-descriptions-item>
          <el-descriptions-item label="更新时间">{{ parseTime(detailDrawer.row.updateTime) || '—' }}</el-descriptions-item>
        </el-descriptions>

        <el-alert
          class="mt16"
          type="info"
          :closable="false"
          title="当前版本未提供会员详情/订单/地址/登录日志接口，以上信息来自会员列表；手机号由后端脱敏且不可逆。禁用后会员 Token 立即失效，需重新登录且登录被拒。"
        />
      </div>
    </el-drawer>
  </div>
</template>

<script setup name="Members">
import { listMembers, updateMemberStatus } from '@/api/mall/member'
import { MEMBER_STATUS, optionsOf } from '@/utils/mallDict'
import MallStatusTag from '@/components/mall/MallStatusTag.vue'

const { proxy } = getCurrentInstance()
const route = useRoute()
const router = useRouter()

const memberStatusOptions = optionsOf(MEMBER_STATUS)

const loading = ref(false)
const showSearch = ref(true)
const memberList = ref([])
const total = ref(0)
const loadError = ref(false)
const statusLoadingId = ref(null)

const queryParams = reactive({
  pageNum: 1,
  pageSize: 10,
  keyword: undefined,
  status: undefined
})

const columns = ref({
  id: { label: '会员ID', visible: true },
  username: { label: '用户名', visible: true },
  nickname: { label: '昵称', visible: true },
  phone: { label: '手机号', visible: true },
  avatar: { label: '头像', visible: false },
  status: { label: '状态', visible: true },
  createTime: { label: '注册时间', visible: true },
  updateTime: { label: '更新时间', visible: true }
})

const detailDrawer = reactive({
  visible: false,
  row: null
})

const hasFilter = computed(() => {
  return !!queryParams.keyword || (queryParams.status !== undefined && queryParams.status !== null)
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
  queryParams.status = pickNumber(q.status)
  queryParams.pageNum = pickNumber(q.pageNum) || 1
  queryParams.pageSize = pickNumber(q.pageSize) || 10
}

function syncQueryToRoute() {
  const query = {
    pageNum: String(queryParams.pageNum),
    pageSize: String(queryParams.pageSize)
  }
  if (queryParams.keyword) query.keyword = queryParams.keyword
  if (queryParams.status !== undefined && queryParams.status !== null && queryParams.status !== '') {
    query.status = String(queryParams.status)
  }
  // 与当前 URL 一致时不重复导航（避免无意义 replace）
  const currentKeys = Object.keys(route.query)
  const queryKeys = Object.keys(query)
  const same = currentKeys.length === queryKeys.length && queryKeys.every(key => String(route.query[key] ?? '') === query[key])
  if (same) return
  router.replace({ path: route.path, query }).catch(() => {})
}

/* ------------------------------ 数据加载 ------------------------------ */

async function getList() {
  loading.value = true
  loadError.value = false
  syncQueryToRoute()
  try {
    const res = await listMembers(cleanParams(queryParams))
    memberList.value = Array.isArray(res?.list) ? res.list : []
    total.value = Number(res?.total) || 0
  } catch (error) {
    memberList.value = []
    total.value = 0
    loadError.value = true
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

function handleQuery() {
  queryParams.pageNum = 1
  getList()
}

function resetQuery() {
  proxy.resetForm('queryRef')
  queryParams.keyword = undefined
  queryParams.status = undefined
  queryParams.pageNum = 1
  getList()
}

/* ------------------------------ 详情（纯前端行数据） ------------------------------ */

function handleDetail(row) {
  detailDrawer.row = row
  detailDrawer.visible = true
}

/* ------------------------------ 禁用 / 启用 ------------------------------ */

async function handleStatusChange(row) {
  const isDisable = row.status === 0
  const targetStatus = isDisable ? 1 : 0
  const tip = isDisable
    ? `禁用后会员「${row.username || row.id}」立即强制下线（Token 失效），需重新登录且登录被拒；进行中订单不受影响。确认？`
    : `确认恢复会员「${row.username || row.id}」的登录权限？`
  try {
    await proxy.$modal.confirm(tip)
  } catch (error) {
    return
  }
  statusLoadingId.value = row.id
  try {
    const res = await updateMemberStatus(row.id, targetStatus)
    // 以接口返回的会员为准（phone 仍脱敏、password 恒 null）
    if (res && typeof res === 'object') {
      Object.assign(row, res)
    } else {
      row.status = targetStatus
    }
    proxy.$modal.msgSuccess(isDisable ? '已禁用' : '已启用')
    getList()
  } catch (error) {
    if (error?.errorCode === 'PET-2003') {
      getList()
    }
  } finally {
    statusLoadingId.value = null
  }
}

initQueryFromRoute()
getList()
</script>

<style lang="scss" scoped>
.drawer-body {
  min-height: 200px;
}

.mt16 {
  margin-top: 16px;
}
</style>
