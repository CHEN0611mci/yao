<script setup>
import Icon from './Icon.vue'
</script>
<template>
  <nav class="bottom-nav" aria-label="移动导航">
    <router-link to="/"><Icon name="House" />首页</router-link
    ><router-link to="/items"><Icon name="Grid" />好物</router-link
    ><router-link to="/cart"><Icon name="ShoppingCart" />购物车</router-link
    ><router-link to="/member"><Icon name="User" />我的</router-link>
  </nav>
</template>
