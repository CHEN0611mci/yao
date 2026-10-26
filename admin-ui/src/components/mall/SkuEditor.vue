<template>
  <div class="sku-editor">
    <el-table :data="rows" size="small" border :row-class-name="rowClassName" empty-text="暂无 SKU，请点击下方「添加规格」">
      <el-table-column label="规格名" min-width="150">
        <template #default="scope">
          <el-input
            :model-value="scope.row.specName"
            placeholder="如：2kg装"
            maxlength="50"
            :disabled="disabled"
            @update:model-value="val => updateField(scope.$index, 'specName', val)"
          />
        </template>
      </el-table-column>
      <el-table-column label="价格(元)" width="160">
        <template #default="scope">
          <el-input-number
            :model-value="scope.row.price"
            :precision="2"
            :min="0.01"
            :step="1"
            controls-position="right"
            placeholder="0.00"
            style="width: 100%"
            :disabled="disabled"
            @update:model-value="val => updateField(scope.$index, 'price', val)"
          />
        </template>
      </el-table-column>
      <el-table-column label="库存" width="140">
        <template #default="scope">
          <el-input-number
            :model-value="scope.row.stock"
            :min="0"
            :precision="0"
            :step="1"
            controls-position="right"
            style="width: 100%"
            :disabled="disabled"
            @update:model-value="val => updateField(scope.$index, 'stock', val)"
          />
        </template>
      </el-table-column>
      <el-table-column label="SKU 编码" min-width="170">
        <template #default="scope">
          <el-input
            :model-value="scope.row.skuCode"
            placeholder="选填，全平台唯一"
            maxlength="64"
            :disabled="disabled"
            :class="{ 'sku-code-error': serverCodeError }"
            @update:model-value="val => updateField(scope.$index, 'skuCode', val)"
          />
        </template>
      </el-table-column>
      <el-table-column label="状态" width="100" align="center">
        <template #default="scope">
          <el-switch
            :model-value="scope.row.status"
            :active-value="1"
            :inactive-value="0"
            active-text="启用"
            inactive-text="停用"
            inline-prompt
            :disabled="disabled"
            @update:model-value="val => updateField(scope.$index, 'status', val)"
          />
        </template>
      </el-table-column>
      <el-table-column v-if="!disabled" label="操作" width="80" align="center" fixed="right">
        <template #default="scope">
          <el-button link type="danger" icon="Delete" @click="handleRemove(scope.$index)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>

    <div class="sku-editor-footer">
      <el-button v-if="!disabled" type="primary" plain size="small" icon="Plus" @click="handleAdd">添加规格</el-button>
      <span class="sku-tip">至少需要 1 个 SKU；同一表单内「规格名」「SKU 编码」不可重复</span>
    </div>

    <el-alert
      v-if="serverCodeError"
      type="error"
      :closable="true"
      show-icon
      title="SKU 编码已存在，请修改后重试（同一编码全平台唯一）"
      class="sku-editor-alert"
      @close="serverCodeError = false"
    />
    <el-alert
      v-if="duplicateMessage"
      type="error"
      :closable="false"
      show-icon
      :title="duplicateMessage"
      class="sku-editor-alert"
    />
  </div>
</template>

<script setup>
/**
 * 受控 SKU 子表（设计文档 §5.3.6、§6.4、§6.6）
 *
 * - 完全受控：不持有业务状态，所有编辑通过 update:modelValue 回传新数组
 * - 本地校验：至少 1 行、规格名必填、价格 ≥ 0.01、库存 ≥ 0 整数、同表单 specName/skuCode 去重
 * - 父组件通过 ref.validate() 在提交前调用；PET-1002（skuCode 全平台重复）用 markDuplicateCode()
 * - status 0/1 由本组件编辑，行内可停用
 */
const props = defineProps({
  modelValue: {
    type: Array,
    default: () => []
  },
  disabled: {
    type: Boolean,
    default: false
  }
})

const emit = defineEmits(['update:modelValue'])

const { proxy } = getCurrentInstance()

// 服务端返回 PET-1002（skuCode 唯一键冲突）时的行内提示
const serverCodeError = ref(false)

const rows = computed(() => (Array.isArray(props.modelValue) ? props.modelValue : []))

