<script setup>
import { ref, watch, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import * as api from '../api/item.js'
import { useTask } from '../composables/useTask.js'
import FilterBar from './FilterBar.vue'
import SortBar from './SortBar.vue'
import ItemCard from './ItemCard.vue'
import AsyncState from './AsyncState.vue'
import EmptyState from './EmptyState.vue'
const props = defineProps({ search: Boolean })
const route = useRoute(),
  router = useRouter(),
  categories = ref([]),
  page = ref({ list: [], total: 0 }),
  minPrice = ref(''),
  maxPrice = ref(''),
  filterError = ref('')
const { loading, error, run } = useTask()
let generation = 0
async function load() {
  const id = ++generation
  await run(async () => {
    const params = Object.fromEntries(
      Object.entries(route.query).filter(
        ([key, value]) =>
          [
            'keyword',
            'categoryId',
            'species',
            'ageStage',
            'minPrice',
            'maxPrice',
            'sort',
            'pageNum',
            'pageSize',
          ].includes(key) && value !== '',
      ),
    )
    const data = await api.list({ ...params, pageSize: 12 })
    if (id === generation) page.value = data
    minPrice.value = route.query.minPrice || ''
    maxPrice.value = route.query.maxPrice || ''
  })
}
function change(key, value) {
  const query = { ...route.query, pageNum: 1 }
  if (value === '' || value == null) delete query[key]
  else query[key] = value
  router.push({ query })
}
function applyPrice() {
  filterError.value = ''
  if (
    (minPrice.value !== '' && Number(minPrice.value) < 0) ||
    (maxPrice.value !== '' && Number(maxPrice.value) < 0) ||
    (minPrice.value !== '' &&
      maxPrice.value !== '' &&
      Number(minPrice.value) > Number(maxPrice.value))
  ) {
    filterError.value = '请输入有效价格区间'
    return
  }
  const query = { ...route.query, pageNum: 1 }
  for (const [key, value] of [
    ['minPrice', minPrice.value],
    ['maxPrice', maxPrice.value],
  ]) {
    if (value === '') delete query[key]
    else query[key] = value
  }
  router.push({ query })
}
watch(() => route.query, load, { immediate: true })
onMounted(() => {
  api
    .categories()
    .then((data) => {
      categories.value = data
    })
    .catch(() => {})
})
</script>
<template>
  <div class="page-heading">
    <span class="eyebrow">FIND THEIR FAVORITES</span>
    <h1>
      {{ props.search ? `“${route.query.keyword || ''}” 的搜索结果` : '认真挑选，每一份喜欢' }}
    </h1>
    <p>
      {{
        props.search
          ? '再挑一挑，也许就有它的心头好。'
          : '好好吃饭、尽情撒欢，照顾毛孩子的每一个日常。'
      }}
    </p>
  </div>
  <FilterBar :model-value="route.query" :categories="categories" @change="change"
    ><form class="filter-row price-filter" @submit.prevent="applyPrice">
      <strong>价格区间</strong
      ><label
        ><span class="sr-only">最低价</span
        ><input v-model="minPrice" type="number" min="0" step="0.01" placeholder="最低价" /></label
      ><span>—</span
      ><label
        ><span class="sr-only">最高价</span
        ><input v-model="maxPrice" type="number" min="0" step="0.01" placeholder="最高价" /></label
      ><el-button native-type="submit" size="small">确定</el-button
      ><el-button size="small" @click="router.push({ path: route.path })">重置筛选</el-button
      ><span class="error-text">{{ filterError }}</span>
    </form></FilterBar
  ><SortBar
    :model-value="String(route.query.sort || '')"
    :total="page.total"
    @update:model-value="change('sort', $event)"
  /><AsyncState :loading="loading" :error="error" @retry="load"
    ><div v-if="page.list?.length" class="product-grid">
      <ItemCard v-for="item in page.list" :key="item.id" :item="item" />
    </div>
    <EmptyState v-else title="暂时没有找到合适的好物" description="换个关键词，或试试其他筛选条件。"
      ><el-button @click="router.push('/items')">查看全部好物</el-button></EmptyState
    ><el-pagination
      v-if="page.total > 12"
      class="pagination"
      background
      layout="prev, pager, next"
      :pager-count="5"
      :total="page.total"
      :page-size="12"
      :current-page="Number(route.query.pageNum) || 1"
      @current-change="change('pageNum', $event)"
  /></AsyncState>
</template>
