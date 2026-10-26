<script setup>
import { ref, watch, onMounted } from 'vue'
import DOMPurify from 'dompurify'
const props = defineProps({ content: String })
const root = ref(null)
function render() {
  if (!root.value) return
  const fragment = DOMPurify.sanitize(
    props.content || '<p>商品暂无详细说明，请以包装标示为准。</p>',
    {
      RETURN_DOM_FRAGMENT: true,
      ALLOWED_TAGS: [
        'p',
        'br',
        'strong',
        'b',
        'em',
        'i',
        'ul',
        'ol',
        'li',
        'h2',
        'h3',
        'h4',
        'img',
        'table',
        'thead',
        'tbody',
        'tr',
        'th',
        'td',
      ],
      ALLOWED_ATTR: ['src', 'alt', 'colspan', 'rowspan'],
    },
  )
  for (const img of fragment.querySelectorAll('img')) {
    const src = img.getAttribute('src') || ''
    if (!/^\/profile\//.test(src) && !/^https:\/\//i.test(src)) img.remove()
    else {
      img.loading = 'lazy'
      img.alt ||= '商品详情图片'
    }
  }
  root.value.replaceChildren(fragment)
}
onMounted(render)
watch(() => props.content, render)
</script>
<template><div ref="root" class="safe-description" /></template>
