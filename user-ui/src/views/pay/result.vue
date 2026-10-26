<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import * as api from '../../api/pay.js'
import * as orders from '../../api/order.js'
import { useTask } from '../../composables/useTask.js'
import AsyncState from '../../components/AsyncState.vue'
import MoneyText from '../../components/MoneyText.vue'
const route = useRoute(),
  result = ref(null),
  order = ref(null),
  { loading, error, run } = useTask()
// Query parameters never establish payment success; always query the owning account's order.
const paid = computed(() => [2, 3, 4].includes(order.value?.status))
const title = computed(() =>
  paid.value
    ? '支付成功，小快乐即将出发'
    : result.value?.status === 'TIMEOUT'
      ? '支付超时，还差一点点'
      : result.value?.status === 'FAILED'
        ? '支付未完成，再试一次吧'
        : '订单尚未支付',
)
const load = () =>
  run(async () => {
    const no = String(route.query.orderNo || '')
    if (!/^[A-Za-z0-9_-]+$/.test(no)) throw new Error('缺少有效订单号')
    const data = await Promise.all([api.query(no), orders.detail(no)])
    result.value = data[0]
    order.value = data[1]
  })
onMounted(load)
</script>
<template>
  <section class="payment-shell">
    <AsyncState :loading="loading" :error="error" @retry="load"
      ><div v-if="order" class="panel result-card">
        <div class="result-mark" :class="{ success: paid }">{{ paid ? '✓' : '!' }}</div>
        <h1>{{ title }}</h1>
        <p class="muted">
          {{
            paid
              ? '这份认真挑选的喜欢，正在向它靠近。'
              : '请以当前订单状态为准，可返回订单查看详情。'
          }}
        </p>
        <MoneyText :value="order.payAmount" />
        <p>订单号 {{ order.orderNo }}</p>
        <p class="muted">沙箱支付演示，无真实扣款</p>
        <div class="actions">
          <router-link :to="`/orders/${order.orderNo}`" class="button">查看订单</router-link
          ><router-link
            v-if="order.status === 0"
            :to="`/pay/${order.orderNo}`"
            class="button secondary"
            >重新支付</router-link
          ><router-link v-else to="/items" class="button secondary">继续逛逛</router-link
          ><el-button @click="load">刷新结果</el-button>
        </div>
      </div></AsyncState
    >
  </section>
</template>
