<template>
  <div class="app-container">
    <!-- 本地过滤：类目接口无查询参数，名称过滤/仅看启用全部在已拉取的树上做客户端过滤（不发请求） -->
    <el-form :model="filterForm" :inline="true" v-show="showSearch">
      <el-form-item label="类目名称">
        <el-input
          v-model="filterForm.name"
          placeholder="请输入类目名称（本地过滤）"
          clearable
          style="width: 240px"
          @keyup.enter="handleQuery"
          @clear="handleQuery"
        />
      </el-form-item>
      <el-form-item label="仅看启用">
        <el-switch v-model="filterForm.onlyEnabled" @change="handleQuery" />
      </el-form-item>
      <el-form-item>
        <el-button icon="RefreshLeft" @click="resetFilter">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5">
        <el-button
          type="primary"
          plain
          icon="Plus"
          @click="handleAdd()"
          v-hasPermi="['mall:category:add']"
        >新增类目</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button plain :icon="expandAll ? 'Fold' : 'Expand'" @click="toggleExpand">{{ expandAll ? '折叠' : '展开' }}</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button plain icon="Refresh" @click="getList">刷新</el-button>
      </el-col>
      <right-toolbar v-model:showSearch="showSearch" :columns="columns" storage-key="mall-category" @queryTable="getList" />
    </el-row>

    <el-alert
      v-if="loadError"
      title="类目加载失败"
      type="error"
      :closable="false"
      show-icon
      class="mb8"
    >
      <template #default>
        <el-button link type="primary" icon="Refresh" @click="getList">重试</el-button>
      </template>
    </el-alert>

    <el-table
      ref="tableRef"
      v-loading="loading"
      :data="tableData"
      row-key="id"
      :tree-props="{ children: 'children' }"
      :default-expand-all="expandAll"
    >
      <el-table-column
        v-if="columns.name.visible"
        label="类目名称"
        prop="name"
        width="260"
        align="left"
        :show-overflow-tooltip="true"
      >
        <template #default="scope">
          <span :class="{ 'root-name': isRoot(scope.row) }">{{ scope.row.name }}</span>
        </template>
      </el-table-column>
      <el-table-column v-if="columns.id.visible" label="类目ID" prop="id" width="90" align="center" />
      <el-table-column v-if="columns.icon.visible" label="图标" width="80" align="center">
        <template #default="scope">
          <image-preview v-if="scope.row.icon" :src="scope.row.icon" width="32px" height="32px" />
          <span v-else class="text-muted">无</span>
        </template>
      </el-table-column>
      <el-table-column v-if="columns.sort.visible" label="排序" prop="sort" width="80" align="center" />
      <el-table-column v-if="columns.petScope.visible" label="宠物范围" width="100" align="center">
        <template #default="scope">
          <span>{{ petScopeText(scope.row.petScope) }}</span>
        </template>
      </el-table-column>
      <el-table-column v-if="columns.status.visible" label="状态" width="90" align="center">
        <template #default="scope">
          <MallStatusTag :dict="CATEGORY_STATUS" :value="scope.row.status" />
        </template>
      </el-table-column>
      <el-table-column v-if="columns.createTime.visible" label="创建时间" width="160" align="center">
        <template #default="scope">
          <span>{{ parseTime(scope.row.createTime) }}</span>
        </template>
      </el-table-column>
      <el-table-column
        v-if="columns.operation.visible"
        label="操作"
        width="220"
        align="center"
        class-name="small-padding fixed-width"
        fixed="right"
      >
        <template #default="scope">
          <el-button
            v-if="isRoot(scope.row)"
            link
            type="primary"
            icon="Plus"
            @click="handleAdd(scope.row)"
            v-hasPermi="['mall:category:add']"
          >新增下级</el-button>
          <el-button
            link
            type="primary"
            icon="Edit"
            @click="handleUpdate(scope.row)"
            v-hasPermi="['mall:category:edit']"
          >编辑</el-button>
          <el-button
            link
            type="danger"
            icon="Delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['mall:category:remove']"
          >删除</el-button>
        </template>
      </el-table-column>
      <template #empty>
        <el-empty :image-size="80" :description="emptyText">
          <el-button
            v-if="!hasFilter"
            type="primary"
            icon="Plus"
            @click="handleAdd()"
            v-hasPermi="['mall:category:add']"
          >新增类目</el-button>
        </el-empty>
      </template>
    </el-table>

    <!-- 新增 / 编辑类目（CategoryRequest） -->
    <el-dialog
      :title="dialog.title"
      v-model="dialog.open"
      width="600px"
      append-to-body
      :close-on-click-modal="false"
      :close-on-press-escape="!dialog.submitting"
      :show-close="!dialog.submitting"
      @closed="handleDialogClosed"
    >
      <el-form
        ref="categoryRef"
        v-loading="detailLoading"
        :model="form"
        :rules="rules"
        :disabled="dialog.submitting"
        label-width="100px"
      >
        <el-form-item label="上级类目" prop="parentId" :error="serverErrors.parentId">
          <el-tree-select
            v-model="form.parentId"
            :data="parentOptions"
            :props="{ value: 'id', label: 'name', children: 'children' }"
            node-key="id"
            check-strictly
            :render-after-expand="false"
            :default-expand-all="true"
            clearable
            style="width: 100%"
            :disabled="parentDisabled"
            placeholder="不选则为一级类目"
          />
          <div class="form-tip">类目最多支持两级：上级只能选择一级类目</div>
        </el-form-item>
        <el-form-item label="类目名称" prop="name" :error="serverErrors.name">
          <el-input v-model="form.name" maxlength="50" show-word-limit placeholder="请输入类目名称" />
        </el-form-item>
        <el-form-item label="类目图标" prop="icon">
          <MallImageUpload v-model="form.icon" :limit="1" :disabled="dialog.submitting" />
        </el-form-item>
        <el-form-item label="排序" prop="sort">
          <el-input-number v-model="form.sort" :min="0" :precision="0" controls-position="right" />
          <span class="form-tip">数值越小越靠前</span>
        </el-form-item>
        <el-form-item label="适用宠物" prop="petScope">
          <el-select v-model="form.petScope" placeholder="请选择适用宠物" style="width: 100%">
            <el-option
              v-for="item in petScopeOptions"
              :key="item.value"
              :label="item.label"
              :value="item.value"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="状态" prop="status">
          <el-radio-group v-model="form.status">
            <el-radio :value="0">启用</el-radio>
            <el-radio :value="1">停用</el-radio>
          </el-radio-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" :loading="dialog.submitting" @click="submitForm">保 存</el-button>
          <el-button :disabled="dialog.submitting" @click="dialog.open = false">取 消</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="Categories">
