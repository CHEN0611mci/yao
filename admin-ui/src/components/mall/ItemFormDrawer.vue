<template>
  <el-drawer
    :model-value="visible"
    :title="title"
    size="900px"
    direction="rtl"
    append-to-body
    :close-on-click-modal="false"
    :before-close="handleBeforeClose"
    @update:model-value="handleVisibleChange"
  >
    <div v-loading="loading" class="drawer-body">
      <!-- 审核语义提示：管理员不重审 / 商家强制重审并下架（§5.3.6、§5.10.6、§7.3、§7.4） -->
      <el-alert
        v-if="mode === 'merchant'"
        class="drawer-alert"
        type="warning"
        :closable="false"
        show-icon
        :title="editId ? '修改后将自动下架并重新提交平台审核，审核通过后请手动上架' : '发布后需平台审核，审核通过后请手动上架'"
      />
      <el-alert
        v-else
        class="drawer-alert"
        type="info"
        :closable="false"
        show-icon
        :title="editId ? '后台编辑不会触发重新审核，也不会改变上下架状态' : '后台新建商品默认「审核通过 + 下架」，保存后请到列表手动上架'"
      />

      <el-form ref="formRef" :model="form" :rules="rules" label-width="110px" :disabled="loading || submitting">
        <div class="form-section-title">基本信息</div>
        <el-row :gutter="20">
          <el-col v-if="showMerchantField" :span="12">
            <el-form-item label="归属商家" prop="merchantId">
              <el-select
                v-if="merchantSelectOptions.length"
                v-model="form.merchantId"
                placeholder="请选择商家"
                filterable
                style="width: 100%"
                :disabled="submitting"
              >
                <el-option v-for="item in merchantSelectOptions" :key="item.value" :label="item.label" :value="item.value" />
              </el-select>
              <el-input-number
                v-else
                v-model="form.merchantId"
                :min="1"
                :precision="0"
                :controls="false"
                placeholder="请输入商家ID（演示可用 9001）"
                style="width: 100%"
                :disabled="submitting"
              />
              <div class="form-item-tip">商家ID = 商家账号的部门ID（dept_id），无商家列表接口，演示可用 9001</div>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="商品类目" prop="categoryId">
              <category-tree-select
                v-model="form.categoryId"
                :categories="categoryTree"
                placeholder="请选择末级类目"
                :disabled="submitting"
              />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="商品标题" prop="title">
              <el-input v-model="form.title" placeholder="请输入商品标题" maxlength="100" show-word-limit :disabled="submitting" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="副标题" prop="subtitle">
              <el-input v-model="form.subtitle" placeholder="选填，卖点简述" maxlength="200" show-word-limit :disabled="submitting" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="品牌" prop="brand">
              <el-input v-model="form.brand" placeholder="选填" maxlength="50" :disabled="submitting" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="适用宠物" prop="petSpecies">
              <el-select v-model="form.petSpecies" placeholder="请选择" style="width: 100%" :disabled="submitting">
                <el-option v-for="item in petSpeciesOptions" :key="item.value" :label="item.label" :value="item.value" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="适用年龄" prop="ageStage">
              <el-select v-model="form.ageStage" placeholder="请选择" style="width: 100%" :disabled="submitting">
                <el-option v-for="item in ageStageOptions" :key="item.value" :label="item.label" :value="item.value" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="重量范围" prop="weightRange">
              <el-input v-model="form.weightRange" placeholder="如 0.5-5（选填）" maxlength="50" :disabled="submitting" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="成本价" prop="costPrice">
              <el-input-number
                v-model="form.costPrice"
                :precision="2"
                :min="0"
                :step="1"
                controls-position="right"
                placeholder="选填"
                style="width: 100%"
                :disabled="submitting"
              />
              <div v-if="costPriceWarning" class="form-item-tip form-item-tip-warning">成本价高于最低 SKU 售价 ¥{{ minSkuPrice }}</div>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="支持订阅" prop="supportSubscribe">
              <el-switch v-model="form.supportSubscribe" :active-value="1" :inactive-value="0" active-text="是" inactive-text="否" :disabled="submitting" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="处方商品" prop="isPrescription">
              <el-switch v-model="form.isPrescription" :active-value="1" :inactive-value="0" active-text="是" inactive-text="否" :disabled="submitting" />
              <div class="form-item-tip">仅作标记，一期无处方上传流程</div>
            </el-form-item>
          </el-col>
        </el-row>

        <div class="form-section-title">商品图片</div>
        <el-form-item label="主图" prop="mainImage">
          <mall-image-upload v-model="form.mainImage" :limit="1" :disabled="submitting" />
        </el-form-item>
        <el-form-item label="图集" prop="imageList">
          <mall-image-upload v-model="form.imageList" :limit="5" :disabled="submitting" />
        </el-form-item>
        <el-form-item label="商品详情">
          <editor v-model="form.detail" :min-height="192" />
        </el-form-item>

        <div class="form-section-title">SKU 规格</div>
        <el-form-item label="SKU" prop="skus">
          <sku-editor ref="skuEditorRef" v-model="form.skus" :disabled="submitting" />
        </el-form-item>
      </el-form>
    </div>

    <template #footer>
      <div class="drawer-footer">
        <el-button :disabled="submitting" @click="handleClose">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="submitForm">
          {{ mode === 'merchant' && !editId ? '提交审核' : '保存' }}
        </el-button>
      </div>
    </template>
  </el-drawer>
