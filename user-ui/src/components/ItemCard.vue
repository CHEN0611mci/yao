<script setup>
import ImageWithFallback from './ImageWithFallback.vue'
import MoneyText from './MoneyText.vue'
import AdaptTag from './AdaptTag.vue'
import Icon from './Icon.vue'
import { species, ages } from '../utils/format.js'
defineProps({ item: { type: Object, required: true } })
</script>
<template>
  <article class="item-card">
    <router-link :to="`/items/${item.id}`" class="item-image"
      ><ImageWithFallback :src="item.mainImage" :alt="item.title" /><span class="item-species">{{
        species[item.petSpecies] || '宠物好物'
      }}</span
      ><span class="item-open"><Icon name="ArrowRight" /></span
    ></router-link>
    <div class="item-body">
      <div class="item-meta">
        {{ item.brand || '日常好物' }}<span>{{ ages[item.ageStage] || '细心呵护' }}</span>
      </div>
      <router-link :to="`/items/${item.id}`" class="item-title">{{ item.title }}</router-link>
      <p class="item-subtitle">{{ item.subtitle || '陪伴日常，用心挑选' }}</p>
      <AdaptTag :adapt="item.adapt" />
      <div class="item-price">
        <MoneyText :value="item.priceMin" suffix="起" /><small>已售 {{ item.sales || 0 }}</small>
      </div>
    </div>
  </article>
</template>