import { listCategories, getCategory, createCategory, updateCategory, deleteCategory } from '@/api/mall/category'
import { PET_SCOPE, optionsOf } from '@/utils/mallDict'
import MallStatusTag from '@/components/mall/MallStatusTag.vue'
import MallImageUpload from '@/components/mall/MallImageUpload.vue'

const { proxy } = getCurrentInstance()

// 类目状态：0 启用 / 1 停用（列表只读，启停只能通过编辑表单修改）
const CATEGORY_STATUS = {
  0: { label: '启用', type: 'success' },
  1: { label: '停用', type: 'info' }
}

const petScopeOptions = optionsOf(PET_SCOPE).filter(item => item.value !== '')

const loading = ref(false)
const detailLoading = ref(false)
const loadError = ref(false)
const showSearch = ref(true)
const expandAll = ref(true)
const categoryTree = ref([])
const tableRef = ref(null)
const filterForm = ref({ name: '', onlyEnabled: false })

const columns = ref({
  name: { label: '类目名称', visible: true },
  id: { label: '类目ID', visible: true },
  icon: { label: '图标', visible: true },
  sort: { label: '排序', visible: true },
  petScope: { label: '宠物范围', visible: true },
  status: { label: '状态', visible: true },
  createTime: { label: '创建时间', visible: true },
  operation: { label: '操作', visible: true }
})

