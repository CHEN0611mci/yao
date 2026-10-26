<script setup>
import Icon from './Icon.vue'
import ImageWithFallback from './ImageWithFallback.vue'
import { safeRedirect } from '../utils/auth.js'
defineProps({ banners: { type: Array, default: () => [] } })
</script>
<template>
  <el-carousel
    v-if="banners.length"
    class="home-carousel"
    height="auto"
    :autoplay="banners.length > 1"
    :interval="6000"
    :arrow="banners.length > 1 ? 'hover' : 'never'"
    :indicator-position="banners.length > 1 ? 'outside' : 'none'"
  >
    <el-carousel-item v-for="(banner, index) in banners" :key="index">
      <section class="hero">
        <div class="hero-copy">
          <span class="eyebrow"><i></i> GOOD DAYS WITH LITTLE PAWS</span>
          <h1>{{ banner.title }}</h1>
          <p>{{ banner.subtitle }}</p>
          <router-link :to="safeRedirect(banner.path || '/items')" class="button hero-button"
            >发现它的心头好 <Icon name="ArrowRight" :size="18"
          /></router-link>
          <div class="hero-note"><span>✦</span> 用心挑选 · 按宠适配 · 快乐陪伴</div>
        </div>
        <div class="hero-art">
          <span class="hero-sticker sticker-top">THEIR HAPPY PLACE ♡</span
          ><ImageWithFallback :src="banner.image" alt="猫咪和狗狗并肩坐着的温暖插画" /><span
            class="hero-sticker sticker-bottom"
            >好好吃饭，好好长大。</span
          >
        </div>
        <span class="hero-index">0{{ index + 1 }} / EVERYDAY COMPANIONS</span>
      </section>
    </el-carousel-item>
  </el-carousel>
</template>
