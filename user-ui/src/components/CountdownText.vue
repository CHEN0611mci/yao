<script setup>
import { ref, computed, onUnmounted, watch } from 'vue'
import { timeLeft } from '../utils/format.js'
const props = defineProps({ until: String }),
  emit = defineEmits(['expired'])
const seconds = ref(timeLeft(props.until))
let emitted = false
function tick() {
  seconds.value = timeLeft(props.until)
  if (!seconds.value && !emitted) {
    emitted = true
    emit('expired')
  }
}
watch(
  () => props.until,
  () => {
    emitted = false
    tick()
  },
)
const timer = setInterval(tick, 1000)
onUnmounted(() => clearInterval(timer))
const text = computed(
  () =>
    `${String(Math.floor(seconds.value / 60)).padStart(2, '0')}:${String(seconds.value % 60).padStart(2, '0')}`,
)
</script>
<template>
  <span class="countdown" role="timer">{{ text }}</span>
</template>
