<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import * as api from '../../api/item.js'
import { useCart } from '../../stores/cart.js'
import { useMember } from '../../stores/member.js'
import { usePet } from '../../stores/pet.js'
import { useTask, useAction, confirm } from '../../composables/useTask.js'
import { species, ages } from '../../utils/format.js'
import AsyncState from '../../components/AsyncState.vue'
import ImageWithFallback from '../../components/ImageWithFallback.vue'
import MoneyText from '../../components/MoneyText.vue'
import SkuSelector from '../../components/SkuSelector.vue'
import QuantityStepper from '../../components/QuantityStepper.vue'
import PetSelector from '../../components/PetSelector.vue'
import AdaptTag from '../../components/AdaptTag.vue'
import SafeDescription from '../../components/SafeDescription.vue'
const route = useRoute(),
  router = useRouter(),
  cart = useCart(),
  member = useMember(),
  pet = usePet()
const item = ref(null),
  skuId = ref(null),
  quantity = ref(1),
  activeImage = ref(''),
  { loading, error, run } = useTask(),
  { busy, act } = useAction()
const sku = computed(() => item.value?.skus?.find((row) => row.id === skuId.value))
const gallery = computed(() => [
  ...new Set(
    [
      item.value?.mainImage,
      ...[...(item.value?.images || [])].sort((a, b) => a.sort - b.sort).map((row) => row.url),
    ].filter(Boolean),
  ),
])
const load = () =>
  run(async () => {
    item.value = await api.detail(route.params.id)
    skuId.value = item.value.skus?.find((row) => row.stock > 0 && row.status !== 0)?.id
    activeImage.value = item.value.mainImage
    if (member.loggedIn) await pet.fetch()
  })
async function add(buy = false) {
  if (!sku.value) return
  const adapt = item.value.adapts?.find((row) => row.petId === pet.selected)
  if (
    adapt?.level === 'UNSUITABLE' &&
    !(await confirm(`该商品不适合${adapt.petName}，仍要购买吗？`))
  )
    return
  if (buy && !member.loggedIn) {
    await router.push({ path: '/login', query: { redirect: route.fullPath } })
    return
  }
  await act(async () => {
    await cart.add(item.value, sku.value, quantity.value, pet.selected)
    if (buy) {
      const row = cart.rows.find((row) => row.skuId === sku.value.id)
      if (row) await cart.change(row.id, { checked: 1 })
      await router.push({ path: '/checkout', query: { from: 'buynow', skuId: sku.value.id } })
    } else ElMessage.success(member.loggedIn ? '已加入购物车' : '已加入游客购物车，登录后自动合并')
  })
}
onMounted(load)
</script>
<template>
  <div class="breadcrumb">
    <router-link to="/">首页</router-link> / <router-link to="/items">全部好物</router-link> /
    商品详情
  </div>
  <AsyncState :loading="loading" :error="error" @retry="load"
    ><template v-if="item"
      ><section class="detail-grid">
        <div>
          <div class="detail-image"><ImageWithFallback :src="activeImage" :alt="item.title" /></div>
          <div v-if="gallery.length > 1" class="thumbnails">
            <button
              v-for="(image, index) in gallery"
              :key="index"
              :class="{ selected: activeImage === image }"
              @click="activeImage = image"
            >
              <ImageWithFallback :src="image" :alt="`商品图片 ${index + 1}`" />
            </button>
          </div>
        </div>
        <div class="detail-info">
          <span class="eyebrow"
            >{{ item.brand || 'PET & GOOD' }} · {{ species[item.petSpecies] }}</span
          >
          <h1>{{ item.title }}</h1>
          <p class="muted">{{ item.subtitle }}</p>
          <div class="detail-price">
            <MoneyText :value="sku?.price ?? item.priceMin" /><small
              >已售 {{ item.sales || 0 }} · {{ ages[item.ageStage] }}</small
            >
          </div>
          <div class="field-block">
            <label>选择规格</label
            ><SkuSelector
              v-model="skuId"
              :skus="item.skus"
              @update:model-value="quantity = 1"
            /><small v-if="sku"
              >库存 {{ sku.stock }} 件<span v-if="sku.stock <= 3" class="notice-text">
                · 库存不多了</span
              ></small
            >
          </div>
          <div class="field-block">
            <label>购买数量</label
            ><QuantityStepper v-model="quantity" :max="sku?.stock || 1" :disabled="!sku || busy" />
          </div>
          <div class="field-block">
            <label>为谁挑选 <small>选填</small></label
            ><PetSelector
              v-if="member.loggedIn && pet.rows.length"
              v-model="pet.selected"
              :pets="pet.rows"
            /><router-link
              v-else
              :to="
                member.loggedIn
                  ? '/member/pets'
                  : { path: '/login', query: { redirect: route.fullPath } }
              "
              class="text-link"
              >{{
                member.loggedIn ? '建立档案，让挑选更适合 ↗' : '登录后查看专属适配建议 ↗'
              }}</router-link
            >
            <div class="adapt-list">
              <AdaptTag v-for="adapt in item.adapts || []" :key="adapt.petId" :adapt="adapt" />
            </div>
          </div>
          <div class="detail-actions">
            <el-button
              type="primary"
              size="large"
              :loading="busy"
              :disabled="!sku || !sku.stock"
              @click="add()"
              >{{ sku ? '加入购物车' : '暂时售罄' }}</el-button
            ><el-button size="large" :disabled="!sku || !sku.stock || busy" @click="add(true)"
              >立即购买</el-button
            >
          </div>
          <p class="detail-assurance">按宠适配建议仅供选购参考，健康问题请咨询兽医。</p>
        </div>
      </section>
      <section class="panel detail-description">
        <h2>好物详情</h2>
        <div class="detail-facts">
          <span>适用宠物：{{ species[item.petSpecies] }}</span
          ><span>适用阶段：{{ ages[item.ageStage] }}</span
          ><span>适用体重：{{ item.weightRange || '详见商品说明' }}</span>
        </div>
        <SafeDescription :content="item.detail" /></section></template
  ></AsyncState>
</template>
