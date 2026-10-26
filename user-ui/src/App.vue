<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import DefaultLayout from './layouts/DefaultLayout.vue'
import BlankLayout from './layouts/BlankLayout.vue'
import zhCn from 'element-plus/es/locale/lang/zh-cn'
const route = useRoute()
const layout = computed(() => (route.meta.layout === 'blank' ? BlankLayout : DefaultLayout))
</script>
<template>
  <el-config-provider :locale="zhCn"
    ><component :is="layout"
      ><router-view v-slot="{ Component }"
        ><component :is="Component" :key="$route.path" /></router-view></component
  ></el-config-provider>
</template>
