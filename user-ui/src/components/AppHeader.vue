<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useMember } from '../stores/member.js'
import { useCart } from '../stores/cart.js'
import { useApp } from '../stores/app.js'
import SearchBar from './SearchBar.vue'
import Icon from './Icon.vue'
const member = useMember(),
  cart = useCart(),
  app = useApp()
const route = useRoute()
// 分区高亮：四个入口共用 /items 这条路由记录，物种只体现在 query 上，
// 不能交给 router-link 的 active-class（它按路由记录匹配、不看 query，
// 会让「全部好物」在专区页也保持高亮），这里按 query.species 自行判定。
const SECTION_KEYS = ['CAT', 'DOG', 'SMALL']
const activeSection = computed(() => {
  if (route.path !== '/items') return ''
  const key = String(route.query.species || '').toUpperCase()
  return SECTION_KEYS.includes(key) ? key : 'ALL'
})
</script>
<template>
  <div class="utility">
    <div class="container utility-inner">
      <span>每一份陪伴，都值得认真挑选</span>
      <div>
        <router-link to="/orders">我的订单</router-link
        ><router-link to="/messages">消息<span v-if="app.unread" class="dot"></span></router-link
        ><router-link :to="member.loggedIn ? '/member' : '/login'">{{
          member.profile?.nickname || '登录 / 注册'
        }}</router-link>
      </div>
    </div>
  </div>
  <header class="app-header">
    <div class="container header-inner">
      <router-link to="/" class="brand"
        ><img src="/images/logo.svg" alt="" /><span
          >萌宠优选<small>PET & GOOD</small></span
        ></router-link
      ><SearchBar />
      <div class="header-actions">
        <router-link to="/member/pets" class="pet-link"
          ><span class="paw-small">✦</span><span>我的毛孩子</span></router-link
        ><router-link to="/cart" class="cart-link" aria-label="购物车"
          ><el-badge :value="cart.count" :hidden="!cart.count" :max="99"
            ><Icon name="ShoppingCart" :size="25" /></el-badge
          ><span class="hide-mobile">购物车</span></router-link
        >
      </div>
    </div>
  </header>
  <nav class="category-bar">
    <div class="container">
      <router-link to="/" exact-active-class="active">首页</router-link
      ><router-link to="/items" :class="{ active: activeSection === 'ALL' }">全部好物</router-link
      ><router-link to="/items?species=CAT" :class="{ active: activeSection === 'CAT' }"
        >猫咪专区</router-link
      ><router-link to="/items?species=DOG" :class="{ active: activeSection === 'DOG' }"
        >狗狗专区</router-link
      ><router-link to="/items?species=SMALL" :class="{ active: activeSection === 'SMALL' }"
        >小宠生活</router-link
      ><router-link to="/member/pets" class="nav-tail"
        >为它选，更合适 <Icon name="ArrowRight" :size="14"
      /></router-link>
    </div>
  </nav>
</template>
