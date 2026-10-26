<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import * as addressApi from '../../api/address.js'
import * as api from '../../api/order.js'
import { useMember } from '../../stores/member.js'
import { useCart } from '../../stores/cart.js'
import { useTask, useAction } from '../../composables/useTask.js'
import { orderItems } from '../../utils/format.js'
import { readStorage, writeStorage } from '../../utils/storage.js'
import AsyncState from '../../components/AsyncState.vue'
import EmptyState from '../../components/EmptyState.vue'
import AddressPicker from '../../components/AddressPicker.vue'
import ImageWithFallback from '../../components/ImageWithFallback.vue'
import MoneyText from '../../components/MoneyText.vue'
const route = useRoute(),
  router = useRouter(),
  member = useMember(),
  cart = useCart(),
  addresses = ref([]),
  addressId = ref(null),
  remark = ref(''),
  preview = ref(null)
const key = `checkout_pending:${member.profile?.id}`,
  pending = ref(readStorage(key, null, sessionStorage))
const { loading, error, run } = useTask(),
  { busy, act, actionError } = useAction()
const rows = computed(() =>
  route.query.from === 'buynow'
    ? cart.rows.filter((row) => row.skuId === Number(route.query.skuId) && row.valid)
    : cart.checked,
)
const crossShop = computed(() => new Set(rows.value.map((row) => row.item?.merchantId)).size > 1)
const ready = computed(
  () =>
    !!preview.value &&
    !!addressId.value &&
    rows.value.length > 0 &&
    !crossShop.value &&
    !preview.value.stockWarning?.length,
)
const load = () =>
  run(async () => {
    if (pending.value) return
    preview.value = null
    const result = await Promise.all([addressApi.list(), cart.fetch()])
    addresses.value = result[0] || []
    addressId.value =
      addresses.value.find((row) => row.isDefault === 1)?.id || addresses.value[0]?.id || null
    if (rows.value.length) await refreshPreview()
  })
async function refreshPreview() {
  preview.value = await api.preview({
    skuIds: rows.value.map((row) => row.skuId),
    addressId: addressId.value,
  })
}
async function chooseAddress(value) {
  addressId.value = value
  await run(refreshPreview)
}
async function send(payload) {
  // Save the complete payload before sending; network retries use exactly the same token.
  pending.value = payload
  writeStorage(key, payload, sessionStorage)
  try {
    const result = await api.submit(payload)
    sessionStorage.removeItem(key)
    pending.value = null
    await cart.fetch().catch(() => {})
    await router.replace(`/pay/${result.orderNo}`)
  } catch (e) {
    if (e.status >= 400 && e.status < 500) {
      sessionStorage.removeItem(key)
      pending.value = null
      await cart.fetch().catch(() => {})
      await refreshPreview().catch(() => {})
    }
    throw e
  }
}
async function submit() {
  if (!ready.value || busy.value) return
  const payload = {
    addressId: addressId.value,
    clientToken: crypto.randomUUID(),
    items: orderItems(rows.value),
    remark: remark.value.trim(),
  }
  await act(() => send(payload))
}
onMounted(load)
</script>
<template>
  <div class="page-heading">
    <span class="eyebrow">ONE STEP CLOSER TO HAPPINESS</span>
    <h1>确认这份小快乐</h1>
    <p>核对收货信息与商品，金额以本次结算试算为准。</p>
  </div>
  <el-alert
    v-if="pending"
    type="warning"
    title="有一笔提交结果待确认。请使用原请求确认订单，避免重复下单。"
    :closable="false"
    show-icon
  />
  <div v-if="pending" class="panel pending-order">
    <p>已保存原始订单请求。即使网络中断，也会沿用原幂等键。</p>
    <el-button type="primary" :loading="busy" @click="act(() => send(pending))"
      >确认上次提交结果</el-button
    ><router-link to="/orders" class="text-link">查看我的订单</router-link>
  </div>
  <AsyncState v-else :loading="loading" :error="error" @retry="load"
    ><template v-if="rows.length"
      ><section class="panel">
        <div class="section-heading compact">
          <h2>01 / 送到哪里</h2>
          <router-link to="/member/addresses" class="text-link">管理收货地址 ↗</router-link>
        </div>
        <AddressPicker
          v-if="addresses.length"
          :model-value="addressId"
          :addresses="addresses"
          :disabled="busy"
          @update:model-value="chooseAddress"
        /><EmptyState
          v-else
          title="先添加一个收货地址"
          description="好物需要一个可以送达的地方。"
          to="/member/addresses"
          action="添加地址"
        />
      </section>
      <section class="panel checkout-products">
        <h2>02 / 带这些回家</h2>
        <div v-for="row in preview?.items || []" :key="row.skuId" class="order-line">
          <ImageWithFallback :src="row.image" :alt="row.title" />
          <div>
            <strong>{{ row.title }}</strong>
            <p>
              {{ row.spec }}<span v-if="row.petName"> · 给{{ row.petName }}</span>
            </p>
          </div>
          <span>× {{ row.quantity }}</span
          ><MoneyText :value="row.amount" />
        </div>
        <el-alert
          v-if="crossShop"
          type="warning"
          title="仅支持同一店铺的商品一起结算，请返回购物车调整。"
          :closable="false"
        /><el-alert
          v-for="warning in preview?.stockWarning || []"
          :key="warning"
          type="warning"
          :title="String(warning)"
          :closable="false"
        /><label for="order-remark" class="field-label">给商家的留言（选填）</label
        ><el-input
          id="order-remark"
          v-model="remark"
          type="textarea"
          maxlength="200"
          show-word-limit
          placeholder="还有什么需要叮嘱的？"
          :disabled="busy"
        />
      </section>
      <section v-if="preview" class="panel checkout-summary">
        <div class="amount-breakdown">
          <div><span>商品金额</span><MoneyText :value="preview.totalAmount" /></div>
          <div>
            <span>优惠</span><span>− <MoneyText :value="preview.discountAmount" /></span>
          </div>
          <div>
            <span>运费{{ preview.freeShipping ? '（已包邮）' : '' }}</span
            ><MoneyText :value="preview.freight" />
          </div>
          <div class="amount-total">
            <strong>应付金额</strong><MoneyText :value="preview.payAmount" />
          </div>
          <el-button type="primary" size="large" :disabled="!ready" :loading="busy" @click="submit"
            >提交订单 →</el-button
          ><small>提交后进入沙箱支付，不会产生真实扣款。</small>
        </div>
      </section></template
    ><EmptyState v-else title="还没有选择结算商品" to="/cart" action="返回购物车" /></AsyncState
  ><el-alert v-if="actionError" type="error" :title="actionError" :closable="false" />
</template>
