<template>
  <el-drawer
    :model-value="visible"
    :title="drawerTitle"
    size="1000px"
    direction="rtl"
    append-to-body
    :close-on-click-modal="false"
    :before-close="handleBeforeClose"
    @update:model-value="handleVisibleChange"
  >
    <div v-loading="loading" class="audit-drawer-body">
      <template v-if="detail">
        <el-row :gutter="24">
          <!-- 左栏：商品资料（只读，含 SKU / 图片 / 审核留痕） -->
          <el-col :span="14">
            <div class="drawer-section-title">基本信息</div>
            <el-descriptions :column="2" border size="small">
              <el-descriptions-item label="商品标题" :span="2">{{ detail.title || '—' }}</el-descriptions-item>
              <el-descriptions-item label="副标题" :span="2">{{ detail.subtitle || '—' }}</el-descriptions-item>
              <el-descriptions-item label="商品ID">{{ detail.id ?? '—' }}</el-descriptions-item>
              <el-descriptions-item label="商家ID">{{ merchantLabel(detail.merchantId) }}</el-descriptions-item>
              <el-descriptions-item label="类目">{{ detail.categoryId ? `#${detail.categoryId}` : '—' }}</el-descriptions-item>
              <el-descriptions-item label="品牌">{{ detail.brand || '—' }}</el-descriptions-item>
              <el-descriptions-item label="适用宠物">{{ dictLabel(PET_SPECIES, detail.petSpecies) }}</el-descriptions-item>
              <el-descriptions-item label="适用年龄">{{ dictLabel(AGE_STAGE, detail.ageStage) }}</el-descriptions-item>
              <el-descriptions-item label="重量范围">{{ detail.weightRange || '—' }}</el-descriptions-item>
              <el-descriptions-item label="创建时间">{{ parseTime(detail.createTime) || '—' }}</el-descriptions-item>
              <el-descriptions-item label="价格起">
                <mall-money :value="detail.priceMin" />
              </el-descriptions-item>
              <el-descriptions-item label="成本价">
                <mall-money :value="detail.costPrice" />
              </el-descriptions-item>
              <el-descriptions-item label="商品标记" :span="2">
                <el-tag v-if="detail.supportSubscribe" type="success" size="small" class="mr8">支持订阅</el-tag>
                <el-tag v-if="detail.isPrescription" type="warning" size="small" class="mr8">处方商品</el-tag>
                <span v-if="!detail.supportSubscribe && !detail.isPrescription">—</span>
              </el-descriptions-item>
            </el-descriptions>

            <div class="drawer-section-title">商品图片</div>
            <div v-if="allImages.length" class="image-list">
              <image-preview v-for="(url, index) in allImages" :key="index" :src="url" width="72px" height="72px" />
            </div>
            <div v-else class="text-muted">暂无图片</div>

            <div class="drawer-section-title">商品详情</div>
            <div class="detail-html" v-html="detailHtml"></div>

            <div class="drawer-section-title">SKU 列表</div>
            <el-table :data="detail.skus || []" size="small" border :row-class-name="skuRowClassName" empty-text="暂无 SKU">
              <el-table-column label="规格名" prop="specName" min-width="120" show-overflow-tooltip />
              <el-table-column label="价格" width="100" align="right">
                <template #default="scope">
                  <mall-money :value="scope.row.price" />
                </template>
              </el-table-column>
              <el-table-column label="库存" prop="stock" width="80" align="center" />
              <el-table-column label="SKU 编码" prop="skuCode" min-width="140" show-overflow-tooltip />
              <el-table-column label="状态" width="90" align="center">
                <template #default="scope">
                  <mall-status-tag :dict="SKU_STATUS" :value="scope.row.status" />
                </template>
              </el-table-column>
            </el-table>

            <div class="drawer-section-title">审核历史</div>
            <el-timeline v-if="audits.length">
              <el-timeline-item
                v-for="audit in audits"
                :key="audit.id"
                :type="audit.auditStatus === 2 ? 'success' : 'danger'"
                :timestamp="parseTime(audit.createTime) || ''"
                placement="top"
              >
                <div class="audit-history-title">
                  <span :class="audit.auditStatus === 2 ? 'text-success' : 'text-danger'">
                    {{ dictLabel(AUDIT_STATUS, audit.auditStatus) }}
                  </span>
                  <span class="text-muted">审核人：{{ audit.auditor || '—' }}</span>
                </div>
                <div class="audit-history-remark">{{ audit.remark || '无审核意见' }}</div>
              </el-timeline-item>
            </el-timeline>
            <div v-else class="text-muted">暂无审核记录</div>
          </el-col>

          <!-- 右栏：审核表单（仅待审核商品） / 已审核只读说明 -->
          <el-col :span="10">
            <div class="drawer-section-title">审核结论</div>
            <template v-if="canAudit">
              <el-alert
                class="audit-tip"
                type="warning"
                :closable="false"
                show-icon
                title="审核通过 ≠ 自动上架：通过后仍需到「商品管理」手动上架；驳回将同时强制下架。审核结果会写入商品审核留痕。"
              />
              <el-form ref="auditFormRef" :model="auditForm" :rules="auditRules" label-width="90px" class="audit-form">
                <el-form-item label="审核结果" prop="auditStatus">
                  <el-radio-group v-model="auditForm.auditStatus" :disabled="submitting" @change="handleAuditStatusChange">
                    <el-radio :value="2">通过（通过后仍需手动上架）</el-radio>
                    <el-radio :value="1">驳回（同时下架）</el-radio>
                  </el-radio-group>
                </el-form-item>
                <el-form-item label="审核意见" prop="remark">
                  <el-input
                    v-model="auditForm.remark"
                    type="textarea"
                    :rows="4"
                    maxlength="500"
                    show-word-limit
                    placeholder="驳回时必填，审核意见会写入审核留痕（≤500 字）"
                    :disabled="submitting"
                  />
                </el-form-item>
              </el-form>
              <div class="audit-actions">
                <el-button :disabled="submitting" @click="handleClose">取消</el-button>
                <el-button type="primary" :loading="submitting" @click="submitAudit">提交审核</el-button>
              </div>
            </template>
            <div v-else class="audit-readonly">
              <el-icon :class="readonlyIconClass" :size="32">
                <CircleCheck v-if="detail.auditStatus === 2" />
                <CircleClose v-else-if="detail.auditStatus === 1" />
                <View v-else />
              </el-icon>
              <p class="audit-readonly-text">{{ readonlyText }}</p>
              <el-button @click="handleClose">关闭</el-button>
            </div>
          </el-col>
        </el-row>
      </template>
      <el-empty v-else-if="!loading" description="商品不存在或已删除" />
    </div>
  </el-drawer>
