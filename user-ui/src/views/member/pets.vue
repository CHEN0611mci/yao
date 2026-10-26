<script setup>
import { onMounted, ref, reactive } from 'vue'
import * as api from '../../api/pet.js'
import { usePet } from '../../stores/pet.js'
import { useTask, useAction, confirm } from '../../composables/useTask.js'
import MemberNav from '../../components/MemberNav.vue'
import PetCard from '../../components/PetCard.vue'
import EmptyState from '../../components/EmptyState.vue'
import AsyncState from '../../components/AsyncState.vue'
import { species } from '../../utils/format.js'
const pet = usePet(),
  dialog = ref(false),
  editId = ref(null),
  form = ref(),
  model = reactive({})
const { loading, error, run } = useTask(),
  { busy, act } = useAction()
const archived = ref([]),
  showArchived = ref(false)
const load = () =>
  run(async () => {
    await pet.fetch()
    archived.value = (await api.list(true)).filter((x) => x.status !== 0)
  })
async function restore(row) {
  await act(async () => {
    await api.update(row.id, { ...row, status: 0 })
    await load()
  }, '档案已恢复')
}
async function exportPets() {
  await act(async () => {
    const rows = await api.list(true)
    const url = URL.createObjectURL(
      new Blob([JSON.stringify(rows, null, 2)], { type: 'application/json' }),
    )
    const link = document.createElement('a')
    link.href = url
    link.download = '我的宠物档案.json'
    link.click()
    URL.revokeObjectURL(url)
  })
}
const rules = {
  name: [
    { required: true, whitespace: true, message: '请输入宠物名' },
    { max: 30, message: '宠物名最多 30 字' },
  ],
  species: [{ required: true, message: '请选择物种' }],
  breed: [{ max: 50, message: '品种最多 50 字' }],
  allergyNote: [{ max: 200, message: '过敏说明最多 200 字' }],
}
function edit(row) {
  editId.value = row?.id ?? null
  Object.assign(
    model,
    {
      name: '',
      species: 'CAT',
      breed: '',
      birthday: null,
      weight: undefined,
      sterilized: 0,
      allergyNote: '',
      status: 0,
    },
    row || {},
  )
  dialog.value = true
}
async function save() {
  if (!(await form.value.validate().catch(() => false))) return
  const data = {
    name: model.name.trim(),
    species: model.species,
    breed: model.breed,
    birthday: model.birthday || null,
    weight: model.weight ?? null,
    sterilized: model.sterilized,
    allergyNote: model.allergyNote,
    status: 0,
  }
  const ok = await act(async () => {
    await (editId.value ? api.update(editId.value, data) : api.create(data))
    await pet.fetch()
  }, '宠物档案已保存')
  if (ok) dialog.value = false
}
async function archive(row) {
  if (await confirm(`归档「${row.name}」后，它将不再参与适配建议。确定归档吗？`))
    await act(async () => {
      await api.archive(row.id)
      await pet.fetch()
    }, '档案已归档')
  await load()
}
onMounted(load)
</script>
<template>
  <div class="page-heading heading-row">
    <div>
      <span class="eyebrow">MEET YOUR LITTLE ONES</span>
      <h1>它的小档案</h1>
      <p>多了解一点，让每一份选择更贴心。最多可建立 5 个档案。</p>
    </div>
    <el-button :loading="busy" @click="exportPets">导出档案</el-button>
    <el-button @click="showArchived = !showArchived">已归档 {{ archived.length }}</el-button>
    <el-button type="primary" :disabled="pet.rows.length >= 5 || busy" @click="edit()"
      >＋ 新建档案</el-button
    >
  </div>
  <div class="member-layout">
    <MemberNav /><AsyncState :loading="loading" :error="error" @retry="load"
      ><div v-if="pet.rows.length" class="stack">
        <PetCard v-for="row in pet.rows" :key="row.id" :pet="row"
          ><el-button size="small" :disabled="busy" @click="edit(row)">编辑</el-button
          ><el-button size="small" :disabled="busy" @click="archive(row)">归档</el-button></PetCard
        >
      </div>
      <EmptyState
        v-else
        title="认识一下你的毛孩子"
        description="建好档案后，就能在商品页看到专属适配建议。"
        ><el-button type="primary" @click="edit()">建立第一个档案</el-button></EmptyState
      >
      <div v-if="showArchived" class="stack panel">
        <h3>已归档档案</h3>
        <p v-if="!archived.length">暂无已归档档案</p>
        <PetCard v-for="row in archived" :key="row.id" :pet="row">
          <el-button :disabled="busy || pet.rows.length >= 5" @click="restore(row)"
            >恢复档案</el-button
          >
        </PetCard>
      </div></AsyncState
    >
  </div>
  <el-dialog
    v-model="dialog"
    :title="editId ? '编辑宠物档案' : '认识一位新伙伴'"
    width="min(560px, 94vw)"
    :close-on-click-modal="!busy"
    :show-close="!busy"
    :close-on-press-escape="!busy"
    destroy-on-close
    ><el-form ref="form" :model="model" :rules="rules" label-position="top"
      ><div class="form-grid">
        <el-form-item label="宠物名" prop="name"
          ><el-input v-model="model.name" maxlength="30" /></el-form-item
        ><el-form-item label="物种" prop="species"
          ><el-select v-model="model.species"
            ><el-option
              v-for="key in ['CAT', 'DOG', 'SMALL']"
              :key="key"
              :label="species[key]"
              :value="key" /></el-select></el-form-item
        ><el-form-item label="品种" prop="breed"
          ><el-input v-model="model.breed" maxlength="50" /></el-form-item
        ><el-form-item label="生日（选填）"
          ><el-date-picker
            v-model="model.birthday"
            type="date"
            value-format="YYYY-MM-DD"
            :disabled-date="(date) => date > new Date()" /></el-form-item
        ><el-form-item label="体重 kg（选填）"
          ><el-input-number
            v-model="model.weight"
            :min="0.1"
            :max="100"
            :precision="2" /></el-form-item
        ><el-form-item label="绝育情况"
          ><el-radio-group v-model="model.sterilized"
            ><el-radio :value="0">未绝育</el-radio
            ><el-radio :value="1">已绝育</el-radio></el-radio-group
          ></el-form-item
        >
      </div>
      <el-form-item label="过敏说明" prop="allergyNote"
        ><el-input
          v-model="model.allergyNote"
          type="textarea"
          maxlength="200"
          show-word-limit
          placeholder="例如：对谷物敏感（选填）" /></el-form-item></el-form
    ><template #footer
      ><el-button :disabled="busy" @click="dialog = false">取消</el-button
      ><el-button type="primary" :loading="busy" @click="save">保存档案</el-button></template
    ></el-dialog
  >
</template>
