<script setup>
import { ref, onMounted } from 'vue'
import * as api from '../api/member.js'
import { useTask, useAction, confirm } from '../composables/useTask.js'
import AsyncState from './AsyncState.vue'
const rows = ref([]),
  { loading, error, run } = useTask(),
  { busy, act } = useAction()
const fetchRows = async () => {
  rows.value = await api.sessions()
}
const load = () => run(fetchRows)
const time = (value) =>
  value ? new Date(value).toLocaleString('zh-CN', { hour12: false }) : '未知'
async function revoke(row) {
  if (!(await confirm('使这次登录立即失效吗？该设备需要重新登录。'))) return
  await act(async () => {
    await api.revokeSession(row.id)
    await fetchRows()
  }, '该设备已退出')
}
async function revokeOthers() {
  if (!(await confirm('退出其他全部登录设备，保留当前登录吗？'))) return
  await act(async () => {
    await api.revokeOthers()
    await fetchRows()
  }, '其他设备已退出')
}
onMounted(load)
</script>
<template>
  <section class="session-panel">
    <div class="security-row">
      <div>
        <h3>登录设备</h3>
        <p class="muted">按浏览器会话列出；客户端名称来自浏览器声明。</p>
      </div>
      <el-button :disabled="busy || loading || !!error || rows.length < 2" @click="revokeOthers"
        >退出其他设备</el-button
      >
    </div>
    <AsyncState :loading="loading" :error="error" @retry="load">
      <div v-for="row in rows" :key="row.id" class="session-row">
        <div>
          <el-tag v-if="row.current" type="success">当前登录</el-tag>
          <p class="client-name">{{ row.client || '未知客户端' }}</p>
          <small>登录：{{ time(row.loginAt) }} · 到期：{{ time(row.expiresAt) }}</small>
        </div>
        <el-button v-if="!row.current" :disabled="busy" @click="revoke(row)">退出设备</el-button>
      </div>
      <el-button :disabled="busy" @click="load">刷新列表</el-button>
    </AsyncState>
  </section>
</template>
<style scoped>
.session-panel {
  margin-top: 32px;
}
.session-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 18px 0;
  border-bottom: 1px solid var(--border);
  margin-bottom: 16px;
}
.session-row > div {
  min-width: 0;
}
.client-name {
  overflow-wrap: anywhere;
  line-height: 1.6;
}
small {
  color: var(--muted);
  line-height: 1.8;
}
@media (max-width: 550px) {
  .session-row {
    align-items: flex-start;
    flex-direction: column;
  }
}
</style>
