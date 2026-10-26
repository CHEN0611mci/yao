<script setup>
import Icon from './Icon.vue'
</script>
<template>
  <aside class="member-nav panel">
    <span class="eyebrow">MY LITTLE WORLD</span>
    <h3>我的萌宠生活</h3>
    <router-link to="/member" exact-active-class="active"><Icon name="User" />个人中心</router-link
    ><router-link to="/orders"><Icon name="Document" />我的订单</router-link
    ><router-link to="/member/pets"><Icon name="Collection" />宠物档案</router-link
    ><router-link to="/member/addresses"><Icon name="Location" />收货地址</router-link
    ><router-link to="/member/favorites"><Icon name="Star" />我的收藏</router-link
    ><router-link to="/messages"><Icon name="Bell" />消息中心</router-link>
  </aside>
</template>
