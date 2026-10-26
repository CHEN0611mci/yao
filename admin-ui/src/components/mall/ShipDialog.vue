<template>
  <el-dialog
    v-model="dialogVisible"
    title="订单发货"
    width="600px"
    append-to-body
    :close-on-click-modal="false"
    :close-on-press-escape="!submitting"
    :show-close="!submitting"
  >
    <el-form ref="shipFormRef" :model="form" :rules="rules" label-width="100px">
      <el-form-item label="订单号">
        <el-input :model-value="orderNo" disabled />
      </el-form-item>
      <el-form-item label="物流公司" prop="company">
        <el-select
          v-model="form.company"
          placeholder="请选择或输入物流公司"
          filterable
          allow-create
          default-first-option
          clearable
          maxlength="50"
          style="width: 100%"
          :disabled="submitting"
        >
          <el-option v-for="item in companyOptions" :key="item" :label="item" :value="item" />
        </el-select>
      </el-form-item>
      <el-form-item label="运单号" prop="trackingNo">
        <el-input
          v-model="form.trackingNo"
          placeholder="请输入运单号"
          maxlength="50"
          show-word-limit
          :disabled="submitting"
          @keyup.enter="handleSubmit"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <div class="dialog-footer">
        <el-button :disabled="submitting" @click="handleCancel">取 消</el-button>
        <el-button type="primary" :loading="submitting" @click="handleSubmit">确 定</el-button>
      </div>
    </template>
  </el-dialog>
</template>

<script setup>
import { SHIP_COMPANIES } from '@/utils/mallDict'
import { shipOrder } from '@/api/mall/order'
import { shipMyOrder } from '@/api/mall/merchant'

const props = defineProps({
  /* 是否显示弹窗 */
  visible: {
    type: Boolean,
    default: false
  },
  /* 订单号（字符串主键） */
  orderNo: {
    type: String,
    default: ''
  },
  /* 是否商家端（走 /api/merchant/orders/{orderNo}/ship） */
  merchant: {
    type: Boolean,
    default: false
  }
})

const emit = defineEmits(['update:visible', 'shipped', 'failed'])

const { proxy } = getCurrentInstance()

const shipFormRef = ref()
const submitting = ref(false)

const form = reactive({
  company: '',
  trackingNo: ''
})

const rules = {
  company: [
    { required: true, message: '物流公司不能为空', trigger: 'change' },
    { max: 50, message: '物流公司长度不能超过 50 个字符', trigger: 'change' }
  ],
  trackingNo: [
    { required: true, message: '运单号不能为空', trigger: 'blur' },
    { max: 50, message: '运单号长度不能超过 50 个字符', trigger: 'blur' }
  ]
}

// 物流公司候选：兼容常量数组/对象、元素为字符串或 { label, value } 对象两种形态
const companyOptions = computed(() => {
  const source = Array.isArray(SHIP_COMPANIES) ? SHIP_COMPANIES : Object.values(SHIP_COMPANIES || {})
  const list = source
    .map(item => {
      if (typeof item === 'string') return item
      return item?.label || item?.name || item?.value || ''
    })
    .filter(Boolean)
  return list.length ? list : ['顺丰速运', '中通快递', '圆通速递', '韵达快递', '京东物流', '邮政EMS']
})

const dialogVisible = computed({
  get: () => props.visible,
  set: value => emit('update:visible', value)
})

watch(
  () => props.visible,
  value => {
    if (value) resetForm()
  }
)

/** 重置表单 */
function resetForm() {
  form.company = ''
  form.trackingNo = ''
  nextTick(() => shipFormRef.value?.clearValidate())
}

/** 取消（提交中禁止关闭） */
function handleCancel() {
  if (submitting.value) return
  dialogVisible.value = false
}

/** 提交发货 */
async function handleSubmit() {
  if (submitting.value) return
  const valid = await shipFormRef.value?.validate().catch(() => false)
  if (!valid) return
  const company = (form.company || '').trim()
  const trackingNo = (form.trackingNo || '').trim()
  if (!company) {
    proxy.$modal.msgWarning('物流公司不能为空')
    return
  }
  if (!trackingNo) {
    proxy.$modal.msgWarning('运单号不能为空')
    return
  }
  const confirmText = props.merchant
    ? `确认为 ${props.orderNo} 发货？提交后进入待收货`
    : `确认为 ${props.orderNo} 发货？提交后进入待收货，不可撤销`
  const confirmed = await proxy.$modal
    .confirm(confirmText)
    .then(() => true)
    .catch(() => false)
  if (!confirmed) return
  submitting.value = true
  try {
    const payload = { company, trackingNo }
    const res = props.merchant ? await shipMyOrder(props.orderNo, payload) : await shipOrder(props.orderNo, payload)
    proxy.$modal.msgSuccess('发货成功')
    emit('shipped', res || { orderNo: props.orderNo, company, trackingNo, status: 3 })
    dialogVisible.value = false
  } catch (e) {
    // 错误文案由请求层统一提示；弹窗保持打开并保留输入，动作型错误码交页面刷新
    emit('failed', e)
  } finally {
    submitting.value = false
  }
}
</script>
