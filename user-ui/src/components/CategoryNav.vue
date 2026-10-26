<script setup>
defineProps({ categories: { type: Array, default: () => [] } })
const marks = ['◒', '◓', '✦', '✿']
</script>
<template>
  <div class="category-tiles">
    <router-link
      v-for="(category, index) in categories"
      :key="category.id"
      :to="{ path: '/items', query: { categoryId: category.id } }"
      :class="`category-tile tone-${index % 4}`"
      ><span class="category-mark">{{ marks[index % 4] }}</span>
      <div>
        <strong>{{ category.name }}</strong
        ><small>{{
          ['一口满足，小小幸福', '好好吃饭，活力满满', '犒劳每一个可爱瞬间', '用心照顾每一天'][
            index % 4
          ]
        }}</small>
      </div>
      <span>↗</span></router-link
    >
  </div>
</template>
