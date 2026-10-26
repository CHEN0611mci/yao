<script setup>
defineProps({ modelValue: String, total: Number })
defineEmits(['update:modelValue'])
</script>
<template>
  <div class="sort-bar">
    <div class="sort-options">
      <button
        v-for="option in [
          ['', '综合推荐'],
          ['sales', '销量'],
          ['price_asc', '价格 ↑'],
          ['price_desc', '价格 ↓'],
          ['newest', '最新上架'],
        ]"
        :key="option[0]"
        :class="{ active: (modelValue || '') === option[0] }"
        @click="$emit('update:modelValue', option[0])"
      >
        {{ option[1] }}
      </button>
    </div>
    <small>共 {{ total || 0 }} 件好物</small>
  </div>
</template>
