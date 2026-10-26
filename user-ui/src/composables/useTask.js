import { ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
export function useTask() {
  const loading = ref(false),
    error = ref('')
  let runId = 0
  async function run(fn) {
    const id = ++runId
    loading.value = true
    error.value = ''
    try {
      return await fn()
    } catch (e) {
      if (id === runId) error.value = e.message
      return undefined
    } finally {
      if (id === runId) loading.value = false
    }
  }
  return { loading, error, run }
}
export function useAction() {
  const busy = ref(false),
    actionError = ref('')
  async function act(fn, text) {
    if (busy.value) return false
    busy.value = true
    actionError.value = ''
    try {
      await fn()
      if (text) ElMessage.success(text)
      return true
    } catch (e) {
      actionError.value = e.message
      ElMessage.error(e.message)
      return false
    } finally {
      busy.value = false
    }
  }
  return { busy, actionError, act }
}
export async function confirm(message, title = '请确认') {
  try {
    await ElMessageBox.confirm(message, title, {
      confirmButtonText: '确认',
      cancelButtonText: '再想想',
      type: 'warning',
    })
    return true
  } catch {
    return false
  }
}