</template>

<script setup>
/**
 * 商品审核抽屉（§5.4.6、§6.4、§7.4）
 *
 * props  visible(Boolean) / itemId(Number|null)
 * emits  update:visible / audited
 *
 * 展示型取数（getItemDetail）在本组件内完成；写操作 auditItem 成功后 emit('audited') 交页面刷新列表。
 * 只有 auditStatus=0（待审核）才渲染通过/驳回表单；已审核商品只读，防并发覆盖（§3.9 A7、§5.4.8）。
 */
import { auditItem, getItemDetail } from '@/api/mall/item'
import { AGE_STAGE, AUDIT_STATUS, PET_SPECIES, SKU_STATUS, dictLabel } from '@/utils/mallDict'
import MallStatusTag from '@/components/mall/MallStatusTag.vue'
import MallMoney from '@/components/mall/MallMoney.vue'

const props = defineProps({
  visible: {
    type: Boolean,
    default: false
  },
  itemId: {
    type: Number,
    default: null
  },
  /* 只读模式：页面「查看」入口传入，右栏不渲染审核表单（§5.4.5） */
  readonly: {
    type: Boolean,
    default: false
  }
})

const emit = defineEmits(['update:visible', 'audited'])

const { proxy } = getCurrentInstance()

const loading = ref(false)
const submitting = ref(false)
const detail = ref(null)
const auditFormRef = ref()

const auditForm = reactive({
  auditStatus: undefined,
  remark: ''
})

const auditRules = {
  auditStatus: [{ required: true, message: '请选择审核结论', trigger: 'change' }],
  remark: [
    {
      validator: (rule, value, callback) => {
        const text = String(value ?? '')
        if (auditForm.auditStatus === 1 && !text.trim()) {
          callback(new Error('驳回时必须填写审核意见'))
          return
        }
        if (text.length > 500) {
          callback(new Error('审核意见不能超过 500 个字符'))
          return
        }
        callback()
      },
      trigger: 'blur'
    }
  ]
}

const drawerTitle = computed(() => {
  const id = detail.value?.id ?? props.itemId
  return canAudit.value ? `商品审核${id ? `（ID ${id}）` : ''}` : `商品详情${id ? `（ID ${id}）` : ''}`
})

const canAudit = computed(() => !props.readonly && detail.value?.auditStatus === 0)

const audits = computed(() => {
  const list = detail.value?.audits || []
  return list
    .slice()
    .sort((a, b) => String(b.createTime || '').localeCompare(String(a.createTime || '')))
})

const latestAudit = computed(() => audits.value[0] || null)

