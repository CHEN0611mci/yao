<script setup>
import { species } from '../utils/format.js'
defineProps({ pet: Object })
</script>
<template>
  <article class="panel pet-card">
    <span class="pet-avatar">{{
      pet.species === 'CAT' ? '🐱' : pet.species === 'DOG' ? '🐶' : '🐹'
    }}</span>
    <div>
      <h3>
        {{ pet.name }}<small>{{ species[pet.species] }}</small>
      </h3>
      <p>{{ pet.breed || '品种未填写' }} · {{ pet.weight ? `${pet.weight}kg` : '体重未填写' }}</p>
      <p class="muted">
        生日 {{ pet.birthday || '未填写' }} · {{ pet.sterilized === 1 ? '已绝育' : '未绝育' }}
      </p>
      <p v-if="pet.allergyNote" class="notice-text">过敏提醒：{{ pet.allergyNote }}</p>
    </div>
    <div class="card-actions"><slot /></div>
  </article>
</template>
