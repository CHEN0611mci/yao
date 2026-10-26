<script setup>
import { species, ages } from '../utils/format.js'
defineProps({ modelValue: Object, categories: Array })
defineEmits(['change'])
</script>
<template>
  <div class="filter-bar panel">
    <div class="filter-row">
      <strong>分类</strong
      ><button
        :class="{ active: !modelValue.categoryId }"
        @click="$emit('change', 'categoryId', '')"
      >
        全部</button
      ><template v-for="category in categories" :key="category.id"
        ><button
          :class="{ active: String(modelValue.categoryId) === String(category.id) }"
          @click="$emit('change', 'categoryId', category.id)"
        >
          {{ category.name }}</button
        ><button
          v-for="child in category.children"
          :key="child.id"
          :class="{ active: String(modelValue.categoryId) === String(child.id) }"
          @click="$emit('change', 'categoryId', child.id)"
        >
          {{ child.name }}
        </button></template
      >
    </div>
    <div class="filter-row">
      <strong>为谁挑选</strong
      ><button :class="{ active: !modelValue.species }" @click="$emit('change', 'species', '')">
        全部宠物</button
      ><button
        v-for="(label, key) in species"
        :key="key"
        :class="{ active: modelValue.species === key }"
        @click="$emit('change', 'species', key)"
      >
        {{ label }}
      </button>
    </div>
    <div class="filter-row">
      <strong>年龄阶段</strong
      ><button :class="{ active: !modelValue.ageStage }" @click="$emit('change', 'ageStage', '')">
        不限</button
      ><button
        v-for="(label, key) in ages"
        :key="key"
        :class="{ active: modelValue.ageStage === key }"
        @click="$emit('change', 'ageStage', key)"
      >
        {{ label }}
      </button>
    </div>
    <slot />
  </div>
</template>
