<script setup lang="ts">
import { useBridge } from '../composables/useBridge'
import { useBRData } from '../composables/useBRData'
import { useAppLifecycle } from '../composables/useAppLifecycle'
import { ref } from 'vue'

const { logs, bridgeReady, isInWebView, call, appendLog } = useBridge()
const { brData, isLoggedIn, userName, lang } = useBRData()
const { appState, pageVisible, label: stateLabel } = useAppLifecycle()

let tabVisible = true

// ====== 设备能力 ======
async function takePhoto() {
  appendLog(await call('device.camera.takePhoto', {
    maxWidth: 1600,
    maxSizeKB: 1024,        // 默认 ≤1MB，需更小可改
  }))
}

async function pickPhoto() {
  appendLog(await call('device.camera.pickPhoto', {
    maxWidth: 1600,
    maxSizeKB: 1024,
  }))
}

async function takeVideo() {
  appendLog(await call('device.camera.takeVideo', { maxDuration: 15, camera: 'rear', saveToGallery: true }))
}

async function takeVideoNoSave() {
  appendLog(await call('device.camera.takeVideo', { maxDuration: 15, camera: 'rear', saveToGallery: false }))
}

async function pickFile() {
  appendLog(await call('device.file.pick', { multiple: true }))
}

async function pickVideo() {
  appendLog(await call('device.camera.pickVideo', { maxDuration: 600 }))
}

async function startRecord() {
  appendLog(await call('device.audio.startRecord'))
}

async function stopRecord() {
  appendLog(await call('device.audio.stopRecord'))
}

async function previewFile() {
  const type = prompt('预览类型: image / video / audio', 'image')
  const path = prompt('文件路径', type === 'image' ? '/path/to/photo.jpg' : '/path/to/file.mp4')
  if (!path) return
  appendLog(await call('device.file.preview', { path, type, title: '预览' }))
}

async function deleteFile() {
  const path = prompt('待删除文件路径')
  if (!path) return
  appendLog(await call('device.file.delete', { path }))
}

// ====== 导航 & UI ======
async function setMyTitle() {
  const t = prompt('新标题', document.title)
  if (t) {
    document.title = t
    appendLog(await call('navigation.setTitle', { title: t }))
  }
}

async function navigateToH2() {
  appendLog(await call('navigation.navigateTo', { route: '/h2' }))
}

async function toggleTabBar() {
  tabVisible = !tabVisible
  appendLog(await call(tabVisible ? 'ui.showTabBar' : 'ui.hideTabBar'))
}

async function closePage() {
  appendLog(await call('container.close', { reason: 'h5_request' }))
}
</script>

<template>
  <div class="app">
    <header>
      <h1>BR_Web Vue3 容器</h1>
      <p class="user-info">
        <template v-if="isLoggedIn()">
          👤 {{ userName() }} &nbsp;|&nbsp; 🌐 {{ lang() }}
          &nbsp;|&nbsp; {{ stateLabel() }}
          &nbsp;|&nbsp; 🟢 bridge ready
        </template>
        <template v-else>
          <span v-if="isInWebView">⚡ WebView 模式 &nbsp;|&nbsp; {{ stateLabel() }} &nbsp;|&nbsp; 等待注入数据...</span>
          <span v-else>🖥️ 浏览器模式（mock）</span>
        </template>
      </p>
    </header>

    <main>
      <!-- 设备能力 -->
      <button @click="takePhoto">📷 拍照 → 相册</button>
      <button @click="pickPhoto">🖼️ 从相册选照片</button>
      <button @click="takeVideo">🎥 录像（存相册）</button>
      <button @click="takeVideoNoSave">🎥 录像（不入相册）</button>
      <button @click="pickFile">📂 选择文件</button>
      <button @click="pickVideo">🎬 从相册选视频</button>
      <button @click="startRecord">🎙️ 开始录音</button>
      <button @click="stopRecord">⏹️ 停止录音</button>
      <button @click="previewFile">👁️ 预览文件</button>
      <button @click="deleteFile">🗑️ 删除文件</button>

      <hr />

      <!-- 导航 / UI 控制 -->
      <button @click="setMyTitle">✏️ 设置标题</button>
      <button @click="navigateToH2">➡️ 跳转到 H2</button>
      <button @click="toggleTabBar">👁️ 切换 TabBar 显隐</button>
      <button class="outline" @click="closePage">🚪 退出</button>

      <!-- 日志 -->
      <pre class="log"><div v-for="(l, i) in logs" :key="i">{{ l.time }}  {{ l.text }}</div></pre>
    </main>
  </div>
</template>

<style scoped>
* { box-sizing: border-box; }
.app {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  color: #172033;
  background: #f7f8fb;
  min-height: 100vh;
}
header {
  padding: 20px 18px 12px;
  background: #ffffff;
  border-bottom: 1px solid #e7e9ef;
}
h1 { margin: 0 0 6px; font-size: 22px; }
p.user-info { margin: 0; color: #667085; line-height: 1.5; font-size: 13px; }
main { padding: 16px; padding-bottom: 40px; }
button {
  width: 100%;
  height: 46px;
  margin: 7px 0;
  border: 0;
  border-radius: 8px;
  color: white;
  background: #2563eb;
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
}
button:active { opacity: 0.85; }
button.outline { background: transparent; color: #2563eb; border: 1.5px solid #2563eb; }
hr { margin: 14px 0; border: none; border-top: 1px solid #e7e9ef; }
pre.log {
  margin-top: 14px;
  padding: 12px;
  min-height: 200px;
  max-height: 400px;
  overflow: auto;
  border: 1px solid #e7e9ef;
  border-radius: 8px;
  background: #ffffff;
  white-space: pre-wrap;
  word-break: break-word;
  font-size: 12px;
  line-height: 1.6;
}
</style>