</template>

<script setup>
/**
 * 商品发布 / 编辑表单抽屉（admin 与 merchant 共用，§5.3.6、§5.10.6、§6.6、§7.3、§7.4）
 *
 * 严格遵循固定契约：
 *   props  visible(Boolean) / mode('admin'|'merchant') / editId(Number|null) / categories(Array) / merchantOptions(Array)
 *   emits  update:visible / saved
 *
 * 差异：
 *   - admin 新增：调 createItem，必须带 merchantId（商家下拉或手填，placeholder 提示演示 9001，不预填），保存后「商品已创建」
 *   - admin 编辑：getItemDetail 回填 → updateItem，不重审、不改上下架，保存后「商品已更新」
 *   - merchant  ：不出现/不提交 merchantId，createMyItem/updateMyItem；「下架+重新审核」确认由商家列表页打开抽屉前完成
 */
import { listHomeCategories } from '@/api/mall/category'
import { createItem, getItemDetail, updateItem } from '@/api/mall/item'
import { createMyItem, getMyItem, updateMyItem } from '@/api/mall/merchant'
import { AGE_STAGE, PET_SPECIES, optionsOf } from '@/utils/mallDict'
import MallImageUpload from '@/components/mall/MallImageUpload.vue'
import CategoryTreeSelect from '@/components/mall/CategoryTreeSelect.vue'
import SkuEditor from '@/components/mall/SkuEditor.vue'

const props = defineProps({
  visible: {
    type: Boolean,
    default: false
  },
  mode: {
    type: String,
    default: 'admin',
    validator: value => ['admin', 'merchant'].includes(value)
  },
  editId: {
    type: Number,
    default: null
  },
  categories: {
    type: Array,
    default: () => []
  },
  merchantOptions: {
    type: Array,
    default: () => []
  }
})

const emit = defineEmits(['update:visible', 'saved'])

const { proxy } = getCurrentInstance()

const formRef = ref()
const skuEditorRef = ref()
const loading = ref(false)
const submitting = ref(false)
// 编辑时原始归属商家，用于「改归属」二次确认
const originalMerchantId = ref(null)
const localCategories = ref([])

const defaultForm = () => ({
  merchantId: null,
  categoryId: undefined,
  title: '',
  subtitle: '',
  mainImage: '',
  brand: '',
  petSpecies: '',
  ageStage: '',
  weightRange: '',
  costPrice: null,
  supportSubscribe: 0,
  isPrescription: 0,
  detail: '',
  imageList: '',
  skus: []
})

const form = reactive(defaultForm())

const title = computed(() => {
  if (props.mode === 'merchant') return props.editId ? '编辑商品' : '发布商品'
  return props.editId ? '编辑商品' : '新增商品'
})

const showMerchantField = computed(() => props.mode === 'admin')

const merchantSelectOptions = computed(() => {
  const list = Array.isArray(props.merchantOptions) ? props.merchantOptions : []
  return list
    .map(item => {
      if (item && typeof item === 'object') {
        const value = Number(item.value ?? item.id ?? item.merchantId)
        return { value, label: item.label ?? item.name ?? `商家#${item.value ?? item.id}` }
      }
      return { value: Number(item), label: `商家#${item}` }
    })
    .filter(item => !Number.isNaN(item.value))
})

const petSpeciesOptions = computed(() => optionsOf(PET_SPECIES))
const ageStageOptions = computed(() => optionsOf(AGE_STAGE))

// 类目由页面通过 props 传入；未传时兜底加载一次公开类目树（仅启用）
const categoryTree = computed(() => (Array.isArray(props.categories) && props.categories.length ? props.categories : localCategories.value))

