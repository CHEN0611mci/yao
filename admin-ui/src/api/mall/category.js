import request from '@/utils/mallRequest'

// A8 类目树（两级，含停用）
export function listCategories() {
  return request({ url: '/api/admin/categories', method: 'get' })
}

// 匿名公开类目树（仅启用）：商家角色无 market:category:list，商品页类目下拉必须用它
export function listHomeCategories() {
  return request({ url: '/api/home/categories', method: 'get' })
}

// A9 类目详情
export function getCategory(id) {
  return request({ url: `/api/admin/categories/${id}`, method: 'get' })
}

// A10 新增类目
export function createCategory(data) {
  return request({ url: '/api/admin/categories', method: 'post', data })
}

// A11 编辑类目
export function updateCategory(id, data) {
  return request({ url: `/api/admin/categories/${id}`, method: 'put', data })
}

// A12 删除类目（有子类/商品引用 → PET-1003）
export function deleteCategory(id) {
  return request({ url: `/api/admin/categories/${id}`, method: 'delete' })
}
