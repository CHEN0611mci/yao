<script setup>
import { computed } from 'vue'
import {
  Search,
  ShoppingCart,
  User,
  Bell,
  House,
  Grid,
  ArrowRight,
  ArrowLeft,
  Plus,
  Delete,
  Location,
  Box,
  Close,
  Check,
  Van,
  Warning,
  Refresh,
  Document,
  Collection,
  ArrowDown,
} from '@element-plus/icons-vue'
const props = defineProps({ name: String, size: { type: [String, Number], default: 20 } })
const icons = {
  Search,
  ShoppingCart,
  User,
  Bell,
  House,
  Grid,
  ArrowRight,
  ArrowLeft,
  Plus,
  Delete,
  Location,
  Box,
  Close,
  Check,
  Van,
  Warning,
  Refresh,
  Document,
  Collection,
  ArrowDown,
}
const icon = computed(() => icons[props.name] || Box)
</script>
<template>
  <el-icon :size="size" aria-hidden="true"><component :is="icon" /></el-icon>
</template>
