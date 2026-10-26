<script setup>
defineProps({
  pets: { type: Array, default: () => [] },
  modelValue: [Number, String],
  clearable: { type: Boolean, default: true },
  disabled: Boolean,
})
defineEmits(['update:modelValue'])
</script>
<template>
  <el-select
    :model-value="modelValue"
    :clearable="clearable"
    :disabled="disabled"
    placeholder="选择宠物（选填）"
    aria-label="选择宠物"
    @update:model-value="$emit('update:modelValue', $event || null)"
    ><el-option v-for="pet in pets" :key="pet.id" :label="pet.name" :value="pet.id"
  /></el-select>
</template>
