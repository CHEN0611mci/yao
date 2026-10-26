<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
const route = useRoute()
const type = computed(() =>
  ['user', 'privacy', 'about'].includes(route.query.type) ? route.query.type : 'user',
)
const content = {
  user: {
    title: '用户服务协议',
    intro: '欢迎来到萌宠优选。本项目为课程实践商城，使用前请了解以下约定。',
    sections: [
      [
        '账号使用',
        '请使用本人创建的会员账号，妥善保存密码。请勿使用他人的身份信息，不得进行恶意请求或干扰平台服务。',
      ],
      [
        '商品与订单',
        '商品库存、售价、运费以及最终应付金额以服务端结算与订单信息为准。宠物适配信息仅作为选购参考，不替代兽医建议。',
      ],
      [
        '沙箱支付',
        '本站支付功能用于模拟成功、失败及超时场景，不连接真实收款渠道，不会发生真实扣款或实际履约。',
      ],
      [
        '服务范围',
        '本期提供商品浏览、购物车、宠物档案、地址、订单与消息功能。售后、订阅、优惠券等功能尚未开放。',
      ],
    ],
  },
  privacy: {
    title: '隐私政策',
    intro: '我们尊重你与毛孩子的信息。这份说明介绍课程演示系统如何使用数据。',
    sections: [
      [
        '收集与使用',
        '注册信息用于账号认证；昵称与头像用于个人展示；地址与联系电话用于订单收货信息；宠物档案用于商品适配提示。请勿在课程演示环境填写不必要的真实敏感信息。',
      ],
      [
        '浏览器存储',
        '浏览器本地保存会员登录令牌与游客购物车。登录令牌用于向后端证明会员身份。退出登录会清除当前登录状态；游客购物车在登录时尝试合并。',
      ],
      [
        '数据管理',
        '可以在个人中心编辑资料、修改密码、维护地址，并在宠物档案页导出或归档档案。账号注销属于后续版本。请在共用设备上使用后退出登录。',
      ],
      [
        '数据保护',
        '本项目仅用于教学与功能验证，正式上线前需要由运营者补齐联系方式、数据保留期限及隐私合规流程。',
      ],
    ],
  },
  about: {
    title: '关于萌宠优选',
    intro: '每一份陪伴，都值得认真挑选。',
    sections: [
      [
        '我们的想法',
        '从第一口好粮到每一次撒欢，我们希望用认真挑选的宠物食品与日常用品，照顾毛孩子的每一天。',
      ],
      [
        '更适合的小日常',
        '为它建立宠物档案，记录物种、生日、体重及过敏说明，让选购时的适配提示更有参考意义。',
      ],
      [
        '项目说明',
        '萌宠优选是基于 RuoYi-Vue 与 Spring Boot 的课程实践项目。当前页面中的支付及订单流程为教学沙箱演示。',
      ],
    ],
  },
}
</script>
<template>
  <article class="panel legal-page">
    <nav class="legal-nav">
      <router-link to="/agreement?type=user">用户协议</router-link
      ><router-link to="/agreement?type=privacy">隐私政策</router-link
      ><router-link to="/agreement?type=about">关于我们</router-link>
    </nav>
    <span class="eyebrow">PET & GOOD</span>
    <h1>{{ content[type].title }}</h1>
    <p class="legal-intro">{{ content[type].intro }}</p>
    <section v-for="(section, index) in content[type].sections" :key="section[0]">
      <h2>{{ index + 1 }}. {{ section[0] }}</h2>
      <p>{{ section[1] }}</p>
    </section>
    <router-link to="/" class="text-link">回到首页 ↗</router-link>
  </article>
</template>
