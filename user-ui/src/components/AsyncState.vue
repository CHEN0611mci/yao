<script setup>
import SkeletonBlock from './SkeletonBlock.vue'
import Icon from './Icon.vue'
defineProps({ loading: Boolean, error: String })
defineEmits(['retry'])
</script>
<template>
  <SkeletonBlock v-if="loading" />
  <div v-else-if="error" class="error-state" role="alert">
    <Icon name="Warning" :size="30" />
    <h3>暂时没能加载</h3>
    <p>{{ error }}</p>
    <el-button @click="$emit('retry')">重新加载</el-button>
  </div>
  <slot v-else />
</template>
