<template>
  <el-dialog
    v-model="dialogVisible"
    title="库存调整"
    width="600px"
    append-to-body
    :close-on-click-modal="false"
    :close-on-press-escape="!submitting"
    :before-close="handleBeforeClose"
  >
    <el-alert
      v-if="staleStock"
      class="stock-desc"
      type="warning"
      :closable="false"
      show-icon
      title="库存已被并发变更，当前库存可能已变化；页面正在重拉库存，请以刷新后的数据为准，必要时关闭弹窗后重新调整。"
    />

    <el-descriptions v-if="row" :column="2" border size="small" class="stock-desc">
      <el-descriptions-item label="商品" :span="2">{{ row.title || '—' }}</el-descriptions-item>
      <el-descriptions-item label="规格">{{ row.specName || '—' }}</el-descriptions-item>
      <el-descriptions-item label="SKU 编码">{{ row.skuCode || '—' }}</el-descriptions-item>
      <el-descriptions-item label="SKU ID">{{ row.skuId ?? '—' }}</el-descriptions-item>
      <el-descriptions-item label="当前库存">
        <span class="current-stock">{{ currentStock }}</span>
      </el-descriptions-item>
    </el-descriptions>

    <el-form ref="adjustFormRef" :model="form" :rules="rules" label-width="96px" class="stock-form">
      <el-form-item label="目标库存" prop="targetStock">
        <el-input-number
          v-model="form.targetStock"
          :min="0"
          :step="1"
          :precision="0"
          :disabled="submitting"
          controls-position="right"
          placeholder="请输入目标库存"
          style="width: 100%"
        />
      </el-form-item>
      <el-form-item label="差异预览">
        <div class="diff-preview">
          <span class="diff-flow">{{ currentStock }} → {{ targetText }}</span>
          <el-tag v-if="changeNum > 0" type="success" size="small" disable-transitions>增加 {{ changeNum }}</el-tag>
          <el-tag v-else-if="changeNum < 0" type="danger" size="small" disable-transitions>减少 {{ Math.abs(changeNum) }}</el-tag>
          <el-tag v-else type="info" size="small" disable-transitions>无变化</el-tag>
        </div>
        <div v-if="changeNum === 0" class="diff-tip">{{ emptyTarget ? '请输入目标库存。' : '目标库存与当前库存一致，不会写入库存流水，无需提交。' }}</div>
      </el-form-item>
      <el-form-item label="备注" prop="remark">
        <el-input
          v-model="form.remark"
          type="textarea"
          :rows="3"
          maxlength="200"
          show-word-limit
          :disabled="submitting"
          placeholder="写入库存流水备注（选填，最多 200 字）"
        />
      </el-form-item>
    </el-form>

    <template #footer>
      <div class="dialog-footer">
        <el-button type="primary" :loading="submitting" :disabled="changeNum === 0" @click="handleSubmit">保 存</el-button>
        <el-button :disabled="submitting" @click="handleCancel">取 消</el-button>
      </div>
    </template>
  </el-dialog>
</template>

<script setup>
/**
 * 库存调整弹窗（A20 / M11 共用）
 *
 * - props.merchant=false 调 admin 调整接口 A20；true 调商家调整接口 M11
 * - targetStock 是「目标库存」而非增量；后端计算 change = targetStock - 当前库存
 * - change = 0 时后端不写流水，前端禁用提交；增加/减少库存均需二次确认（§5.8.5）
 * - 成功提示与关闭由本组件负责；失败保持弹窗（请求层已统一提示）
 *   PET-3001（库存不足以调整为目标值）属于并发变化，emit adjusted 让页面重拉库存
 */
import { adjustStock } from '@/api/mall/stock'
import { adjustMyStock } from '@/api/mall/merchant'

const props = defineProps({
  /* 是否显示 */
  visible: {
    type: Boolean,
    default: false
  },
  /* 库存行数据：skuId/title/specName/stock/skuCode 等 */
  row: {
    type: Object,
    default: () => ({})
  },
  /* 是否商家端（决定调用哪个调整接口） */
  merchant: {
    type: Boolean,
    default: false
  }
})

const emit = defineEmits(['update:visible', 'adjusted'])

const { proxy } = getCurrentInstance()

const adjustFormRef = ref(null)
const submitting = ref(false)
/** PET-3001（并发扣减导致库存不足）：弹窗保持打开，提示当前库存可能已变化 */
const staleStock = ref(false)

