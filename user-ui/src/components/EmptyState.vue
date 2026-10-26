<script setup>
defineProps({
  title: { type: String, default: '这里还空着' },
  description: String,
  to: String,
  action: String,
})
</script>
<template>
  <div class="empty-state">
    <div class="empty-mark">✦</div>
    <h3>{{ title }}</h3>
    <p>{{ description }}</p>
    <router-link v-if="to" :to="to" class="button">{{ action || '去逛逛' }}</router-link
    ><slot />
  </div>
</template>
