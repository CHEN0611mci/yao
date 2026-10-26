<template>
  <span class="mall-money" :class="{ 'is-bold': bold, 'is-empty': isEmpty }">{{ text }}</span>
</template>

<script setup>
import { formatMoney } from '@/utils/mallDict'

const props = defineProps({
  /* 金额（后端 BigDecimal 序列化为 number） */
  value: {
    type: [Number, String],
    default: null
  },
  /* 前缀，默认人民币符号 */
  prefix: {
    type: String,
    default: '¥'
  },
  /* 是否加粗 */
  bold: {
    type: Boolean,
    default: false
  }
})

const emptyText = '—'
const isEmpty = computed(() => formatMoney(props.value) === emptyText)
const text = computed(() => {
  const money = formatMoney(props.value)
  return money === emptyText ? emptyText : props.prefix + money
})
</script>

<style scoped>
.mall-money {
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}
.mall-money.is-bold {
  font-weight: 600;
}
.mall-money.is-empty {
  color: #909399;
}
</style>
