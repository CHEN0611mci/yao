<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useMember } from '../stores/member.js'
import * as api from '../api/home.js'
import { useAction } from '../composables/useTask.js'
const dialog = ref(false),
  content = ref(''),
  support = ref('本商城为教学沙箱，商品与订单问题可提交意见反馈。')
const router = useRouter(),
  member = useMember(),
  { busy, act, actionError } = useAction()
onMounted(() =>
  api
    .settings()
    .then((data) => {
      support.value = data.support
    })
    .catch(() => {}),
)
async function submit() {
  if (!member.loggedIn) return router.push('/login?redirect=/agreement%3Ftype%3Dabout')
  if (content.value.trim().length < 5) return
  await act(async () => {
    await api.feedback(content.value.trim())
    content.value = ''
  }, '反馈已提交，项目管理员可在后台操作日志查看')
}
</script>
<template>
  <button class="support-float" @click="dialog = true" aria-label="客服与意见反馈">
    客服与反馈
  </button>
  <el-dialog
    v-model="dialog"
    title="客服与意见反馈"
    width="min(520px, 94vw)"
    :close-on-click-modal="!busy"
    :show-close="!busy"
    :close-on-press-escape="!busy"
  >
    <p>{{ support }}</p>
    <p class="muted">请描述问题与订单号，勿填写密码或支付信息。</p>
    <el-input
      v-model="content"
      type="textarea"
      :rows="5"
      maxlength="1000"
      show-word-limit
      placeholder="至少输入 5 个字"
      aria-label="反馈内容"
    />
    <el-alert v-if="actionError" :title="actionError" type="error" :closable="false" />
    <template #footer
      ><el-button @click="dialog = false">关闭</el-button
      ><el-button
        type="primary"
        :loading="busy"
        :disabled="member.loggedIn && content.trim().length < 5"
        @click="submit"
        >{{ member.loggedIn ? '提交反馈' : '登录后反馈' }}</el-button
      ></template
    >
  </el-dialog>
</template>
