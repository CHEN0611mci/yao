<script setup>
import { ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import * as api from '../../api/order.js'
import { orderTabs, cancelledPage } from '../../utils/orders.js'
import { useTask, useAction, confirm } from '../../composables/useTask.js'
import MemberNav from '../../components/MemberNav.vue'
import OrderCard from '../../components/OrderCard.vue'
import AsyncState from '../../components/AsyncState.vue'
import EmptyState from '../../components/EmptyState.vue'
import OrderActions from '../../components/OrderActions.vue'
const keyword = ref('')
const route = useRoute(),
  router = useRouter(),
  page = ref({ list: [], total: 0 }),
  { loading, error, run } = useTask(),
  { busy, act } = useAction()
let generation = 0
const load = () =>
  run(async () => {
    keyword.value = String(route.query.keyword || '')
    const id = ++generation,
      pageNum = Math.max(1, Number(route.query.pageNum) || 1),
      status = String(route.query.status || 'all')
    const data =
      status === 'cancelled'
        ? await cancelledPage(
            (params) => api.list({ ...params, keyword: route.query.keyword }),
            pageNum,
          )
        : await api.list({
            pageNum,
            pageSize: 10,
            keyword: route.query.keyword,
            status: /^\d$/.test(status) ? Number(status) : undefined,
          })
    if (id === generation) page.value = data
  })
async function receive(row) {
  if (await confirm('请确认已经收到商品，再确认收货。'))
    await act(async () => {
      await api.confirm(row.orderNo)
      await load()
    }, '已确认收货')
}
watch(() => route.query, load, { immediate: true })
</script>
<template>
  <div class="page-heading">
    <span class="eyebrow">EVERY PACKAGE, A LITTLE JOY</span>
    <h1>我的订单</h1>
    <p>每一份小快乐，都有迹可循。</p>
  </div>
  <div class="member-layout">
    <MemberNav />
    <div>
      <el-tabs
        :model-value="String(route.query.status || 'all')"
        @update:model-value="router.push({ query: { ...route.query, pageNum: 1, status: $event } })"
        ><el-tab-pane v-for="tab in orderTabs" :key="tab[0]" :name="tab[0]" :label="tab[1]"
      /></el-tabs>
      <form
        class="order-search"
        @submit.prevent="
          router.push({ query: { ...route.query, keyword: keyword.trim(), pageNum: 1 } })
        "
      >
        <el-input
          v-model="keyword"
          placeholder="搜索订单号或商品名称"
          aria-label="搜索订单"
          clearable
          maxlength="100"
        /><el-button native-type="submit">搜索订单</el-button>
      </form>
      <AsyncState :loading="loading" :error="error" @retry="load"
        ><div v-if="page.list?.length" class="stack">
          <OrderCard v-for="order in page.list" :key="order.orderNo" :order="order"
            ><el-button
              v-if="order.status === 3"
              type="primary"
              :loading="busy"
              @click="receive(order)"
              >确认收货</el-button
            ><OrderActions :order="order" @changed="load"
          /></OrderCard>
        </div>
        <EmptyState
          v-else
          title="这个分类还没有订单"
          description="去挑选一份它喜欢的好物吧。"
          to="/items" /><el-pagination
          v-if="page.total > 10"
          class="pagination"
          layout="prev, pager, next"
          :pager-count="5"
          :page-size="10"
          :total="page.total"
          :current-page="Number(route.query.pageNum) || 1"
          @current-change="router.push({ query: { ...route.query, pageNum: $event } })"
      /></AsyncState>
    </div>
  </div>
</template>
