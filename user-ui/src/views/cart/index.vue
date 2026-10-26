<script setup>
import { computed, ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useCart } from '../../stores/cart.js'
import { usePet } from '../../stores/pet.js'
import * as api from '../../api/cart.js'
import { useTask, useAction, confirm } from '../../composables/useTask.js'
import AsyncState from '../../components/AsyncState.vue'
import EmptyState from '../../components/EmptyState.vue'
import ImageWithFallback from '../../components/ImageWithFallback.vue'
import MoneyText from '../../components/MoneyText.vue'
import QuantityStepper from '../../components/QuantityStepper.vue'
import PetSelector from '../../components/PetSelector.vue'
const cart = useCart(),
  pet = usePet(),
  router = useRouter(),
  { loading, error, run } = useTask(),
  { busy, act, actionError } = useAction()
const allChecked = computed(
  () =>
    cart.rows.some((row) => row.valid) &&
    cart.rows.filter((row) => row.valid).every((row) => row.checked === 1),
)
const merchants = computed(() => new Set(cart.checked.map((row) => row.item?.merchantId)).size)
const petFilter = ref(null)
const visibleRows = computed(() =>
  petFilter.value ? cart.rows.filter((x) => x.petId === petFilter.value) : cart.rows,
)
async function clearInvalid() {
  const rows = cart.rows.filter((x) => !x.valid)
  if (!rows.length || !(await confirm(`清理 ${rows.length} 件失效商品？`))) return
  await act(async () => {
    for (const row of rows) await api.remove(row.id)
    await cart.fetch()
  }, '失效商品已清理')
}
async function removeChecked() {
  const rows = cart.checked
  if (!rows.length || !(await confirm(`移除已选的 ${rows.length} 件商品？`))) return
  await act(async () => {
    try {
      for (const row of rows) await api.remove(row.id)
    } finally {
      await cart.fetch()
    }
  }, '已移除所选商品')
}
const load = () =>
  run(async () => {
    await cart.fetch()
    await pet.fetch()
  })
async function change(row, data) {
  await act(async () => {
    try {
      await cart.change(row.id, data)
    } catch (e) {
      await cart.fetch().catch(() => {})
      throw e
    }
  })
}
async function selectAll(value) {
  await act(async () => {
    try {
      for (const row of cart.rows.filter((row) => row.valid))
        await api.update(row.id, { checked: value ? 1 : 0 })
    } finally {
      await cart.fetch()
    }
  })
}
async function remove(row) {
  if (await confirm('确定将这件商品移出购物车吗？'))
    await act(() => cart.remove(row.id), '已移出购物车')
}
onMounted(load)
</script>
<template>
  <div class="page-heading">
    <span class="eyebrow">THEIR NEXT LITTLE JOYS</span>
    <h1>
      购物车 <small>{{ cart.rows.length }} 件好物</small>
    </h1>
    <p>喜欢的都在这里，再确认一下，就可以带回家。</p>
  </div>
  <div class="cart-tools panel">
    <span>按宠物查看</span><PetSelector :pets="pet.rows" v-model="petFilter" />
    <el-button :disabled="!cart.checked.length || busy" @click="removeChecked">移除所选</el-button
    ><el-button :loading="busy" :disabled="!cart.rows.some((x) => !x.valid)" @click="clearInvalid"
      >清理失效商品</el-button
    >
  </div>
  <div v-if="cart.mergeErrors.length || cart.guestRows.length" class="panel merge-notice">
    <h3>部分游客购物车商品还未合并</h3>
    <p v-for="(row, index) in cart.mergeErrors" :key="index">{{ row.title }}：{{ row.error }}</p>
    <el-button :loading="busy" @click="act(() => cart.merge())">重新合并</el-button>
  </div>
  <AsyncState :loading="loading" :error="error" @retry="load"
    ><template v-if="cart.rows.length"
      ><div class="cart-table-head">
        <el-checkbox :model-value="allChecked" :disabled="busy" @change="selectAll"
          >全选</el-checkbox
        ><span>商品信息</span><span>单价 / 数量</span><span>小计</span>
      </div>
      <article
        v-for="row in visibleRows"
        :key="row.id"
        class="panel cart-row"
        :class="{ invalid: !row.valid }"
      >
        <el-checkbox
          :model-value="row.checked === 1 && !!row.valid"
          :disabled="!row.valid || busy"
          :aria-label="`选择${row.item?.title || '商品'}`"
          @change="change(row, { checked: $event ? 1 : 0 })"
        /><router-link :to="`/items/${row.itemId}`" class="cart-image"
          ><ImageWithFallback :src="row.sku?.image || row.item?.mainImage" :alt="row.item?.title"
        /></router-link>
        <div class="cart-info">
          <router-link :to="`/items/${row.itemId}`"
            ><strong>{{ row.item?.title || '商品已失效' }}</strong></router-link
          >
          <p>{{ row.sku?.specName }}</p>
          <p v-if="!row.valid" class="error-text">{{ row.invalidReason || '商品暂时不可购买' }}</p>
          <small v-else-if="row.sku?.stock < 4" class="notice-text"
            >仅剩 {{ row.sku?.stock }} 件</small
          ><PetSelector
            v-if="pet.rows.length"
            :model-value="row.petId"
            :pets="pet.rows"
            :clearable="true"
            :disabled="busy"
            @update:model-value="change(row, $event ? { petId: $event } : { clearPet: true })"
          />
        </div>
        <div class="cart-quantity">
          <MoneyText :value="row.sku?.price" /><QuantityStepper
            :model-value="row.quantity"
            :max="row.sku?.stock || 99"
            :disabled="busy || !row.valid"
            @update:model-value="change(row, { quantity: $event })"
          />
        </div>
        <div class="cart-subtotal">
          <MoneyText :value="row.amount" /><el-button text :disabled="busy" @click="remove(row)"
            >移除</el-button
          >
        </div>
      </article>
      <el-alert v-if="actionError" type="error" :title="actionError" :closable="false" /><el-alert
        v-if="merchants > 1"
        type="warning"
        title="当前后端仅支持同一店铺的商品一起结算，请调整勾选。"
        :closable="false"
      />
      <div class="cart-checkout panel">
        <el-checkbox :model-value="allChecked" :disabled="busy" @change="selectAll"
          >全选</el-checkbox
        ><span class="muted">全部购物车已选 {{ cart.checked.length }} 件好物（含筛选外商品）</span>
        <div class="cart-checkout-right">
          <span class="muted">运费与实付金额将在结算时确认</span
          ><el-button
            type="primary"
            size="large"
            :disabled="!cart.checked.length || merchants > 1 || busy"
            @click="router.push('/checkout?from=cart')"
            >去结算 →</el-button
          >
        </div>
      </div></template
    ><EmptyState
      v-else
      title="购物车在等一点小快乐"
      description="去挑一份它会喜欢的好物吧。"
      to="/items"
  /></AsyncState>
</template>