const readonlyText = computed(() => {
  const item = detail.value
  if (!item) return ''
  if (item.auditStatus === 0) {
    return '该商品为待审核状态；如需提交审核结论，请回到列表点击「审核」'
  }
  const statusText = item.auditStatus === 2 ? '审核通过' : '驳回'
  if (latestAudit.value) {
    return `已于 ${latestAudit.value.createTime || '—'} 由 ${latestAudit.value.auditor || '—'} ${statusText}，不可重复审核`
  }
  return `该商品当前审核状态为「${dictLabel(AUDIT_STATUS, item.auditStatus)}」，不可重复审核`
})

const readonlyIconClass = computed(() => {
  if (detail.value?.auditStatus === 2) return 'text-success'
  if (detail.value?.auditStatus === 1) return 'text-danger'
  return 'text-muted'
})

const allImages = computed(() => {  const item = detail.value
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

const detailHtml = computed(() => detail.value?.detail || '<p class="text-muted">暂无商品详情</p>')

function handleVisibleChange(value) {
  emit('update:visible', value)
}

function handleClose() {
  if (submitting.value) return
  emit('update:visible', false)
}

function handleBeforeClose(done) {
  if (submitting.value) {
    proxy.$modal.msgWarning('审核提交中，请稍候')
    return
  }
  done()
}

function skuRowClassName({ row }) {
  return row && row.status === 0 ? 'sku-row-disabled' : ''
}

function merchantLabel(merchantId) {
  return merchantId === null || merchantId === undefined || merchantId === '' ? '—' : `#${merchantId}`
}

function handleAuditStatusChange() {
  nextTick(() => auditFormRef.value?.clearValidate('remark'))
}

async function loadDetail() {
  if (!props.itemId) return
  loading.value = true
  detail.value = null
  try {
    detail.value = await getItemDetail(props.itemId)
    // 新商品：清空审核结论与上一条的校验态
    auditForm.auditStatus = undefined
    auditForm.remark = ''
    nextTick(() => auditFormRef.value?.clearValidate())
  } catch (e) {
    // 详情失败关闭抽屉（§5.4.8）；商品不存在/无权时刷新队列
    if (e?.errorCode === 'PET-3003' || e?.errorCode === 'PET-2003') {
      emit('audited')
    }
    emit('update:visible', false)
  } finally {
    loading.value = false
  }
}

async function submitAudit() {
  if (submitting.value || !canAudit.value) return
  let valid = false
  try {
    valid = await auditFormRef.value.validate()
  } catch (e) {
    valid = false
  }
  if (!valid) return

  const pass = auditForm.auditStatus === 2
  const title = detail.value?.title || ''
  const confirmText = pass
    ? `确认审核通过「${title}」？通过后不会自动上架，需到商品管理页手动上架。`
    : `确认驳回「${title}」？驳回后该商品将被强制下架。`
  const confirmed = await proxy.$modal
    .confirm(confirmText)
    .then(() => true)
    .catch(() => false)
  if (!confirmed) return

  submitting.value = true
  try {
    await auditItem(props.itemId, {
      auditStatus: auditForm.auditStatus,
      remark: String(auditForm.remark ?? '').trim()
    })
    proxy.$modal.msgSuccess(
      pass ? '审核完成；审核通过后请到商品管理页手动上架' : '已驳回，该商品已同时下架'
    )
    emit('audited')
    emit('update:visible', false)
  } catch (e) {
    // PET-1001（驳回未填意见）保持抽屉打开；PET-3003 商品不可售/不存在 → 关闭并刷新队列
    if (e?.errorCode === 'PET-3003' || e?.errorCode === 'PET-2003') {
      emit('audited')
      emit('update:visible', false)
    }
  } finally {
    submitting.value = false
  }
}

watch(
  () => props.visible,
  visible => {
    if (visible) loadDetail()
  }
)
</script>

<style scoped>
.audit-drawer-body {
  padding: 0 4px 8px;
  min-height: 200px;
}

.drawer-section-title {
  margin: 4px 0 12px;
  padding-left: 8px;
  border-left: 3px solid var(--el-color-primary);
  font-weight: 600;
  font-size: 14px;
  line-height: 18px;
  color: var(--el-text-color-primary);
}

.image-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 8px;
}

.detail-html {
  max-height: 240px;
  overflow-y: auto;
  padding: 8px 12px;
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 4px;
  margin-bottom: 8px;
  line-height: 1.6;
  word-break: break-word;
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

.audit-tip {
  margin-bottom: 16px;
}

.audit-form {
  margin-top: 4px;
}

.audit-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  margin-top: 16px;
}

.audit-readonly {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding: 32px 12px;
  border: 1px dashed var(--el-border-color);
  border-radius: 4px;
}

.audit-readonly-text {
  margin: 0;
  text-align: center;
  color: var(--el-text-color-regular);
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
