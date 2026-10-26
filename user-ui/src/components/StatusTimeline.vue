<script setup>
import { computed } from 'vue'
const props = defineProps({ order: Object })
const events = computed(() =>
  [
    ['订单创建', props.order.createTime],
    ['支付完成', props.order.payTime],
    ['商家发货', props.order.shipTime],
    ['确认收货', props.order.receiveTime],
    ['订单关闭', props.order.closeTime],
  ].filter((row) => row[1]),
)
</script>
<template>
  <el-timeline
    ><el-timeline-item
      v-for="event in events"
      :key="event[0]"
      :timestamp="event[1]"
      color="#2bb3a3"
      >{{ event[0] }}</el-timeline-item
    ></el-timeline
  >
</template>
