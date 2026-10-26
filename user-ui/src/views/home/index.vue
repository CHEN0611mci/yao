<script setup>
import { onMounted, ref } from 'vue'
import * as api from '../../api/item.js'
import { useTask } from '../../composables/useTask.js'
import CategoryNav from '../../components/CategoryNav.vue'
import ItemCard from '../../components/ItemCard.vue'
import AsyncState from '../../components/AsyncState.vue'
import EmptyState from '../../components/EmptyState.vue'
import Icon from '../../components/Icon.vue'
const categories = ref([]),
  items = ref([]),
  { loading, error, run } = useTask()
const load = () =>
  run(async () => {
    const result = await Promise.all([api.categories(), api.recommend(8)])
    categories.value = result[0].filter((row) => !row.parentId)
    items.value = result[1] || []
  })
onMounted(load)
</script>
<template>
  <section class="hero">
    <div class="hero-copy">
      <span class="eyebrow"><i></i> GOOD DAYS WITH LITTLE PAWS</span>
      <h1>它的小日常，<br />我们的大认真<span>。</span></h1>
      <p>从第一口好粮，到每一次撒欢。<br />为毛孩子挑好物，也为陪伴添一点幸福。</p>
      <router-link to="/items" class="button hero-button"
        >发现它的心头好 <Icon name="ArrowRight" :size="18"
      /></router-link>
      <div class="hero-note"><span>✦</span> 用心挑选 · 按宠适配 · 快乐陪伴</div>
    </div>
    <div class="hero-art">
      <span class="hero-sticker sticker-top">THEIR HAPPY PLACE <span>♡</span></span
      ><img src="/images/companions.svg" alt="猫咪和狗狗并肩坐着的温暖插画" /><span
        class="hero-sticker sticker-bottom"
        >好好吃饭，好好长大。</span
      >
    </div>
    <span class="hero-index">01 / EVERYDAY COMPANIONS</span>
  </section>
  <section class="promise-strip">
    <span><Icon name="Collection" />食品用品，一站挑选</span
    ><span><Icon name="Check" />宠物档案，适配更安心</span
    ><span><Icon name="Box" />陪它长大，照顾日常</span>
  </section>
  <AsyncState :loading="loading" :error="error" @retry="load"
    ><section class="section">
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
