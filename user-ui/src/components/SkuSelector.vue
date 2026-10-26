<script setup>
defineProps({ skus: { type: Array, default: () => [] }, modelValue: [Number, String] })
defineEmits(['update:modelValue'])
</script>
<template>
  <div class="sku-options" role="group" aria-label="选择规格">
    <button
      v-for="sku in skus"
      :key="sku.id"
      type="button"
      :class="{ selected: modelValue === sku.id }"
      :disabled="sku.stock <= 0 || sku.status === 0"
      @click="$emit('update:modelValue', sku.id)"
    >
      {{ sku.specName }}<small v-if="sku.stock <= 0"> · 已售罄</small>
    </button>
  </div>
</template>
