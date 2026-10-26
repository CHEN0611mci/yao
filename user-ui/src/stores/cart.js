import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import * as api from '../api/cart.js'
import { getToken } from '../utils/auth.js'
import { readStorage, writeStorage } from '../utils/storage.js'
export const useCart = defineStore('cart', () => {
  const rows = ref([]),
    guestRows = ref(readStorage('guest_cart', [])),
    mergeErrors = ref([])
  const count = computed(() =>
    (getToken() ? rows.value : guestRows.value).reduce((n, row) => n + row.quantity, 0),
  )
  const checked = computed(() => rows.value.filter((row) => row.checked === 1 && row.valid))
  async function fetch() {
    const token = getToken(),
      data = await api.list()
    if (getToken() === token) rows.value = data || []
  }
  async function add(item, sku, quantity, petId) {
    if (getToken()) {
      await api.add({ skuId: sku.id, quantity, petId: petId || undefined })
      await fetch()
      return
    }
    const old = guestRows.value.find((row) => row.skuId === sku.id)
    if (old) old.quantity = Math.min(99, sku.stock, old.quantity + quantity)
    else {
      if (guestRows.value.length >= 200) throw new Error('购物车最多保存 200 种商品')
      guestRows.value.push({ skuId: sku.id, quantity, title: item.title, spec: sku.specName })
    }
    writeStorage('guest_cart', guestRows.value)
  }
  async function merge() {
    mergeErrors.value = []
    // Persist after every success, so a later failed line cannot duplicate earlier lines.
    for (const row of [...guestRows.value]) {
      try {
        await api.add({ skuId: row.skuId, quantity: row.quantity })
        guestRows.value = guestRows.value.filter((item) => item.skuId !== row.skuId)
        writeStorage('guest_cart', guestRows.value)
      } catch (e) {
        mergeErrors.value.push({ ...row, error: e.message })
      }
    }
    await fetch()
  }
  async function change(id, data) {
    await api.update(id, data)
    await fetch()
  }
  async function remove(id) {
    await api.remove(id)
    await fetch()
  }
  function reset() {
    rows.value = []
    mergeErrors.value = []
  }
  return { rows, guestRows, mergeErrors, count, checked, fetch, add, merge, change, remove, reset }
})
