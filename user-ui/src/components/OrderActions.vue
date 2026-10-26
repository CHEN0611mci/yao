<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import * as orderApi from '../api/order.js'
import * as addressApi from '../api/address.js'
import * as itemApi from '../api/item.js'
import { useCart } from '../stores/cart.js'
import { useAction } from '../composables/useTask.js'
import AddressPicker from './AddressPicker.vue'
const props = defineProps({ order: Object }),
  emit = defineEmits(['changed'])
const cart = useCart(),
  router = useRouter(),
  dialog = ref(false),
  addresses = ref([]),
  addressId = ref(null)
const { busy, act, actionError } = useAction()
async function openAddress() {
  await act(async () => {
    addresses.value = await addressApi.list()
    addressId.value =
      addresses.value.find((x) => x.isDefault === 1)?.id || addresses.value[0]?.id || null
    dialog.value = true
  })
}
async function saveAddress() {
  if (!addressId.value) return
  await act(async () => {
    await orderApi.changeAddress(props.order.orderNo, addressId.value)
    dialog.value = false
    emit('changed')
  }, '订单收货地址已更新')
}
async function rebuy() {
  await act(async () => {
    const failures = []
    let added = 0
    const source = props.order.items || (await orderApi.detail(props.order.orderNo)).items || []
    for (const line of source) {
      try {
        const item = await itemApi.detail(line.itemId)
        const sku = item.skus.find((x) => x.id === line.skuId && x.status === 1)
        if (!sku) throw new Error('原规格已下架')
        await cart.add(item, sku, line.quantity, null)
        added++
      } catch (e) {
        failures.push(`${line.title}：${e.message}`)
      }
    }
    if (failures.length)
      ElMessage.warning({ message: `已加购 ${added} 项；${failures.join('；')}`, duration: 8000 })
    else ElMessage.success('原订单商品已按当前价格加入购物车')
    if (added) await router.push('/cart')
  })
}
</script>
<template>
  <el-button v-if="[0, 1, 2].includes(order.status)" :loading="busy" @click="openAddress"
    >修改收货地址</el-button
  >
  <el-button :loading="busy" @click="rebuy">再次购买</el-button>
  <p v-if="actionError" class="error-text" role="alert">{{ actionError }}</p>
  <el-dialog
    v-model="dialog"
    title="修改订单收货地址"
    width="min(620px, 94vw)"
    destroy-on-close
    :close-on-click-modal="!busy"
    :show-close="!busy"
    :close-on-press-escape="!busy"
  >
    <p class="muted">仅在订单发货前可修改，原订单金额保持不变。</p>
    <AddressPicker
      v-if="addresses.length"
      :addresses="addresses"
      v-model="addressId"
      :disabled="busy"
    />
    <p v-else>
      还没有收货地址，请先去<router-link to="/member/addresses">地址管理</router-link>添加。
    </p>
    <template #footer
      ><el-button :disabled="busy" @click="dialog = false">取消</el-button
      ><el-button type="primary" :disabled="!addressId" :loading="busy" @click="saveAddress"
        >保存订单地址</el-button
      ></template
    >
  </el-dialog>
</template>
