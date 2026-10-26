<script setup>
import { ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import Icon from './Icon.vue'
import { remember } from '../utils/search.js'
const route = useRoute(),
  router = useRouter(),
  keyword = ref(route.query.keyword || '')
watch(
  () => route.query.keyword,
  (value) => {
    keyword.value = value || ''
  },
)
function search() {
  remember(keyword.value)
  router.push({
    path: keyword.value.trim() ? '/search' : '/items',
    query: keyword.value.trim() ? { keyword: keyword.value.trim().slice(0, 100) } : {},
  })
}
</script>
<template>
  <form class="search-bar" role="search" @submit.prevent="search">
    <Icon name="Search" /><input
      v-model="keyword"
      aria-label="搜索商品"
      placeholder="为毛孩子找点好东西"
      maxlength="100"
    /><button type="submit" aria-label="搜索"><Icon name="ArrowRight" /></button>
  </form>
</template>