const form = ref({})
const rules = {
  name: [
    { required: true, message: '类目名称不能为空', trigger: 'blur' },
    { max: 50, message: '类目名称不能超过 50 个字符', trigger: 'blur' }
  ],
  parentId: [{ validator: validateParent, trigger: 'change' }],
  sort: [{ type: 'number', min: 0, message: '排序不能小于 0', trigger: 'change' }]
}

const dialog = reactive({ open: false, title: '', submitting: false })
const serverErrors = reactive({ parentId: '', name: '' })

const hasFilter = computed(() => !!String(filterForm.value.name || '').trim() || filterForm.value.onlyEnabled)
const emptyText = computed(() => (hasFilter.value ? '没有匹配的类目' : '暂无类目'))

/** 是否一级类目（后端 parentId=0/空） */
function isRoot(row) {
  return !row || row.parentId === null || row.parentId === undefined || Number(row.parentId) === 0
}

function petScopeText(scope) {
  return PET_SCOPE[scope || ''] || '通用'
}

/** 客户端过滤：名称（含子级命中保留父级）+ 仅看启用；不触发接口请求 */
const tableData = computed(() => {
  const keyword = String(filterForm.value.name || '').trim().toLowerCase()
  const onlyEnabled = filterForm.value.onlyEnabled
  const match = node => {
    if (!node) return false
    if (onlyEnabled && Number(node.status) !== 0) return false
    if (keyword && !String(node.name || '').toLowerCase().includes(keyword)) return false
    return true
  }
  const roots = []
  ;(categoryTree.value || []).forEach(root => {
    const children = (root.children || []).filter(match)
    if (match(root) || children.length > 0) {
      roots.push({ ...root, children })
    }
  })
  return roots
})

/** 上级类目下拉：顶级 + 一级类目（编辑时排除自身，避免选中自己/下级） */
const parentOptions = computed(() => {
  const firstLevel = (categoryTree.value || [])
    .filter(node => isRoot(node) && Number(node.id) !== Number(form.value.id))
    .map(node => ({ id: node.id, name: node.name }))
  return [{ id: 0, name: '顶级类目（无上级）', children: firstLevel }]
})

/** 有子类目的一级类目不允许改挂到其它类目下（否则会变成三级） */
const parentDisabled = computed(() => {
  const node = findCategoryNode(categoryTree.value, form.value.id)
  return !!(node && isRoot(node) && Array.isArray(node.children) && node.children.length > 0)
})

/** 在类目树中按 id 查找节点（使用原始树，避免本地过滤影响判断） */
function findCategoryNode(tree, id) {
  if (!id) return null
  for (const node of tree || []) {
    if (Number(node.id) === Number(id)) return node
  }
  return null
}

function validateParent(rule, value, callback) {
  if (form.value.id && value !== undefined && value !== null && Number(value) === Number(form.value.id)) {
    return callback(new Error('上级类目不能选择自己'))
  }
  if (parentDisabled.value && value !== 0 && value !== '' && value !== undefined && value !== null) {
    return callback(new Error('该一级类目下已有子类目，不能改为二级类目'))
  }
  callback()
}

/** 查询类目树（A8，无查询参数） */
async function getList() {
  loading.value = true
  loadError.value = false
  try {
    const res = await listCategories()
    categoryTree.value = Array.isArray(res) ? res : []
    await nextTick()
    applyExpand()
  } catch (e) {
    categoryTree.value = []
    loadError.value = true
  } finally {
    loading.value = false
  }
}

/** 按当前 expandAll 状态同步树表展开/折叠 */
function applyExpand() {
  const table = tableRef.value
  if (!table) return
  tableData.value.forEach(row => table.toggleRowExpansion(row, expandAll.value))
}

function toggleExpand() {
  expandAll.value = !expandAll.value
  applyExpand()
}

function handleQuery() {
  // 纯本地过滤：不调接口，同步展开状态
  nextTick(applyExpand)
}

function resetFilter() {
  filterForm.value = { name: '', onlyEnabled: false }
  nextTick(applyExpand)
}

