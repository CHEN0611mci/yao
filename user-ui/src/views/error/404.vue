<script setup>
import EmptyState from '../../components/EmptyState.vue'
</script>
<template>
  <section class="panel not-found">
    <span class="eyebrow">404 / A LITTLE DETOUR</span
    ><EmptyState
      title="哎呀，毛孩子把页面藏起来了"
      description="这个地址不存在，回首页继续发现好物吧。"
      to="/"
      action="返回首页"
    />
  </section>
</template>
