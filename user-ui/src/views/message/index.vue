<script setup>
import { ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import * as api from '../../api/message.js'
import { useApp } from '../../stores/app.js'
import { useTask, useAction } from '../../composables/useTask.js'
import { messageTarget } from '../../utils/format.js'
import AsyncState from '../../components/AsyncState.vue'
import EmptyState from '../../components/EmptyState.vue'
import MemberNav from '../../components/MemberNav.vue'
const route = useRoute(),
  router = useRouter(),
  app = useApp(),
  page = ref({ list: [], total: 0 }),
  { loading, error, run } = useTask(),
  { busy, act } = useAction()
const load = () =>
  run(async () => {
    page.value = await api.list({
      pageNum: Number(route.query.pageNum) || 1,
      pageSize: 10,
      readFlag: route.query.readFlag === '0' ? 0 : undefined,
    })
    await app.refreshUnread()
  })
async function open(row) {
  await act(async () => {
    if (row.readFlag === 0) {
      await api.read(row.id)
      await app.refreshUnread()
    }
    router.push(messageTarget(row.targetUrl))
  })
}
async function allRead() {
  await act(async () => {
    await api.readAll()
    await load()
  }, '已将全部消息标记为已读')
}
watch(() => route.query, load, { immediate: true })
</script>
<template>
  <div class="page-heading heading-row">
    <div>
      <span class="eyebrow">A NOTE FOR YOU</span>
      <h1>消息中心</h1>
      <p>有关你和毛孩子的小小提醒。</p>
    </div>
    <el-button :disabled="!app.unread || busy" @click="allRead">全部已读</el-button>
  </div>
  <div class="member-layout">
    <MemberNav />
    <div>
      <el-tabs
        :model-value="String(route.query.readFlag || 'all')"
        @update:model-value="router.push({ query: $event === '0' ? { readFlag: 0 } : {} })"
        ><el-tab-pane label="全部消息" name="all" /><el-tab-pane
          :label="`未读消息 ${app.unread || ''}`"
          name="0" /></el-tabs
      ><AsyncState :loading="loading" :error="error" @retry="load"
        ><div v-if="page.list?.length" class="stack">
          <button
            v-for="row in page.list"
            :key="row.id"
            class="panel message-card"
            :class="{ unread: row.readFlag === 0 }"
            :disabled="busy"
            @click="open(row)"
          >
            <div class="row">
              <strong>{{ row.title }}</strong
              ><small>{{ row.createTime }}</small
              ><span v-if="row.readFlag === 0" class="dot"></span>
            </div>
            <p>{{ row.content }}</p>
            <span class="text-link">查看相关订单 →</span>
          </button>
        </div>
        <EmptyState
          v-else
          title="暂时没有消息"
          description="有新的订单动态时，会在这里告诉你。" /><el-pagination
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
