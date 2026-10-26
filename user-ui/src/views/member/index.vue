<script setup>
import { reactive, ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useMember } from '../../stores/member.js'
import { usePet } from '../../stores/pet.js'
import { useCart } from '../../stores/cart.js'
import { useApp } from '../../stores/app.js'
import * as api from '../../api/member.js'
import * as upload from '../../api/upload.js'
import { useTask, useAction, confirm } from '../../composables/useTask.js'
import MemberNav from '../../components/MemberNav.vue'
import AsyncState from '../../components/AsyncState.vue'
import ImageWithFallback from '../../components/ImageWithFallback.vue'
import PasswordForm from '../../components/PasswordForm.vue'
const member = useMember(),
  route = useRoute(),
  router = useRouter(),
  form = ref(),
  model = reactive({ nickname: '', avatar: '' })
const cart = useCart(),
  pet = usePet(),
  app = useApp(),
  { loading, error, run } = useTask(),
  { busy, act } = useAction()
const load = () =>
  run(async () => {
    member.profile = await api.me()
    model.nickname = member.profile.nickname
    model.avatar = member.profile.avatar || ''
  })
async function save() {
  if (!(await form.value.validate().catch(() => false))) return
  await act(async () => {
    member.profile = await api.update({ nickname: model.nickname.trim(), avatar: model.avatar })
  }, '资料已保存')
}
async function fileChanged(event) {
  const file = event.target.files?.[0]
  if (!file) return
  await act(async () => {
    const result = await upload.image(file)
    model.avatar = result.url
  }, '头像已上传，请保存资料')
  event.target.value = ''
}
async function logout() {
  if (!(await confirm('确定退出当前账号吗？'))) return
  await act(async () => {
    try {
      await member.logout()
    } finally {
      cart.reset()
      pet.reset()
      app.reset()
      router.replace('/')
    }
  })
}
onMounted(load)
</script>
<template>
  <div class="page-heading">
    <span class="eyebrow">A PLACE FOR YOU & THEM</span>
    <h1>你好，{{ member.profile?.nickname || '新朋友' }}</h1>
    <p>把喜欢的日常，和它一起好好收藏。</p>
  </div>
  <div class="member-layout">
    <MemberNav />
    <div>
      <AsyncState :loading="loading" :error="error" @retry="load"
        ><section class="panel">
          <el-tabs
            :model-value="String(route.query.tab || 'profile')"
            @update:model-value="router.replace({ query: { tab: $event } })"
            ><el-tab-pane label="个人资料" name="profile"
              ><el-form ref="form" :model="model" label-position="top" class="profile-form"
                ><div class="profile-avatar">
                  <ImageWithFallback :src="model.avatar" kind="avatar" alt="会员头像" /><label
                    class="upload-label"
                    >更换头像<input
                      type="file"
                      accept="image/jpeg,image/png,image/webp"
                      :disabled="busy"
                      @change="fileChanged" /></label
                  ><small>JPG / PNG / WebP，最大 10MB</small>
                </div>
                <el-form-item label="用户名"
                  ><el-input :model-value="member.profile?.username" disabled /></el-form-item
                ><el-form-item
                  label="昵称"
                  prop="nickname"
                  :rules="[
                    { required: true, whitespace: true, message: '请输入昵称' },
                    { max: 30, message: '最多 30 字' },
                  ]"
                  ><el-input v-model="model.nickname" maxlength="30" /></el-form-item
                ><el-form-item label="手机号"
                  ><el-input
                    :model-value="member.profile?.phone || '未绑定'"
                    disabled /></el-form-item
                ><el-button type="primary" :loading="busy" @click="save"
                  >保存资料</el-button
                ></el-form
              ></el-tab-pane
            ><el-tab-pane label="账号安全" name="security"
              ><div class="security-row">
                <div>
                  <h3>修改密码</h3>
                  <p class="muted">修改后需要重新登录，其他设备的登录也会失效。</p>
                </div>
              </div>
              <PasswordForm />
              <div class="security-row">
                <div>
                  <h3>退出登录</h3>
                  <p class="muted">退出后可以使用其他会员账号登录。</p>
                </div>
                <el-button :loading="busy" @click="logout">退出登录</el-button>
              </div></el-tab-pane
            ></el-tabs
          >
        </section></AsyncState
      >
    </div>
  </div>
</template>
