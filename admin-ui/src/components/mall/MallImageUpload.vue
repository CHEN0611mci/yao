<template>
  <div class="mall-image-upload">
    <el-upload
      multiple
      :disabled="disabled"
      :action="uploadUrl"
      list-type="picture-card"
      :on-success="handleUploadSuccess"
      :before-upload="handleBeforeUpload"
      :limit="limit"
      :on-error="handleUploadError"
      :on-exceed="handleExceed"
      ref="imageUpload"
      :before-remove="handleDelete"
      :headers="headers"
      :file-list="fileList"
      :on-preview="handlePictureCardPreview"
      :class="{ hide: fileList.length >= limit }"
    >
      <el-icon class="avatar-uploader-icon"><plus /></el-icon>
    </el-upload>
    <!-- 上传提示 -->
    <div class="el-upload__tip" v-if="showTip && !disabled">
      请上传
      <template v-if="fileSize">
        大小不超过 <b style="color: #f56c6c">{{ fileSize }}MB</b>
      </template>
      <template v-if="fileType && fileType.length">
        格式为 <b style="color: #f56c6c">{{ fileType.join("/") }}</b>
      </template>
      的图片
    </div>

    <el-dialog v-model="dialogVisible" title="预览" width="800px" append-to-body>
      <img :src="dialogImageUrl" style="display: block; max-width: 100%; margin: 0 auto" />
    </el-dialog>
  </div>
</template>

<script setup>
/**
 * 商城图片上传组件
 *
 * 不能直接复用基座 ImageUpload：商城上传响应为 Result{code,message,data:{url,...}}，
 * 基座读取顶层 res.fileName。本组件兼容两种响应，并始终向前端表单输出「相对路径」的
 * 逗号分隔字符串（与 ImageUpload 的 listToString 行为一致，提交时可直接入库）。
 */
import { getToken } from '@/utils/auth'
import { isExternal } from '@/utils/validate'

const props = defineProps({
  /* 表单值：字符串（逗号分隔相对路径）或数组 */
  modelValue: {
    type: [String, Array],
    default: ''
  },
  /* 上传接口地址（组件内部会拼 VITE_APP_BASE_API） */
  action: {
    type: String,
    default: '/api/upload/image'
  },
  /* 图片数量限制 */
  limit: {
    type: Number,
    default: 5
  },
  /* 大小限制(MB) */
  fileSize: {
    type: Number,
    default: 5
  },
  /* 文件类型 */
  fileType: {
    type: Array,
    default: () => ['png', 'jpg', 'jpeg', 'gif', 'bmp']
  },
  /* 是否显示提示 */
  isShowTip: {
    type: Boolean,
    default: true
  },
  /* 禁用（仅查看） */
  disabled: {
    type: Boolean,
    default: false
  }
})

const { proxy } = getCurrentInstance()
const emit = defineEmits(['update:modelValue'])

const number = ref(0)
const uploadList = ref([])
const dialogImageUrl = ref('')
const dialogVisible = ref(false)
const fileList = ref([])
const baseUrl = import.meta.env.VITE_APP_BASE_API
const uploadUrl = baseUrl + props.action
const headers = ref({ Authorization: 'Bearer ' + getToken() })
const showTip = computed(() => props.isShowTip && ((props.fileType && props.fileType.length) || props.fileSize))

function resolveUrl(path) {
  if (!path) return ''
  return isExternal(path) ? path : baseUrl + path
}

// 表单值 → el-upload 的 fileList
watch(
  () => props.modelValue,
  val => {
    let list = []
    if (Array.isArray(val)) {
      list = val
    } else if (typeof val === 'string' && val) {
      list = val.split(',')
    }
    fileList.value = list
      .filter(item => item !== null && item !== undefined && item !== '')
      .map(item => {
        if (typeof item === 'object') {
          const path = item.url || item.name || ''
          return { name: item.name || path, url: resolveUrl(path), rawUrl: path }
        }
        const path = String(item)
        return { name: path.substring(path.lastIndexOf('/') + 1) || path, url: resolveUrl(path), rawUrl: path }
      })
  },
  { deep: true, immediate: true }
)