const rules = computed(() => {
  const base = {
    categoryId: [{ required: true, message: '请选择商品类目', trigger: 'change' }],
    title: [
      { required: true, message: '商品标题不能为空', trigger: 'blur' },
      { max: 100, message: '商品标题不能超过 100 个字符', trigger: 'blur' }
    ],
    subtitle: [{ max: 200, message: '副标题不能超过 200 个字符', trigger: 'blur' }],
    brand: [{ max: 50, message: '品牌不能超过 50 个字符', trigger: 'blur' }],
    mainImage: [{ required: true, message: '主图不能为空', trigger: ['blur', 'change'] }],
    petSpecies: [{ required: true, message: '请选择适用宠物', trigger: 'change' }],
    ageStage: [{ required: true, message: '请选择适用年龄段', trigger: 'change' }],
    skus: [{ required: true, message: '至少需要一个 SKU', trigger: 'change' }]
  }
  if (props.mode === 'admin' && !props.editId) {
    base.merchantId = [{ required: true, message: '请输入归属商家ID', trigger: ['blur', 'change'] }]
  }
  return base
})

// 成本价高于最低 SKU 售价时给出非阻断提示
const minSkuPrice = computed(() => {
  const prices = (form.skus || [])
    .filter(row => row.status !== 0 && row.price !== null && row.price !== undefined && row.price !== '' && !Number.isNaN(Number(row.price)))
    .map(row => Number(row.price))
  return prices.length ? Math.min(...prices).toFixed(2) : '—'
})

const costPriceWarning = computed(() => {
  if (form.costPrice === null || form.costPrice === undefined || form.costPrice === '') return false
  const prices = (form.skus || [])
    .filter(row => row.status !== 0 && row.price !== null && row.price !== undefined && row.price !== '' && !Number.isNaN(Number(row.price)))
    .map(row => Number(row.price))
  if (!prices.length) return false
  return Number(form.costPrice) > Math.min(...prices)
})

function handleVisibleChange(value) {
  emit('update:visible', value)
}

function handleBeforeClose(done) {
  if (submitting.value) {
    proxy.$modal.msgWarning('保存中，请稍候')
    return
  }
  done()
}

function handleClose() {
  if (submitting.value) return
  emit('update:visible', false)
}

function resetFormModel() {
  Object.assign(form, defaultForm())
  originalMerchantId.value = null
}

/** 商品详情 → 表单回填 */
function fillForm(detail) {
  if (!detail) return
  form.merchantId = detail.merchantId ?? null
  form.categoryId = detail.categoryId ?? undefined
  form.title = detail.title ?? ''
  form.subtitle = detail.subtitle ?? ''
  form.mainImage = detail.mainImage ?? ''
  form.brand = detail.brand ?? ''
  form.petSpecies = detail.petSpecies ?? ''
  form.ageStage = detail.ageStage ?? ''
  form.weightRange = detail.weightRange ?? ''
  form.costPrice = detail.costPrice ?? null
  form.supportSubscribe = detail.supportSubscribe ? 1 : 0
  form.isPrescription = detail.isPrescription ? 1 : 0
  form.detail = detail.detail ?? ''
  // 图集：排除主图，其余按 sort 顺序拼成逗号串（MallImageUpload 的输入输出格式）
  form.imageList = (detail.images || [])
    .slice()
    .sort((a, b) => (a.sort ?? 0) - (b.sort ?? 0))
    .map(image => image.url)
    .filter(url => url && url !== detail.mainImage)
    .join(',')
  form.skus = (detail.skus || []).map(sku => ({
    id: sku.id,
    specName: sku.specName ?? '',
    price: sku.price ?? null,
    stock: sku.stock ?? 0,
    skuCode: sku.skuCode ?? '',
    image: sku.image ?? '',
    status: sku.status === 0 ? 0 : 1
  }))
  originalMerchantId.value = detail.merchantId ?? null
}

async function openDrawer() {
  resetFormModel()
  submitting.value = false
  if (props.editId) {
    loading.value = true
    try {
      const detail = props.mode === 'merchant' ? await getMyItem(props.editId) : await getItemDetail(props.editId)
      fillForm(detail)
    } catch (e) {
      // 详情失败关闭抽屉（§5.3.8），请求层已提示
      emit('update:visible', false)
      return
    } finally {
      loading.value = false
    }
  }
  // admin 新建不再预填 merchantId：由必填校验强制用户确认归属（无商家列表接口，placeholder 提示演示 9001）
  nextTick(() => formRef.value?.clearValidate())
}

/** 未由页面传入类目时，兜底加载公开类目树（商家角色无 mall:category:list，只能用匿名接口） */
async function loadCategoriesFallback() {
  if (Array.isArray(props.categories) && props.categories.length) return
  if (localCategories.value.length) return
  try {
    localCategories.value = (await listHomeCategories()) || []
  } catch (e) {
    localCategories.value = []
  }
}

