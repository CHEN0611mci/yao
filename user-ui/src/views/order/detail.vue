<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import * as api from '../../api/order.js'
import { useTask, useAction, confirm } from '../../composables/useTask.js'
import { parseSnapshot, petSnapshotName } from '../../utils/format.js'
import AsyncState from '../../components/AsyncState.vue'
import OrderStatusTag from '../../components/OrderStatusTag.vue'
import MoneyText from '../../components/MoneyText.vue'
import ImageWithFallback from '../../components/ImageWithFallback.vue'
import StatusTimeline from '../../components/StatusTimeline.vue'
import CountdownText from '../../components/CountdownText.vue'
import ConfirmDialog from '../../components/ConfirmDialog.vue'
import OrderActions from '../../components/OrderActions.vue'
const route = useRoute(),
  order = ref(null),
  cancelDialog = ref(false),
  reason = ref(''),
  { loading, error, run } = useTask(),
  { busy, act, actionError } = useAction()
const receiver = computed(() => parseSnapshot(order.value?.receiverSnapshot))
const load = () =>
  run(async () => {
    order.value = await api.detail(route.params.orderNo)
  })
async function cancel() {
  const ok = await act(async () => {
    await api.cancel(order.value.orderNo, reason.value.trim())
    await load()
  }, '订单已取消')
  if (ok) cancelDialog.value = false
}
async function receive() {
  if (await confirm('请确认已经收到商品，再确认收货。'))
    await act(async () => {
      await api.confirm(order.value.orderNo)
      await load()
    }, '已确认收货')
}
onMounted(load)
</script>
<template>
  <div class="breadcrumb"><router-link to="/orders">我的订单</router-link> / 订单详情</div>
  <AsyncState :loading="loading" :error="error" @retry="load"
    ><template v-if="order"
      ><section class="panel order-overview">
        <div>
          <span class="eyebrow">ORDER DETAILS</span>
          <h1><OrderStatusTag :status="order.status" /></h1>
          <p>订单号 {{ order.orderNo }}</p>
          <p v-if="order.status === 0">剩余付款时间 <CountdownText :until="order.expireAt" /></p>
          <p v-if="order.cancelReason" class="muted">取消原因：{{ order.cancelReason }}</p>
        </div>
        <div class="actions">
          <router-link v-if="order.status === 0" :to="`/pay/${order.orderNo}`" class="button"
            >去付款</router-link
          ><el-button v-if="order.status === 0" :disabled="busy" @click="cancelDialog = true"
            >取消订单</el-button
          ><el-button v-if="order.status === 3" type="primary" :loading="busy" @click="receive"
            >确认收货</el-button
          ><OrderActions :order="order" @changed="load" /><el-button :disabled="busy" @click="load"
            >刷新状态</el-button
          >
        </div>
      </section>
      <div class="order-detail-columns">
        <section class="panel">
          <h2>收货信息</h2>
          <p>
            <strong>{{ receiver.receiver || '—' }}</strong> {{ receiver.phone }}
          </p>
          <p>
            {{ receiver.province }} {{ receiver.city }} {{ receiver.district }}
            {{ receiver.detail }}
          </p>
          <div v-if="receiver.logistics" class="logistics">
            <h3>配送信息</h3>
            <p>{{ receiver.logistics.company }} · {{ receiver.logistics.trackingNo }}</p>
            <p class="muted">发货时间：{{ receiver.logistics.shipTime || order.shipTime }}</p>
          </div>
          <p v-else class="muted">暂无发货信息</p>
          <h3>订单备注</h3>
          <p>{{ order.remark || '无' }}</p>
        </section>
        <section class="panel">
          <h2>订单动态</h2>
          <StatusTimeline :order="order" />
        </section>
      </div>
      <section class="panel">
        <h2>商品清单</h2>
        <div v-for="(item, index) in order.items" :key="index" class="order-line">
          <ImageWithFallback :src="item.image" :alt="item.title" />
          <div>
            <strong>{{ item.title }}</strong>
            <p>
              {{ item.spec
              }}<span v-if="petSnapshotName(item.petSnapshot)">
                · 给{{ petSnapshotName(item.petSnapshot) }}</span
              >
            </p>
          </div>
          <MoneyText :value="item.price" /><span>× {{ item.quantity }}</span
          ><MoneyText :value="item.amount" />
        </div>
        <div class="amount-breakdown">
          <div><span>商品金额</span><MoneyText :value="order.totalAmount" /></div>
          <div>
            <span>优惠</span><span>− <MoneyText :value="order.discountAmount" /></span>
          </div>
          <div><span>运费</span><MoneyText :value="order.freight" /></div>
          <div class="amount-total">
            <strong>应付金额</strong><MoneyText :value="order.payAmount" />
          </div>
        </div>
      </section>
      <section v-if="order.payment" class="panel">
        <h2>支付信息</h2>
        <p>支付流水：{{ order.payment.paymentNo }}</p>
        <p>
          渠道：{{
            { WECHAT: '微信支付', ALIPAY: '支付宝', BALANCE: '余额' }[order.payment.channel] ||
            order.payment.channel
          }}（沙箱）
        </p>
        <p>
          状态：{{
            { SUCCESS: '成功', FAILED: '失败', TIMEOUT: '超时' }[order.payment.status] || '待确认'
          }}
        </p>
      </section></template
    ></AsyncState
  ><el-alert v-if="actionError" :title="actionError" type="error" :closable="false" /><ConfirmDialog
    v-model="cancelDialog"
    title="取消这笔订单？"
    :busy="busy"
    @confirm="cancel"
    ><p>取消后将返还商品库存。请填写取消原因（选填）。</p>
    <el-input v-model="reason" type="textarea" maxlength="200" show-word-limit
  /></ConfirmDialog>
</template>
