<script setup>
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import * as api from '../api/member.js'
import { useMember } from '../stores/member.js'
import { useCart } from '../stores/cart.js'
import { usePet } from '../stores/pet.js'
import { useApp } from '../stores/app.js'
import { useAction } from '../composables/useTask.js'
const router = useRouter(),
  member = useMember(),
  cart = useCart(),
  pet = usePet(),
  app = useApp()
const model = reactive({ oldPassword: '', newPassword: '', confirmation: '' }),
  form = ref()
const { busy, act, actionError } = useAction()
const rules = {
  oldPassword: [{ required: true, message: '请输入原密码' }],
  newPassword: [
    { required: true, message: '请输入新密码' },
    { min: 6, max: 30, message: '密码长度为 6–30 位' },
  ],
  confirmation: [
    {
      validator: (_, value, cb) =>
        cb(value && value === model.newPassword ? undefined : new Error('请再次输入相同的新密码')),
    },
  ],
}
async function save() {
  if (!(await form.value.validate().catch(() => false))) return
  await act(async () => {
    await api.changePassword({ oldPassword: model.oldPassword, newPassword: model.newPassword })
    member.reset()
    cart.reset()
    pet.reset()
    app.reset()
    model.oldPassword = model.newPassword = model.confirmation = ''
    ElMessage.success('密码已修改，请重新登录；其他设备的登录也已失效')
    await router.replace('/login')
  })
}
</script>
<template>
  <el-form
    ref="form"
    :model="model"
    :rules="rules"
    label-position="top"
    class="profile-form"
    @submit.prevent="save"
  >
    <el-form-item label="原密码" prop="oldPassword"
      ><el-input
        v-model="model.oldPassword"
        type="password"
        autocomplete="current-password"
        show-password
    /></el-form-item>
    <el-form-item label="新密码" prop="newPassword"
      ><el-input
        v-model="model.newPassword"
        type="password"
        autocomplete="new-password"
        show-password
        maxlength="30"
    /></el-form-item>
    <el-form-item label="确认新密码" prop="confirmation"
      ><el-input
        v-model="model.confirmation"
        type="password"
        autocomplete="new-password"
        show-password
        maxlength="30"
    /></el-form-item>
    <el-alert v-if="actionError" type="error" :title="actionError" :closable="false" />
    <el-button type="primary" native-type="submit" :loading="busy">修改密码并重新登录</el-button>
  </el-form>
</template>
