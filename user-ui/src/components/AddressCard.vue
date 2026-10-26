<script setup>
defineProps({ address: Object, selected: Boolean })
</script>
<template>
  <article class="address-card" :class="{ selected }">
    <div class="row">
      <strong>{{ address.receiver }}</strong
      ><span>{{ address.phone }}</span
      ><el-tag v-if="address.isDefault === 1" size="small" type="success">默认</el-tag>
    </div>
    <p>{{ address.province }} {{ address.city }} {{ address.district }}</p>
    <p>{{ address.detail }}</p>
    <div class="card-actions"><slot /></div>
  </article>
</template>
