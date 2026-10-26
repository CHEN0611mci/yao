<script setup>
import { ref, reactive, onMounted } from 'vue'
import * as api from '../../api/address.js'
import { useTask, useAction, confirm } from '../../composables/useTask.js'
import MemberNav from '../../components/MemberNav.vue'
import AddressCard from '../../components/AddressCard.vue'
import AsyncState from '../../components/AsyncState.vue'
import EmptyState from '../../components/EmptyState.vue'
const rows = ref([]),
  dialog = ref(false),
  editId = ref(null),
  form = ref(),
  model = reactive({})
const { loading, error, run } = useTask(),
  { busy, act } = useAction()
const load = () =>
  run(async () => {
    rows.value = (await api.list()) || []
  })
const fields = {
  receiver: ['收货人', 30],
  phone: ['手机号', 11],
  province: ['省份', 50],
  city: ['城市', 50],
  district: ['区县', 50],
  detail: ['详细地址', 200],
}
const rules = Object.fromEntries(
  Object.entries(fields).map(([key, [name, max]]) => [
    key,
    [
      { required: true, whitespace: true, message: `请输入${name}`, trigger: 'blur' },
      { max, message: `${name}最多 ${max} 字`, trigger: 'blur' },
      ...(key === 'phone'
        ? [{ pattern: /^1[3-9]\d{9}$/, message: '手机号格式不正确', trigger: 'blur' }]
        : []),
    ],
  ]),
)
function edit(row) {
  editId.value = row?.id ?? null
  Object.assign(
    model,
    {
      receiver: '',
      phone: '',
      province: '',
      city: '',
      district: '',
      detail: '',
      isDefault: rows.value.length ? 0 : 1,
    },
    row || {},
  )
  dialog.value = true
}
async function save() {
  if (!(await form.value.validate().catch(() => false))) return
  const data = Object.fromEntries(Object.keys(fields).map((key) => [key, model[key].trim()]))
  data.isDefault = model.isDefault
  const ok = await act(async () => {
    await (editId.value ? api.update(editId.value, data) : api.create(data))
    rows.value = await api.list()
  }, '收货地址已保存')
  if (ok) dialog.value = false
}
async function remove(row) {
  if (await confirm(`确定删除${row.receiver}的收货地址吗？`))
    await act(async () => {
      await api.remove(row.id)
      rows.value = await api.list()
    }, '地址已删除')
}
async function setDefault(row) {
  await act(async () => {
    await api.setDefault(row.id)
    rows.value = await api.list()
  }, '默认地址已更新')
}
onMounted(load)
</script>
<template>
  <div class="page-heading heading-row">
    <div>
      <span class="eyebrow">DELIVER A LITTLE HAPPINESS</span>
      <h1>收货地址</h1>
      <p>把它喜欢的好物，送到你身边。最多保存 20 个地址。</p>
    </div>
    <el-button type="primary" :disabled="rows.length >= 20 || busy" @click="edit()"
      >＋ 新增地址</el-button
    >
  </div>
  <div class="member-layout">
    <MemberNav /><AsyncState :loading="loading" :error="error" @retry="load"
      ><div v-if="rows.length" class="address-grid">
        <AddressCard v-for="row in rows" :key="row.id" :address="row"
          ><el-button size="small" :disabled="busy" @click="edit(row)">编辑</el-button
          ><el-button
            v-if="row.isDefault !== 1"
            size="small"
            :disabled="busy"
            @click="setDefault(row)"
            >设为默认</el-button
          ><el-button size="small" :disabled="busy" @click="remove(row)"
            >删除</el-button
          ></AddressCard
        >
      </div>
      <EmptyState v-else title="还没有收货地址" description="添加一个地址，准备接收它的快乐。"
        ><el-button type="primary" @click="edit()">添加收货地址</el-button></EmptyState
      ></AsyncState
    >
  </div>
  <el-dialog
    v-model="dialog"
    :title="editId ? '编辑地址' : '新增收货地址'"
    width="min(560px, 94vw)"
    :close-on-click-modal="!busy"
    :show-close="!busy"
    :close-on-press-escape="!busy"
    destroy-on-close
    ><el-form ref="form" :model="model" :rules="rules" label-position="top"
      ><div class="form-grid">
        <el-form-item
          v-for="(field, key) in fields"
          :key="key"
          :label="field[0]"
          :prop="key"
          :class="{ 'full-width': key === 'detail' }"
          ><el-input
            v-model="model[key]"
            :maxlength="field[1]"
            :type="key === 'detail' ? 'textarea' : 'text'"
        /></el-form-item>
      </div>
      <el-form-item
        ><el-checkbox
          v-model="model.isDefault"
          :true-value="1"
          :false-value="0"
          :disabled="!!editId && rows.some((row) => row.id === editId && row.isDefault === 1)"
          >设为默认地址</el-checkbox
        ></el-form-item
      ></el-form
    ><template #footer
      ><el-button :disabled="busy" @click="dialog = false">取消</el-button
      ><el-button type="primary" :loading="busy" @click="save">保存地址</el-button></template
    ></el-dialog
  >
</template>
