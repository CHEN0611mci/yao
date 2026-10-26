<script setup>
import { ref, reactive, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useMember } from '../stores/member.js'
import { useCart } from '../stores/cart.js'
import { safeRedirect } from '../utils/auth.js'
const props = defineProps({ register: Boolean })
const route = useRoute(),
  router = useRouter(),
  member = useMember(),
  cart = useCart(),
  form = ref(),
  busy = ref(false),
  error = ref(''),
  wait = ref(0)
const model = reactive({
  username: '',
  password: '',
  nickname: '',
  phone: '',
  confirmation: '',
  agree: false,
})
const rules = {
  username: [
    { required: true, message: '请输入用户名', trigger: 'blur' },
    {
      pattern: /^[A-Za-z0-9_]{4,20}$/,
      message: '用户名为 4–20 位字母、数字或下划线',
      trigger: 'blur',
    },
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, max: 30, message: '密码长度为 6–30 位', trigger: 'blur' },
  ],
  nickname: [
    { required: true, whitespace: true, message: '请输入昵称', trigger: 'blur' },
    { max: 30, message: '昵称最多 30 字', trigger: 'blur' },
  ],
  phone: [{ pattern: /^$|^1[3-9]\d{9}$/, message: '请输入有效手机号', trigger: 'blur' }],
  confirmation: [
    {
      validator: (_, value, callback) =>
        callback(value === model.password ? undefined : new Error('两次输入的密码不一致')),
      trigger: 'blur',
    },
  ],
}
const timer = setInterval(() => {
  if (wait.value > 0) wait.value--
}, 1000)
onUnmounted(() => clearInterval(timer))
async function submit() {
  if (busy.value || wait.value) return
  if (!(await form.value.validate().catch(() => false))) return
  if (props.register && !model.agree) {
    error.value = '请先阅读并同意用户协议与隐私政策'
    return
  }
  busy.value = true
  error.value = ''
  try {
    const data = props.register
      ? {
          username: model.username,
          password: model.password,
          nickname: model.nickname.trim(),
          phone: model.phone || '',
        }
      : { username: model.username, password: model.password }
    await member.authenticate(data, props.register)
    // Merge failure must not undo an established login. Failed guest rows remain available.
    try {
      await cart.merge()
    } catch (e) {
      cart.mergeErrors = [{ title: '游客购物车', error: e.message }]
    }
    model.password = ''
    model.confirmation = ''
    await router.replace(safeRedirect(route.query.redirect))
  } catch (e) {
    error.value = e.message
    if (e.status === 429 || e.errorCode === 'PET-4290') wait.value = e.retryAfter
  } finally {
    busy.value = false
  }
}
</script>
<template>
  <section class="auth-shell">
    <div class="auth-visual">
      <span class="eyebrow">LIFE IS BETTER WITH PAWS</span>
      <h1>有它在，<br />日子都可爱起来。</h1>
      <p>每一次用心挑选，<br />都是给陪伴的一点小小回应。</p>
      <img src="/images/companions.svg" alt="可爱的猫狗伙伴" />
    </div>
    <div class="auth-form">
      <span class="eyebrow">{{ register ? 'HELLO, NEW FRIEND' : 'WELCOME BACK' }}</span>
      <h2>{{ register ? '一起，照顾它的日常' : '欢迎回来，老朋友' }}</h2>
      <p class="muted">
        {{
          register ? '创建账号，开启你与毛孩子的好物之旅。' : '登录萌宠优选，继续你们的美好日常。'
        }}
      </p>
      <el-form
        ref="form"
        :model="model"
        :rules="rules"
        label-position="top"
        @submit.prevent="submit"
        ><el-form-item label="用户名" prop="username"
          ><el-input
            v-model="model.username"
            maxlength="20"
            autocomplete="username"
            placeholder="请输入用户名" /></el-form-item
        ><el-form-item v-if="register" label="昵称" prop="nickname"
          ><el-input
            v-model="model.nickname"
            maxlength="30"
            placeholder="大家怎么称呼你" /></el-form-item
        ><el-form-item label="密码" prop="password"
          ><el-input
            v-model="model.password"
            type="password"
            show-password
            maxlength="30"
            :autocomplete="register ? 'new-password' : 'current-password'"
            placeholder="请输入密码" /></el-form-item
        ><el-form-item v-if="register" label="确认密码" prop="confirmation"
          ><el-input
            v-model="model.confirmation"
            type="password"
            show-password
            autocomplete="new-password"
            placeholder="再输入一次密码" /></el-form-item
        ><el-form-item v-if="register" label="手机号（选填）" prop="phone"
          ><el-input
            v-model="model.phone"
            maxlength="11"
            autocomplete="tel"
            placeholder="请输入手机号"
        /></el-form-item>
        <div v-if="register" class="agreement-check">
          <el-checkbox v-model="model.agree">我已阅读并同意</el-checkbox
          ><router-link to="/agreement?type=user">用户协议</router-link>及<router-link
            to="/agreement?type=privacy"
            >隐私政策</router-link
          >
        </div>
        <el-alert v-if="error" :title="error" type="error" :closable="false" show-icon /><el-button
          class="auth-submit"
          type="primary"
          native-type="submit"
          :loading="busy"
          :disabled="wait > 0"
          >{{ wait ? `请 ${wait} 秒后重试` : register ? '注册并登录' : '登录' }}</el-button
        ></el-form
      >
      <p class="auth-switch">
        {{ register ? '已经有账号？' : '还没有账号？'
        }}<router-link :to="{ path: register ? '/login' : '/register', query: route.query }"
          >{{ register ? '立即登录' : '立即注册' }} ↗</router-link
        >
      </p>
    </div>
  </section>
</template>