/** 表单重置 */
function resetCategoryForm() {
  form.value = {
    id: undefined,
    parentId: 0,
    name: '',
    icon: '',
    sort: 0,
    petScope: 'ALL',
    status: 0
  }
  serverErrors.parentId = ''
  serverErrors.name = ''
  proxy.resetForm('categoryRef')
}

function handleDialogClosed() {
  resetCategoryForm()
  dialog.submitting = false
}

/** 新增类目 / 新增下级 */
function handleAdd(row) {
  resetCategoryForm()
  dialog.title = row ? '新增下级类目' : '新增类目'
  form.value.parentId = row ? row.id : 0
  dialog.open = true
}

/** 修改类目：先拉详情回填再打开 */
async function handleUpdate(row) {
  resetCategoryForm()
  dialog.title = '修改类目'
  dialog.open = true
  detailLoading.value = true
  try {
    const res = await getCategory(row.id)
    form.value = {
      id: res.id,
      parentId: res.parentId === null || res.parentId === undefined ? 0 : res.parentId,
      name: res.name,
      icon: res.icon || '',
      sort: res.sort === null || res.sort === undefined ? 0 : res.sort,
      petScope: res.petScope || 'ALL',
      status: res.status === null || res.status === undefined ? 0 : res.status
    }
  } catch (e) {
    dialog.open = false
    // 分类不存在（PET-1001）→ 列表可能已变更，刷新
    if (e?.errorCode === 'PET-1001') {
      getList()
    }
  } finally {
    detailLoading.value = false
  }
}

/** 提交新增/编辑 */
function submitForm() {
  if (detailLoading.value) return
  proxy.$refs['categoryRef'].validate(async valid => {
    if (!valid) return
    const payload = {
      parentId: form.value.parentId === undefined || form.value.parentId === null || form.value.parentId === '' ? 0 : form.value.parentId,
      name: String(form.value.name || '').trim(),
      icon: form.value.icon || '',
      sort: form.value.sort === undefined || form.value.sort === null ? 0 : form.value.sort,
      petScope: form.value.petScope || 'ALL',
      status: form.value.status === undefined || form.value.status === null ? 0 : form.value.status
    }
    dialog.submitting = true
    try {
      if (form.value.id) {
        await updateCategory(form.value.id, payload)
        proxy.$modal.msgSuccess('类目已更新')
      } else {
        await createCategory(payload)
        proxy.$modal.msgSuccess('类目已创建')
      }
      dialog.open = false
      await getList()
    } catch (e) {
      // 业务失败提示由请求层统一处理；这里把 PET-1001 文案定位到对应字段
      if (e?.errorCode === 'PET-1001') {
        const message = e.message || e.msg || ''
        if (message.includes('两级') || message.includes('父级')) {
          serverErrors.parentId = message
        } else if (message.includes('分类名') || message.includes('名称')) {
          serverErrors.name = message
        }
      }
    } finally {
      dialog.submitting = false
    }
  })
}

/** 删除类目（有子类/商品引用 → PET-1003） */
function handleDelete(row) {
  proxy.$modal
    .confirm(`确认删除类目「${row.name}」？将校验子类与商品引用`)
    .then(() => deleteCategory(row.id))
    .then(() => {
      proxy.$modal.msgSuccess('删除成功')
      getList()
    })
    .catch(e => {
      // 取消确认时 e 为 'cancel'；PET-1003 表示被引用：后端文案由请求层提示，这里刷新列表保持数据最新
      if (e?.errorCode === 'PET-1003') {
        getList()
      }
    })
}

watch(() => form.value.name, () => { serverErrors.name = '' })
watch(() => form.value.parentId, () => { serverErrors.parentId = '' })
watch(tableData, () => nextTick(applyExpand))

getList()
</script>

<style scoped lang="scss">
.root-name {
  font-weight: 600;
}

.form-tip {
  margin-left: 8px;
  color: #909399;
  font-size: 12px;
  line-height: 1.4;
}

.text-muted {
  color: #909399;
}
</style>
