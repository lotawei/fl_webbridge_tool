<script setup lang="ts">
import { useBridge, getBRData } from 'br-web-bridge-vue'
import { computed } from 'vue'
import { TwentyFirstToolbar, type ToolbarConfig } from '@21st-extension/toolbar-vue'

const toolbarConfig: ToolbarConfig = { plugins: [] }

const { logs, bridgeReady, isInWebView, call, appendLog } = useBridge()

const brData = computed(() => getBRData())
const isLoggedIn = computed(() => !!brData.value.accessToken)
const userName = computed(() => (brData.value.user as any)?.name ?? '')
const lang = computed(() => (brData.value.lang as string) || 'zh-CN')

// ====== 设备能力 ======
async function takePhoto() { appendLog(await call('device.camera.takePhoto', { quality: 80, maxWidth: 1600 })) }
async function takeVideo() { appendLog(await call('device.camera.takeVideo', { maxDuration: 15, camera: 'rear', saveToGallery: true })) }
async function takeVideoNoSave() { appendLog(await call('device.camera.takeVideo', { maxDuration: 15, camera: 'rear', saveToGallery: false })) }
async function pickFile() { appendLog(await call('device.file.pick', { multiple: true })) }
async function pickVideo() { appendLog(await call('device.camera.pickVideo', { maxDuration: 600 })) }
async function startRecord() { appendLog(await call('device.audio.startRecord')) }
async function stopRecord() { appendLog(await call('device.audio.stopRecord')) }
async function previewFile() { const type = prompt('预览类型: image / video / audio', 'image'); const path = prompt('文件路径'); if (!path) return; appendLog(await call('device.file.preview', { path, type, title: '预览' })) }
async function deleteFile() { const path = prompt('待删除文件路径'); if (!path) return; appendLog(await call('device.file.delete', { path })) }

// ====== 导航 & UI ======
async function setMyTitle() { const t = prompt('新标题', document.title); if (t) { document.title = t; appendLog(await call('navigation.setTitle', { title: t })) } }
async function navigateToH2() { appendLog(await call('navigation.navigateTo', { route: '/h2' })) }
let tabVisible = true
async function toggleTabBar() { tabVisible = !tabVisible; appendLog(await call(tabVisible ? 'ui.showTabBar' : 'ui.hideTabBar')) }

async function go(route: string) { appendLog(await call('navigation.navigateTo', { route })) }
</script>

<template>
  <TwentyFirstToolbar :config="toolbarConfig" />
  <div class="app">
    <header class="header">
      <h1>BR_Web Vue3 容器</h1>
      <p class="user-info" v-if="isInWebView">
        <template v-if="isLoggedIn">
          👤 {{ userName }} &nbsp;|&nbsp; 🌐 {{ lang }} &nbsp;|&nbsp; 🟢 bridge ready
        </template>
        <template v-else>
          ⚡ WebView 模式 &nbsp;|&nbsp; 等待注入数据...
        </template>
      </p>
      <p class="user-info" v-else>🖥️ 浏览器模式（mock）</p>
    </header>

    <!-- Tab 导航 -->
    <nav class="tabs">
      <router-link to="/" class="tab" exact-active-class="active">🏠 主页</router-link>
      <router-link to="/nav" class="tab" active-class="active">🧭 导航</router-link>
      <router-link to="/profile" class="tab" active-class="active">👤 我的</router-link>
    </nav>

    <main>
      <router-view />
    </main>
  </div>
</template>

<style scoped>
* { box-sizing: border-box; margin: 0; padding: 0; }
.app {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  color: #172033;
  background: #f7f8fb;
  min-height: 100vh;
  padding-bottom: 40px;
}
.header { padding: 20px 18px 12px; background: #ffffff; border-bottom: 1px solid #e7e9ef; }
h1 { font-size: 22px; margin-bottom: 6px; }
.user-info { color: #667085; line-height: 1.5; font-size: 13px; }

.tabs { display: flex; background: #fff; border-bottom: 1px solid #e7e9ef; }
.tab { flex: 1; text-align: center; padding: 12px 0; color: #667085; font-size: 14px; font-weight: 600; text-decoration: none; border-bottom: 2px solid transparent; }
.tab.active { color: #2563eb; border-bottom-color: #2563eb; }

main { padding: 16px; }
button {
  width: 100%; height: 46px; margin: 7px 0; border: 0; border-radius: 8px;
  color: white; background: #2563eb; font-size: 16px; font-weight: 600; cursor: pointer;
}
button:active { opacity: 0.85; }
button.outline { background: transparent; color: #2563eb; border: 1.5px solid #2563eb; }
button.secondary { background: #475467; }
hr { margin: 14px 0; border: none; border-top: 1px solid #e7e9ef; }
pre.log {
  margin-top: 14px; padding: 12px; min-height: 200px; max-height: 400px; overflow: auto;
  border: 1px solid #e7e9ef; border-radius: 8px; background: #ffffff;
  white-space: pre-wrap; word-break: break-word; font-size: 12px; line-height: 1.6;
}
</style>
