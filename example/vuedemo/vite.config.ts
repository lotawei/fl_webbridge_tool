import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  base: './',  // 相对路径，确保 Flutter WebView 加载 asset 文件正确
  plugins: [vue()],
  // 开发时允许 Flutter WebView 跨域访问
  server: {
    host: '0.0.0.0',
    port: 5173,
    cors: true,
  },
  // 构建用于 Flutter asset 的打包
  build: {
    outDir: '../assets/vuedemo',
    emptyOutDir: true,
  },
})
