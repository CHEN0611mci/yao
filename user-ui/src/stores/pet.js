import { defineStore } from 'pinia'
import { ref } from 'vue'
import * as api from '../api/pet.js'
import { getToken } from '../utils/auth.js'
export const usePet = defineStore('pet', () => {
  const rows = ref([]),
    selected = ref(null)
  async function fetch() {
    const token = getToken(),
      data = await api.list()
    if (getToken() !== token) return
    rows.value = data || []
    if (!rows.value.some((p) => p.id === selected.value)) selected.value = rows.value[0]?.id ?? null
  }
  function reset() {
    rows.value = []
    selected.value = null
  }
  return { rows, selected, fetch, reset }
})
