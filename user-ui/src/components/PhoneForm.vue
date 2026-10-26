<script setup>
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import * as api from '../api/member.js'
import { useMember } from '../stores/member.js'
import { useCart } from '../stores/cart.js'
import { usePet } from '../stores/pet.js'
import { useApp } from '../stores/app.js'
import { useAction, confirm } from '../composables/useTask.js'
const router = useRouter(),
  member = useMember(),
  cart = useCart(),
  pet = usePet(),
  app = useApp()
const form = ref(),
  model = reactive({ phone: '', password: '' }),
  { busy, act } = useAction()
const rules = {
  phone: [
    { required: true, message: '请输入联系手机号' },
    { pattern: /^1[3-9]\d{9}$/, message: '手机号格式不正确' },
  ],
  password: [
    { required: true, message: '请输入当前登录密码' },
    { min: 6, max: 30, message: '密码长度为 6–30 位' },
  ],
}
async function save() {
  if (!(await form.value.validate().catch(() => false))) return
  if (!(await confirm('修改联系手机号后，当前及其他设备都会退出登录。确认修改吗？'))) return
  await act(async () => {
    await api.changePhone({ ...model })
    model.password = ''
    member.reset()
    cart.reset()
    pet.reset()
    app.reset()
    ElMessage.success('联系手机号已修改，请重新登录')
    await router.replace('/login')
  })
}
</script>
<template>
  <div class="security-row">
    <div>
      <h3>修改联系手机号</h3>
      <p class="muted">
        当前：{{
          member.profile?.phone || '未填写'
        }}。仅作为联系信息，尚未接入短信归属验证，不用于找回密码。
      </p>
    </div>
  </div>
  <el-form
    ref="form"
    :model="model"
    :rules="rules"
    label-position="top"
    class="profile-form"
    @submit.prevent="save"
  >
    <el-form-item label="新联系手机号" prop="phone"
      ><el-input v-model.trim="model.phone" maxlength="11" autocomplete="tel"
    /></el-form-item>
    <el-form-item label="当前登录密码" prop="password"
      ><el-input
        v-model="model.password"
        type="password"
        show-password
        autocomplete="current-password"
        maxlength="30"
    /></el-form-item>
    <el-button type="primary" native-type="submit" :loading="busy">保存手机号并重新登录</el-button>
  </el-form>
</template>
