<template>
  <el-tree-select
    v-model="innerValue"
    :data="treeData"
    :props="treeProps"
    :placeholder="placeholder"
    :disabled="disabled"
    :clearable="clearable"
    check-strictly
    :render-after-expand="false"
    :default-expand-all="true"
    style="width: 100%"
  />
</template>

<script setup>
/**
 * 类目树选择（两级）
 *
 * 页面负责加载类目树（admin：listCategories；商家：listHomeCategories）并通过 categories 传入。
 * onlyLeaf=true（默认）时只能选末级类目，父级节点置灰。
 */
const props = defineProps({
  modelValue: {
    type: [Number, String],
    default: null
  },
  /* 类目树（PetCategory[]，含 children） */
  categories: {
    type: Array,
    default: () => []
  },
  /* 只能选末级 */
  onlyLeaf: {
    type: Boolean,
    default: true
  },
  placeholder: {
    type: String,
    default: '请选择类目'
  },
  disabled: {
    type: Boolean,
    default: false
  },
  clearable: {
    type: Boolean,
    default: true
  }
})

const emit = defineEmits(['update:modelValue'])

const treeProps = { value: 'id', label: 'name', children: 'children', disabled: 'disabled' }

const innerValue = computed({
  get: () => (props.modelValue === null || props.modelValue === undefined ? undefined : props.modelValue),
  set: val => emit('update:modelValue', val === undefined || val === '' ? null : val)
})

const treeData = computed(() => buildTree(props.categories))

function buildTree(nodes) {
  if (!Array.isArray(nodes)) return []
  return nodes.map(node => {
    const item = { ...node }
    if (node.children && node.children.length) {
      item.children = buildTree(node.children)
      if (props.onlyLeaf) item.disabled = true
    } else {
      delete item.children
    }
    return item
  })
}
</script>