/** 提交请求体（ItemSaveRequest，字段名与后端严格一致） */
function buildPayload() {
  const skus = (form.skus || []).map(row => {
    const sku = {
      specName: String(row.specName ?? '').trim(),
      price: row.price,
      stock: row.stock,
      status: row.status === 0 ? 0 : 1
    }
    if (row.id) sku.id = row.id
    if (row.image) sku.image = row.image
    const code = String(row.skuCode ?? '').trim()
    if (code) sku.skuCode = code
    return sku
  })

  // 图集：主图始终在首位，其余去重后按顺序生成 sort
  const imageUrls = []
  if (form.mainImage) imageUrls.push(form.mainImage)
  String(form.imageList || '')
    .split(',')
    .map(url => url.trim())
    .filter(Boolean)
    .forEach(url => {
      if (!imageUrls.includes(url)) imageUrls.push(url)
    })

  const payload = {
    categoryId: form.categoryId,
    title: String(form.title ?? '').trim(),
    subtitle: String(form.subtitle ?? '').trim(),
    mainImage: form.mainImage,
    brand: String(form.brand ?? '').trim(),
    petSpecies: form.petSpecies,
    ageStage: form.ageStage,
    weightRange: String(form.weightRange ?? '').trim(),
    costPrice: form.costPrice ?? null,
    supportSubscribe: form.supportSubscribe ? 1 : 0,
    isPrescription: form.isPrescription ? 1 : 0,
    detail: form.detail || '',
    skus,
    images: imageUrls.map((url, index) => ({ url, sort: index }))
  }
  // 商家端禁止提交 merchantId（服务端强制 dept_id）
  if (props.mode === 'admin') payload.merchantId = form.merchantId
  return payload
}

const successText = computed(() => {
  if (props.mode === 'merchant') {
    return props.editId ? '商品已更新（已重新提交审核并下架）' : '商品已提交审核'
  }
  return props.editId ? '商品已更新' : '商品已创建（默认审核通过 + 下架，请到列表手动上架）'
})

async function submitForm() {
  if (submitting.value) return
  // SKU 子表本地校验（必填、价格、库存、去重）
  const skuResult = skuEditorRef.value?.validate?.()
  if (skuResult && !skuResult.valid) {
    proxy.$modal.msgError(skuResult.message || '请检查 SKU 信息')
    return
  }
  let valid = false
  try {
    valid = await formRef.value.validate()
  } catch (fields) {
    valid = false
    // 校验失败聚焦首个错误字段（§7.3 异常分支）
    const firstField = fields && typeof fields === 'object' ? Object.keys(fields)[0] : ''
    if (firstField) formRef.value?.scrollToField?.(firstField)
  }
  if (!valid) return

  // 管理员编辑：改归属商家需二次确认（§5.3.6）
  // 商家编辑的「下架 + 重新审核」确认由商家列表页在打开抽屉前完成（§5.10.5），此处不再重复确认
  if (props.mode === 'admin' && props.editId && form.merchantId !== originalMerchantId.value) {
    const confirmed = await proxy.$modal
      .confirm('修改商品归属商家将影响商家可见性，是否继续？')
      .then(() => true)
      .catch(() => false)
    if (!confirmed) return
  }

  submitting.value = true
  try {
    const payload = buildPayload()
    if (props.editId) {
      if (props.mode === 'merchant') await updateMyItem(props.editId, payload)
      else await updateItem(props.editId, payload)
    } else if (props.mode === 'merchant') {
      await createMyItem(payload)
    } else {
      await createItem(payload)
    }
    proxy.$modal.msgSuccess(successText.value)
    emit('saved')
    emit('update:visible', false)
  } catch (e) {
    // 失败保持抽屉打开（请求层已统一提示）；PET-1002 定位 SKU 编码列
    if (e?.errorCode === 'PET-1002') {
      skuEditorRef.value?.markDuplicateCode?.()
    }
  } finally {
    submitting.value = false
  }
}

watch(
  () => props.visible,
  visible => {
    if (visible) {
      openDrawer()
      loadCategoriesFallback()
    }
  }
)
</script>

<style scoped>
.drawer-body {
  padding: 0 4px 8px;
}

.drawer-alert {
  margin-bottom: 16px;
}

.form-section-title {
  margin: 8px 0 16px;
  padding-left: 8px;
  border-left: 3px solid var(--el-color-primary);
  font-weight: 600;
  font-size: 14px;
  line-height: 18px;
  color: var(--el-text-color-primary);
}

.form-item-tip {
  margin-top: 4px;
  font-size: 12px;
  line-height: 16px;
  color: var(--el-text-color-secondary);
}

.form-item-tip-warning {
  color: var(--el-color-warning);
}

.drawer-footer {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}
</style>
