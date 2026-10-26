<script setup>
import AddressCard from './AddressCard.vue'
defineProps({ addresses: Array, modelValue: [String, Number], disabled: Boolean })
defineEmits(['update:modelValue'])
</script>
<template>
  <div class="address-grid" role="radiogroup" aria-label="收货地址">
    <label v-for="address in addresses" :key="address.id" class="address-choice"
      ><input
        type="radio"
        name="address"
        :value="address.id"
        :checked="modelValue === address.id"
        :disabled="disabled"
        @change="$emit('update:modelValue', address.id)" /><AddressCard
        :address="address"
        :selected="modelValue === address.id"
    /></label>
  </div>
</template>
