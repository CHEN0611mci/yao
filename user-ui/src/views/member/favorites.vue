<script setup>
import { ref, onMounted } from 'vue'
import * as api from '../../api/favorites.js'
import { useTask, useAction, confirm } from '../../composables/useTask.js'
import MemberNav from '../../components/MemberNav.vue'
import ItemCard from '../../components/ItemCard.vue'
import AsyncState from '../../components/AsyncState.vue'
import EmptyState from '../../components/EmptyState.vue'
const rows = ref([]),
  total = ref(0),
  page = ref(1)
const { loading, error, run } = useTask(),
  { busy, act } = useAction()
const available = (row) =>
  row.status === 1 && row.auditStatus === 2 && row.delFlag !== '1' && row.isPrescription !== 1
const fetchRows = async () => {
  let result = await api.list({ pageNum: page.value, pageSize: 12 })
  if (!result.list.length && page.value > 1) {
    page.value = Math.max(1, Math.ceil(result.total / 12))
    result = await api.list({ pageNum: page.value, pageSize: 12 })
  }
  rows.value = result.list
  total.value = result.total
}
const load = () => run(fetchRows)
async function remove(row) {
  if (!(await confirm(`取消收藏“${row.title}”吗？`))) return
  await act(async () => {
    await api.remove(row.id)
    await fetchRows()
  }, '已取消收藏')
}
onMounted(load)
</script>
<template>
  <div class="page-heading">
    <span class="eyebrow">SAVE YOUR LITTLE FAVORITES</span>
    <h1>我的收藏</h1>
    <p>把喜欢的好物留下，下次再来慢慢挑。共 {{ total }} 件。</p>
  </div>
  <div class="member-layout">
    <MemberNav />
    <AsyncState :loading="loading" :error="error" @retry="load">
      <div v-if="rows.length">
        <div class="favorite-grid">
          <div v-for="row in rows" :key="row.id" class="favorite-entry">
            <ItemCard v-if="available(row)" :item="row" />
            <div v-else class="panel unavailable">
              <h3>{{ row.title }}</h3>
              <p class="muted">该商品暂不可购买，收藏仍为你保留。</p>
            </div>
            <el-button :disabled="busy" @click="remove(row)">取消收藏</el-button>
          </div>
        </div>
        <el-pagination
          v-if="total > 12"
          v-model:current-page="page"
          :page-size="12"
          :total="total"
          layout="prev, pager, next"
          @current-change="load"
        />
      </div>
      <EmptyState
        v-else
        title="还没有收藏好物"
        description="在商品详情点击“收藏好物”，就能在这里找到。"
        ><router-link class="text-link" to="/items">去挑选好物 ↗</router-link></EmptyState
      >
    </AsyncState>
  </div>
</template>
<style scoped>
.favorite-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 24px;
}
.favorite-entry {
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.unavailable {
  flex: 1;
  min-height: 240px;
}
.el-pagination {
  margin-top: 28px;
  justify-content: center;
}
@media (max-width: 1000px) {
  .favorite-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
@media (max-width: 550px) {
  .favorite-grid {
    grid-template-columns: minmax(0, 1fr);
  }
}
</style>
