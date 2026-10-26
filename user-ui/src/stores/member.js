import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import * as api from '../api/member.js'
import { getToken, setToken, clearToken } from '../utils/auth.js'
export const useMember = defineStore('member', () => {
  const token = ref(getToken()),
    profile = ref(null)
  const loggedIn = computed(() => !!token.value)
  let restoring
  function reset() {
    clearToken()
    token.value = ''
    profile.value = null
  }
  async function restore() {
    if (!getToken()) {
      reset()
      return
    }
    if (profile.value) return profile.value
    const expectedToken = getToken()
    if (!restoring)
      restoring = api
        .me()
        .then((value) => {
          if (getToken() !== expectedToken) return
          profile.value = value
          token.value = getToken()
          return value
        })
        .finally(() => {
          restoring = null
        })
    return restoring
  }
  async function authenticate(data, isRegister = false) {
    const result = await (isRegister ? api.register : api.login)(data)
    setToken(result.token)
    token.value = result.token
    profile.value = result.member
  }
  async function logout() {
    try {
      await api.logout()
    } finally {
      reset()
    }
  }
  return { token, profile, loggedIn, reset, restore, authenticate, logout }
})
