<template>
  <el-tag v-if="hasValue" :type="tagType" :effect="effect" size="small" disable-transitions>
    {{ text }}
  </el-tag>
  <span v-else class="mall-empty">—</span>
</template>

<script setup>
import { dictType } from '@/utils/mallDict'

const props = defineProps({
  /* 枚举常量对象（值可为 {label,type} 或字符串） */
  dict: {
    type: Object,
    default: () => ({})
  },
  /* 原始值 */
  value: {
    type: [Number, String, Boolean],
    default: null
  },
  /* 未命中枚举时的兜底文案（如后端返回的 statusText） */
  fallback: {
    type: String,
    default: ''
  },
  /* el-tag 风格 */
  effect: {
    type: String,
    default: 'light'
  }
})

const rawLabel = computed(() => {
  if (props.value === null || props.value === undefined || props.value === '') return null
  const item = props.dict?.[props.value]
  if (item && typeof item === 'object') return item.label ?? null
  if (typeof item === 'string') return item
  return null
})

const hasValue = computed(() => rawLabel.value !== null || props.fallback !== '')
const text = computed(() => rawLabel.value ?? props.fallback)
const tagType = computed(() => dictType(props.dict, props.value, 'info'))
</script>

<style scoped>
.mall-empty {
  color: #909399;
}
</style>
