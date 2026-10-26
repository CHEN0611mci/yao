<script setup>
import { computed } from 'vue'
const props = defineProps({ adapt: Object })
const text = computed(
  () =>
    ({ SUITABLE: '适合', CAUTION: '需注意', UNSUITABLE: '不适合', UNKNOWN: '待确认' })[
      props.adapt?.level
    ] || '待确认',
)
</script>
<template>
  <el-tooltip v-if="adapt" :content="(adapt.reasons || []).join('；') || text"
    ><span class="adapt-tag" :class="adapt.level"
      >{{ adapt.petName ? `${adapt.petName} · ` : '' }}{{ text }}</span
    ></el-tooltip
  >
</template>
