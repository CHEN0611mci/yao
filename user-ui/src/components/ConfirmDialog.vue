<script setup>
defineProps({ modelValue: Boolean, title: String, busy: Boolean })
defineEmits(['update:modelValue', 'confirm'])
</script>
<template>
  <el-dialog
    :model-value="modelValue"
    :title="title"
    width="min(520px, 92vw)"
    :close-on-click-modal="!busy"
    :close-on-press-escape="!busy"
    :show-close="!busy"
    @update:model-value="$emit('update:modelValue', $event)"
    ><slot /><template #footer
      ><el-button :disabled="busy" @click="$emit('update:modelValue', false)">取消</el-button
      ><el-button type="primary" :loading="busy" @click="$emit('confirm')"
        >确认</el-button
      ></template
    ></el-dialog
  >
</template>