// 上传前校验
function handleBeforeUpload(file) {
  let isImg = false
  if (props.fileType && props.fileType.length) {
    let fileExtension = ''
    if (file.name.lastIndexOf('.') > -1) {
      fileExtension = file.name.slice(file.name.lastIndexOf('.') + 1).toLowerCase()
    }
    isImg = props.fileType.some(type => {
      if (file.type.indexOf(type) > -1) return true
      if (fileExtension && fileExtension.indexOf(type) > -1) return true
      return false
    })
  } else {
    isImg = file.type.indexOf('image') > -1
  }
  if (!isImg) {
    proxy.$modal.msgError(`文件格式不正确，请上传${(props.fileType || []).join('/')}图片格式文件!`)
    return false
  }
  if (file.name.includes(',')) {
    proxy.$modal.msgError('文件名不正确，不能包含英文逗号!')
    return false
  }
  if (props.fileSize) {
    const isLt = file.size / 1024 / 1024 < props.fileSize
    if (!isLt) {
      proxy.$modal.msgError(`上传图片大小不能超过 ${props.fileSize} MB!`)
      return false
    }
  }
  proxy.$modal.loading('正在上传图片，请稍候...')
  number.value++
  return true
}

// 数量超限
function handleExceed() {
  proxy.$modal.msgError(`上传文件数量不能超过 ${props.limit} 个!`)
}

// 上传成功：兼容商城 Result 与若依 AjaxResult
function handleUploadSuccess(res, file) {
  const body = res || {}
  const data = body.data || body
  const success = body.code === 200 || body.code === 0 || (body.code === undefined && !!(data.url || data.fileName))
  if (!success) {
    number.value = Math.max(number.value - 1, 0)
    proxy.$modal.closeLoading()
    proxy.$modal.msgError(body.message || body.msg || '上传失败')
    if (proxy.$refs.imageUpload) {
      proxy.$refs.imageUpload.handleRemove(file)
    }
    uploadedSuccessfully()
    return
  }
  const path = data.url || data.fileName || ''
  uploadList.value.push({
    name: data.originalFilename || data.fileName || file.name,
    url: resolveUrl(path),
    rawUrl: path
  })
  uploadedSuccessfully()
}

// 全部上传完成
function uploadedSuccessfully() {
  if (number.value > 0 && uploadList.value.length === number.value) {
    fileList.value = fileList.value
      .filter(f => f.url !== undefined && f.rawUrl)
      .concat(uploadList.value)
    uploadList.value = []
    number.value = 0
    emit('update:modelValue', listToString(fileList.value))
    proxy.$modal.closeLoading()
  }
}

// 上传失败
function handleUploadError() {
  number.value = Math.max(number.value - 1, 0)
  proxy.$modal.msgError('上传图片失败')
  proxy.$modal.closeLoading()
}

// 删除图片
function handleDelete(file) {
  const target = file.rawUrl || file.url
  const findex = fileList.value.map(f => f.rawUrl || f.url).indexOf(target)
  // 不在表单值里的文件（如上传失败留下项）交给 el-upload 自行移除，否则会残留
  if (findex === -1) return true
  // 上传进行中不允许删除，避免计数与列表错位
  if (uploadList.value.length !== number.value) return false
  fileList.value.splice(findex, 1)
  emit('update:modelValue', listToString(fileList.value))
  return false
}

// 预览
function handlePictureCardPreview(file) {
  dialogImageUrl.value = file.url
  dialogVisible.value = true
}

// fileList → 逗号分隔的相对路径
function listToString(list) {
  const paths = (list || [])
    .map(item => item.rawUrl || (item.url ? String(item.url).replace(baseUrl, '') : ''))
    .filter(item => item && !String(item).startsWith('blob:'))
  return paths.join(',')
}
</script>

<style scoped lang="scss">
:deep(.hide .el-upload--picture-card) {
  display: none;
}

:deep(.el-upload.el-upload--picture-card.is-disabled) {
  display: none !important;
}
</style>
