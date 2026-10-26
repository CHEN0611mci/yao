import { createApp } from 'vue'
import { createPinia } from 'pinia'
import 'element-plus/es/components/message/style/css'
import 'element-plus/es/components/message-box/style/css'
import './styles/main.css'
import './styles/responsive.css'
import App from './App.vue'
import router from './router/index.js'
createApp(App).use(createPinia()).use(router).mount('#app')
