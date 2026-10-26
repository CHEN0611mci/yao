<script setup>
import { useMember } from '../stores/member.js'
import { useCart } from '../stores/cart.js'
import { useApp } from '../stores/app.js'
import SearchBar from './SearchBar.vue'
import Icon from './Icon.vue'
const member = useMember(),
  cart = useCart(),
  app = useApp()
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
      ><router-link to="/items" active-class="active">全部好物</router-link
      ><router-link to="/items?species=CAT">猫咪专区</router-link
      ><router-link to="/items?species=DOG">狗狗专区</router-link
      ><router-link to="/items?species=SMALL">小宠生活</router-link
      ><router-link to="/member/pets" class="nav-tail"
        >为它选，更合适 <Icon name="ArrowRight" :size="14"
      /></router-link>
    </div>
  </nav>
</template>
