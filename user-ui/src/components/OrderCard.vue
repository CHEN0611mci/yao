<script setup>
import ImageWithFallback from './ImageWithFallback.vue'
import MoneyText from './MoneyText.vue'
import OrderStatusTag from './OrderStatusTag.vue'
defineProps({ order: Object })
</script>
<template>
  <article class="panel order-card">
    <div class="order-card-head">
      <div>
        <small>{{ order.createTime }}</small
        ><span>订单号 {{ order.orderNo }}</span>
      </div>
      <OrderStatusTag :status="order.status" />
    </div>
    <router-link :to="`/orders/${order.orderNo}`" class="order-items"
      ><div v-for="(item, index) in order.items" :key="index" class="order-line">
        <ImageWithFallback :src="item.image" :alt="item.title" />
        <div>
          <strong>{{ item.title }}</strong>
          <p>{{ item.spec }}</p>
        </div>
        <MoneyText :value="item.price" /><span>× {{ item.quantity }}</span>
      </div></router-link
    >
    <div class="order-card-foot">
      <span>实付 <MoneyText :value="order.payAmount" /></span>
      <div class="actions">
        <router-link :to="`/orders/${order.orderNo}`" class="button secondary">订单详情</router-link
        ><router-link v-if="order.status === 0" :to="`/pay/${order.orderNo}`" class="button"
          >去付款</router-link
        ><slot />
      </div>
    </div>
  </article>
</template>
