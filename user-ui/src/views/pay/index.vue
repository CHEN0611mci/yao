<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import * as orderApi from '../../api/order.js'
import * as api from '../../api/pay.js'
import { useTask, useAction } from '../../composables/useTask.js'
import { timeLeft } from '../../utils/format.js'
import AsyncState from '../../components/AsyncState.vue'
import MoneyText from '../../components/MoneyText.vue'
import CountdownText from '../../components/CountdownText.vue'
import OrderStatusTag from '../../components/OrderStatusTag.vue'
const route = useRoute(),
  router = useRouter(),
  order = ref(null),
  channel = ref('WECHAT'),
  outcome = ref('SUCCESS'),
  expired = ref(false)
const { loading, error, run } = useTask(),
  { busy, act, actionError } = useAction()
const load = () =>
  run(async () => {
    order.value = await orderApi.detail(route.params.orderNo)
    expired.value = timeLeft(order.value.expireAt) <= 0
  })
async function pay() {
  if (busy.value || expired.value || order.value?.status !== 0) return
  await act(async () => {
    const result = await api.mock(
      { orderNo: order.value.orderNo, channel: channel.value, result: outcome.value },
      `UI-${order.value.orderNo}-${outcome.value}`,
    )
    await router.replace({
      path: '/pay/result',
      query: { orderNo: order.value.orderNo, result: result.status },
    })
  })
}
let querying = false
async function poll() {
  if (!order.value || busy.value || querying || document.hidden || order.value.status !== 0) return
  querying = true
  try {
    const value = await api.query(order.value.orderNo)
    if ([2, 3, 4].includes(value.orderStatus))
      router.replace({ path: '/pay/result', query: { orderNo: order.value.orderNo } })
    else if ([5, 6].includes(value.orderStatus)) await load()
  } catch {
    /* Keep the current order; explicit refresh exposes connection errors. */
  } finally {
    querying = false
  }
}
const timer = setInterval(poll, 8000)
onUnmounted(() => clearInterval(timer))
onMounted(load)
</script>
<template>
  <section class="payment-shell">
    <div class="page-heading centered">
      <span class="eyebrow">A LITTLE HAPPINESS IS ON ITS WAY</span>
      <h1>最后一步，把喜欢带回家</h1>
      <p>沙箱收银台 · 不会产生真实扣款</p>
    </div>
    <AsyncState :loading="loading" :error="error" @retry="load"
      ><div v-if="order" class="panel payment-card">
        <div class="payment-amount">
          <small>订单应付</small><MoneyText :value="order.payAmount" />
          <p>订单号 {{ order.orderNo }}</p>
          <OrderStatusTag :status="order.status" />
        </div>
        <template v-if="order.status === 0"
          ><p class="centered">
            请在 <CountdownText :until="order.expireAt" @expired="expired = true" /> 内完成支付
          </p>
          <el-alert
            v-if="expired"
            type="warning"
            title="付款时间已到，请刷新订单状态。超时关单由后端处理。"
            :closable="false"
          />
          <div class="field-block">
            <label>选择支付方式</label
            ><el-radio-group v-model="channel" class="payment-options" :disabled="busy"
              ><el-radio value="WECHAT" border>微信支付</el-radio
              ><el-radio value="ALIPAY" border>支付宝</el-radio
              ><el-radio value="BALANCE" border>余额支付</el-radio></el-radio-group
            >
          </div>
          <div class="sandbox-options">
            <label for="mock-outcome">沙箱演示结果</label
            ><el-select id="mock-outcome" v-model="outcome" :disabled="busy"
              ><el-option label="支付成功" value="SUCCESS" /><el-option
                label="支付失败"
                value="FAIL" /><el-option label="支付超时" value="TIMEOUT"
            /></el-select>
          </div>
          <el-button
            type="primary"
            size="large"
            class="full-width"
            :disabled="expired"
            :loading="busy"
            @click="pay"
            >确认沙箱支付</el-button
          ></template
        >
        <div v-else class="centered">
          <p>订单当前状态无需继续付款。</p>
          <router-link :to="`/orders/${order.orderNo}`" class="button">查看订单</router-link>
        </div>
        <el-alert v-if="actionError" type="error" :title="actionError" :closable="false" />
        <div class="payment-links">
          <router-link :to="`/orders/${order.orderNo}`">返回订单</router-link
          ><button @click="load">刷新订单状态</button>
        </div>
      </div></AsyncState
    >
  </section>
</template>
