import { createRouter, createWebHistory } from 'vue-router'
import { ElMessage } from 'element-plus'
import routes from './routes.js'
import { getToken, safeRedirect } from '../utils/auth.js'
import { useMember } from '../stores/member.js'
import { useCart } from '../stores/cart.js'
import { usePet } from '../stores/pet.js'
import { useApp } from '../stores/app.js'
const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior(to, from, saved) {
    return saved || (to.path === from.path ? undefined : { top: 0 })
  },
})
// An open tab can reference removed chunk hashes after a local rebuild.
// Retry the requested route once with a fresh document, retaining stored login/cart data.
router.onError((error, to) => {
  if (
    !/dynamically imported module|Loading chunk|Importing a module script failed/i.test(
      error.message,
    )
  )
    return
  const key = 'mall_chunk_reload'
  const last = Number(sessionStorage.getItem(key) || 0)
  if (Date.now() - last < 60000) {
    ElMessage.error('页面资源更新失败，请稍后刷新重试')
    return
  }
  sessionStorage.setItem(key, String(Date.now()))
  window.location.assign(safeRedirect(to.fullPath))
})
router.beforeEach(async (to) => {
  document.title = `${to.meta.title || '商城'} · 萌宠优选`
  const member = useMember()
  if (getToken() && !member.profile) {
    try {
      await member.restore()
    } catch {
      if (to.meta.requiresAuth && getToken()) return true
    }
  }
  if (to.meta.requiresAuth && !getToken())
    return { path: '/login', query: { redirect: to.fullPath } }
  if (to.meta.anonymousOnly && getToken() && member.profile) return safeRedirect(to.query.redirect)
})
let expiring = false
window.addEventListener('member-expired', async (event) => {
  if (expiring) return
  expiring = true
  const target = router.currentRoute.value.fullPath
  useMember().reset()
  useCart().reset()
  usePet().reset()
  useApp().reset()
  ElMessage.warning(event.detail || '登录已失效，请重新登录')
  if (!router.currentRoute.value.meta.anonymousOnly)
    await router.replace({ path: '/login', query: { redirect: safeRedirect(target) } })
  setTimeout(() => {
    expiring = false
  }, 1000)
})
export default router
