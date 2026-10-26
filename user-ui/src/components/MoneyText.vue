<script setup>
import { money } from '../utils/format.js'
defineProps({ value: [Number, String], suffix: String })
</script>
<template>
  <span class="money"
    ><small>¥</small>{{ money(value) }}<em v-if="suffix">{{ suffix }}</em></span
  >
</template>
