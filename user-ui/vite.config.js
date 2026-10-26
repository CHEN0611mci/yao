import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import Components from 'unplugin-vue-components/vite'
import { ElementPlusResolver } from 'unplugin-vue-components/resolvers'
import { fileURLToPath, URL } from 'node:url'
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const proxy = Object.fromEntries(
    ['/api', '/profile'].map((path) => [
      path,
      { target: env.VITE_API_TARGET || 'http://127.0.0.1:8080', changeOrigin: true },
    ]),
  )
  return {
    plugins: [vue(), Components({ dts: false, resolvers: [ElementPlusResolver()] })],
    resolve: { alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) } },
    server: { port: 81, strictPort: true, proxy },
    preview: { port: 4181, proxy },
    build: { rollupOptions: { output: { manualChunks: { vue: ['vue', 'vue-router', 'pinia'] } } } },
  }
})
