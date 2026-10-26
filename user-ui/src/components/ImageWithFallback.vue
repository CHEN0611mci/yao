<script setup>
import { ref, watch, computed } from 'vue'
const props = defineProps({
  src: String,
  alt: { type: String, default: '商品图片' },
  kind: { type: String, default: 'product' },
})
const broken = ref(false)
const safeSrc = computed(() =>
  typeof props.src === 'string' && (/^\/(?!\/)/.test(props.src) || /^https?:\/\//i.test(props.src))
    ? props.src
    : '',
)
watch(
  () => props.src,
  () => {
    broken.value = false
  },
)
</script>
<template>
  <img v-if="safeSrc && !broken" :src="safeSrc" :alt="alt" loading="lazy" @error="broken = true" />
  <div v-else class="image-fallback" role="img" :aria-label="`${alt}（图片暂缺）`">
    <span v-if="kind === 'avatar'" class="fallback-paw">🐾</span
    ><template v-else
      ><div class="product-pouch"><span>PET & GOOD</span><b>✦</b><small>DAILY CARE</small></div>
      <span class="image-caption">商品图片暂缺</span></template
    >
  </div>
</template>
