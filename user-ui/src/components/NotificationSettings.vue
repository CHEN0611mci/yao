<script setup>
import { reactive, onMounted } from 'vue'
import * as api from '../api/member.js'
import { useTask, useAction } from '../composables/useTask.js'
import AsyncState from './AsyncState.vue'
const model = reactive({ orderNotifications: true, systemNotifications: true })
const { loading, error, run } = useTask(),
  { busy, act } = useAction()
const load = () => run(async () => Object.assign(model, await api.preferences()))
const save = () =>
  act(async () => Object.assign(model, await api.savePreferences({ ...model })), '通知偏好已保存')
onMounted(load)
</script>
<template>
  <AsyncState :loading="loading" :error="error" @retry="load">
    <p class="muted">控制后续站内消息；已收到的消息和订单记录会保留。</p>
    <div class="preference-row">
      <span>订单通知<small>支付成功、发货、订单关闭等提醒</small></span
      ><el-switch v-model="model.orderNotifications" :disabled="busy" aria-label="订单通知" />
    </div>
    <div class="preference-row">
      <span>系统通知<small>系统发送的其他站内提醒</small></span
      ><el-switch v-model="model.systemNotifications" :disabled="busy" aria-label="系统通知" />
    </div>
    <el-button type="primary" :loading="busy" @click="save">保存通知偏好</el-button>
  </AsyncState>
</template>
<style scoped>
.preference-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 20px;
  max-width: 560px;
  padding: 18px 0;
}
small {
  display: block;
  color: var(--muted);
  margin-top: 8px;
}
</style>
