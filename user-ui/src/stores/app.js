import { defineStore } from 'pinia'
import { ref } from 'vue'
import * as api from '../api/message.js'
import { getToken } from '../utils/auth.js'
export const useApp = defineStore('app', () => {
  const unread = ref(0)
  async function refreshUnread() {
    const token = getToken(),
      value = await api.unread()
    if (getToken() === token)
      unread.value = Number(typeof value === 'number' ? value : (value?.unread ?? 0))
  }
  function reset() {
    unread.value = 0
  }
  return { unread, refreshUnread, reset }
})
