<script setup>
import { onMounted, ref } from 'vue'
import * as api from '../../api/item.js'
import { useTask } from '../../composables/useTask.js'
import CategoryNav from '../../components/CategoryNav.vue'
import ItemCard from '../../components/ItemCard.vue'
import AsyncState from '../../components/AsyncState.vue'
import EmptyState from '../../components/EmptyState.vue'
import Icon from '../../components/Icon.vue'
import HomeBanners from '../../components/HomeBanners.vue'
import * as homeApi from '../../api/home.js'
const settings = ref({ banners: [], promises: [], hotKeywords: [] })
const categories = ref([]),
  items = ref([]),
  { loading, error, run } = useTask()
const load = () =>
  run(async () => {
    const result = await Promise.all([api.categories(), api.recommend(8), homeApi.settings()])
    categories.value = result[0].filter((row) => !row.parentId)
    items.value = result[1] || []
    settings.value = result[2]
  })
onMounted(load)
</script>
<template>
  <HomeBanners :banners="settings.banners" />
  <section class="promise-strip">
    <span><Icon name="Collection" />食品用品，一站挑选</span
    ><span><Icon name="Check" />宠物档案，适配更安心</span
    ><span><Icon name="Box" />陪它长大，照顾日常</span>
  </section>
  <AsyncState :loading="loading" :error="error" @retry="load"
    ><div class="hot-keywords">
      <strong>热门搜索</strong
      ><router-link
        v-for="term in settings.hotKeywords"
        :key="term"
        :to="{ path: '/search', query: { keyword: term } }"
        >{{ term }}</router-link
      >
    </div>
    <section class="section">
      <div class="section-heading">
        <div>
          <span class="eyebrow">A LITTLE OF EVERYTHING</span>
          <h2>每一种可爱，都有专属好物</h2>
        </div>
        <router-link to="/items" class="text-link"
          >全部分类 <Icon name="ArrowRight" :size="16"
        /></router-link>
      </div>
      <CategoryNav :categories="categories" />
    </section>
    <section class="section">
      <div class="section-heading">
        <div>
          <span class="eyebrow">PICKED WITH LOVE</span>
          <h2>毛孩子的日常心选<span class="heading-mark">✳</span></h2>
          <p>从认真吃饭开始，把每一天过得有滋有味。</p>
        </div>
        <router-link to="/items?sort=sales" class="text-link"
          >发现更多好物 <Icon name="ArrowRight" :size="16"
        /></router-link>
      </div>
      <div v-if="items.length" class="product-grid">
        <ItemCard v-for="item in items" :key="item.id" :item="item" />
      </div>
      <EmptyState v-else title="好物正在准备中" description="稍后再来看看吧。" /></section
  ></AsyncState>
  <section class="promise-strip service-promises">
    <span v-for="text in settings.promises" :key="text"><Icon name="Check" />{{ text }}</span>
  </section>
  <section class="pet-banner">
    <div>
      <span class="eyebrow">MADE FOR YOUR LITTLE ONE</span>
      <h2>认识它，才能更懂它。</h2>
      <p>建立宠物档案，让每一次挑选多一份适合。</p>
    </div>
    <router-link to="/member/pets" class="button secondary">建立它的小档案 ↗</router-link
    ><span class="banner-paw">✦</span>
  </section>
</template>