const form = reactive({
  targetStock: null,
  remark: ''
})

const rules = {
  targetStock: [
    { required: true, message: '目标库存不能为空', trigger: 'change' },
    {
      validator: (rule, value, callback) => {
        if (value === null || value === undefined || value === '') {
          callback(new Error('目标库存不能为空'))
          return
        }
        const num = Number(value)
        if (Number.isNaN(num)) {
          callback(new Error('目标库存必须为数字'))
          return
        }
        if (!Number.isInteger(num)) {
          callback(new Error('目标库存必须为整数'))
          return
        }
        if (num < 0) {
          callback(new Error('目标库存不能为负'))
          return
        }
        callback()
      },
      trigger: 'change'
    }
  ]
}

const dialogVisible = computed({
  get: () => props.visible,
  set: value => emit('update:visible', value)
})

const currentStock = computed(() => {
  const value = Number(props.row?.stock)
  return Number.isNaN(value) ? 0 : value
})

const targetText = computed(() => {
  const value = form.targetStock
  return value === null || value === undefined || value === '' ? '—' : value
})

const emptyTarget = computed(() => {
  return form.targetStock === null || form.targetStock === undefined || form.targetStock === ''
})

/* 差异预览：目标库存 - 当前库存（正数增加 / 负数减少 / 0 无变化） */
const changeNum = computed(() => {
  const target = Number(form.targetStock)
  if (form.targetStock === null || form.targetStock === undefined || form.targetStock === '' || Number.isNaN(target)) {
    return 0
  }
  return target - currentStock.value
})

watch(
  () => props.visible,
  visible => {
    if (visible) {
      resetForm()
    }
  }
)

watch(
  () => props.row?.skuId,
  () => {
    if (props.visible) {
      resetForm()
    }
  }
)

/** 打开弹窗时回到「目标库存=当前库存」 */
function resetForm() {
  form.targetStock = currentStock.value
  form.remark = ''
  staleStock.value = false
  nextTick(() => {
    adjustFormRef.value?.clearValidate()
  })
}

function handleBeforeClose(done) {
  if (submitting.value) return
  done()
}

function handleCancel() {
  if (submitting.value) return
  dialogVisible.value = false
}

function handleSubmit() {
  if (submitting.value) return
  adjustFormRef.value.validate(async valid => {
    if (!valid) return
    const skuId = props.row?.skuId
    if (!skuId) {
      proxy.$modal.msgError('缺少 SKU 信息，请刷新后重试')
      return
    }
    const targetStock = Number(form.targetStock)
    const change = targetStock - currentStock.value
    if (!Number.isInteger(targetStock) || targetStock < 0) return
    if (change === 0) {
      proxy.$modal.msgWarning('目标库存与当前库存一致，无需调整（不会写入流水）')
      return
    }
    // 每次实际调整（增加/减少）都必须二次确认（§5.8.5 页面行为；§6.6「减少时确认」以页面行为为准）
    const skuLabel = props.row?.skuCode || skuId
    const tip = `确认将 SKU ${skuLabel} 库存由 ${currentStock.value} 调整为 ${targetStock}？将写入库存流水。`
    try {
      await proxy.$modal.confirm(tip)
    } catch (e) {
      return
    }
    const payload = {
      targetStock,
      remark: form.remark ? form.remark.trim() : undefined
    }
    submitting.value = true
    try {
      const res = props.merchant ? await adjustMyStock(skuId, payload) : await adjustStock(skuId, payload)
      proxy.$modal.msgSuccess('库存已调整')
      emit('adjusted', res)
      dialogVisible.value = false
    } catch (error) {
      // 请求层已统一提示；弹窗保持打开
      if (error?.errorCode === 'PET-3001') {
        // 库存不足说明数据已被并发扣减，通知页面重拉库存（弹窗保持打开便于改小目标值）
        staleStock.value = true
        emit('adjusted', null)
      }
    } finally {
      submitting.value = false
    }
  })
}
</script>

<style lang="scss" scoped>
.stock-desc {
  margin-bottom: 16px;
}

.current-stock {
  font-weight: 600;
  color: var(--el-color-danger);
}

.stock-form {
  .diff-preview {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .diff-flow {
    color: var(--el-text-color-regular);
    font-variant-numeric: tabular-nums;
  }

  .diff-tip {
    margin-top: 4px;
    font-size: 12px;
    line-height: 1.5;
    color: var(--el-color-warning);
  }
}
</style>
