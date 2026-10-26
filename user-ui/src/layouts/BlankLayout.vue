<template>
  <div class="blank-layout">
    <div class="container blank-header">
      <router-link to="/" class="brand"
        ><img src="/images/logo.svg" alt="" /><span
          >萌宠优选<small>PET & GOOD</small></span
        ></router-link
      ><router-link to="/" class="muted">返回首页 ↗</router-link>
    </div>
    <main class="container blank-content"><slot /></main>
    <footer class="blank-footer">萌宠优选 · 每一份陪伴，都值得认真挑选</footer>
  </div>
</template>
