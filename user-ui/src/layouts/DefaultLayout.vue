<script setup>
import { watch } from 'vue'
import { useRoute } from 'vue-router'
import { useMember } from '../stores/member.js'
import { useCart } from '../stores/cart.js'
import { useApp } from '../stores/app.js'
import AppHeader from '../components/AppHeader.vue'
import AppFooter from '../components/AppFooter.vue'
import BottomNav from '../components/BottomNav.vue'
import SupportPanel from '../components/SupportPanel.vue'
const member = useMember(),
  cart = useCart(),
  app = useApp()
const route = useRoute()
watch(
  () => [member.loggedIn, route.path],
  ([value]) => {
    if (value) {
      cart.fetch().catch(() => {})
      app.refreshUnread().catch(() => {})
    }
  },
  { immediate: true },
)
</script>
<template>
  <AppHeader />
  <main id="main" class="container main-content"><slot /></main>
  <AppFooter /><BottomNav /><SupportPanel />
</template>
