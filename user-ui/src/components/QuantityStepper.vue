<script setup>
defineProps({ modelValue: Number, max: { type: Number, default: 99 }, disabled: Boolean })
defineEmits(['update:modelValue'])
</script>
<template>
  <el-input-number
    :model-value="modelValue"
    :min="1"
    :max="Math.max(1, Math.min(99, max))"
    :disabled="disabled"
    size="small"
    aria-label="商品数量"
    @update:model-value="$event != null && $emit('update:modelValue', $event)"
  />
</template>
