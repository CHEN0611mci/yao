<script setup>
import { statuses } from '../utils/format.js'
defineProps({ status: [Number, String] })
</script>
<template>
  <span class="order-status" :class="`status-${status}`">{{ statuses[status] || '状态未知' }}</span>
</template>