function createEmptyRow() {
  return { specName: '', price: null, stock: 0, skuCode: '', status: 1 }
}

function cloneRow(row) {
  return {
    id: row.id,
    specName: row.specName ?? '',
    price: row.price ?? null,
    stock: row.stock ?? 0,
    skuCode: row.skuCode ?? '',
    image: row.image ?? '',
    status: row.status === 0 ? 0 : 1
  }
}

function updateRows(next) {
  emit('update:modelValue', next)
}

function updateField(index, key, value) {
  if (props.disabled) return
  const next = rows.value.map((row, i) => (i === index ? { ...row, [key]: value } : row))
  updateRows(next)
}

function handleAdd() {
  updateRows([...rows.value.map(cloneRow), createEmptyRow()])
  serverCodeError.value = false
}

function handleRemove(index) {
  if (props.disabled) return
  if (rows.value.length <= 1) {
    proxy.$modal.msgWarning('至少保留一个 SKU')
    return
  }
  updateRows(rows.value.filter((row, i) => i !== index))
}

function rowClassName({ row }) {
  return row && row.status === 0 ? 'sku-row-disabled' : ''
}

// 同表单去重：规格名（必填项）与 SKU 编码（选填项）
const duplicateMessage = computed(() => {
  const messages = []
  const nameMap = new Map()
  const codeMap = new Map()
  rows.value.forEach((row, index) => {
    const name = String(row.specName ?? '').trim()
    if (name) {
      if (!nameMap.has(name)) nameMap.set(name, [])
      nameMap.get(name).push(index + 1)
    }
    const code = String(row.skuCode ?? '').trim()
    if (code) {
      if (!codeMap.has(code)) codeMap.set(code, [])
      codeMap.get(code).push(index + 1)
    }
  })
  nameMap.forEach((indexes, name) => {
    if (indexes.length > 1) messages.push(`规格名不能重复：${name}（第 ${indexes.join('、')} 行）`)
  })
  codeMap.forEach((indexes, code) => {
    if (indexes.length > 1) messages.push(`SKU 编码不能重复：${code}（第 ${indexes.join('、')} 行）`)
  })
  return messages.join('；')
})

/**
 * 提交前校验
 * @returns {{valid: boolean, message: string}}
 */
function validate() {
  if (!rows.value.length) {
    return { valid: false, message: '至少需要一个 SKU' }
  }
  for (let i = 0; i < rows.value.length; i++) {
    const row = rows.value[i]
    const prefix = `第 ${i + 1} 行 SKU：`
    if (!String(row.specName ?? '').trim()) {
      return { valid: false, message: `${prefix}规格名不能为空` }
    }
    const price = Number(row.price)
    if (row.price === null || row.price === undefined || row.price === '' || Number.isNaN(price)) {
      return { valid: false, message: `${prefix}价格不能为空` }
    }
    if (price < 0.01) {
      return { valid: false, message: `${prefix}价格不能低于 0.01 元` }
    }
    const stock = Number(row.stock)
    if (row.stock === null || row.stock === undefined || row.stock === '' || Number.isNaN(stock)) {
      return { valid: false, message: `${prefix}库存不能为空` }
    }
    if (stock < 0) {
      return { valid: false, message: `${prefix}库存不能为负数` }
    }
    if (!Number.isInteger(stock)) {
      return { valid: false, message: `${prefix}库存必须为整数` }
    }
  }
  if (duplicateMessage.value) {
    return { valid: false, message: duplicateMessage.value }
  }
  return { valid: true, message: '' }
}

// PET-1002：SKU 编码全平台唯一键冲突，定位编码列
function markDuplicateCode() {
  serverCodeError.value = true
}

defineExpose({ validate, markDuplicateCode })
</script>

<style scoped>
.sku-editor {
  width: 100%;
}

.sku-editor-footer {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 8px;
}

.sku-tip {
  color: #909399;
  font-size: 12px;
}

.sku-editor-alert {
  margin-top: 8px;
}

:deep(.sku-row-disabled) {
  color: #b1b3b8;
  background-color: #fafafa;
}

:deep(.sku-code-error .el-input__wrapper) {
  box-shadow: 0 0 0 1px var(--el-color-danger) inset;
}
</style>
