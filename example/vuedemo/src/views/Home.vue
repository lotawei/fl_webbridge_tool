<script setup lang="ts">
import { useBridge, getBRData } from 'br-web-bridge-vue'
import { computed } from 'vue'

const { logs, call, appendLog } = useBridge()
const brData = computed(() => getBRData())
const isLoggedIn = computed(() => !!brData.value.accessToken)
const userName = computed(() => (brData.value.user as any)?.name ?? '')
const lang = computed(() => (brData.value.lang as string) || 'zh-CN')

// ====== 拍照（默认 ≤1MB）======
async function takePhoto() {
  appendLog(await call('device.camera.takePhoto', {
    maxWidth: 1600, maxHeight: 2400, maxSizeKB: 1024, saveToGallery: true
  }))
}

// ====== 从相册选照片 ======
async function pickPhoto() {
  appendLog(await call('device.camera.pickPhoto', { maxSizeKB: 1024 }))
}

// ====== 录像 ======
async function takeVideo(save: boolean) {
  appendLog(await call('device.camera.takeVideo', { maxDuration: 15, camera: 'rear', saveToGallery: save }))
}

// ====== 从相册选视频 ======
async function pickVideo() {
  appendLog(await call('device.camera.pickVideo', { maxDuration: 600 }))
}

// ====== 录音 ======
async function startRecord() { appendLog(await call('device.audio.startRecord')) }
async function stopRecord() { appendLog(await call('device.audio.stopRecord')) }

// ====== 文件 ======
async function pickFile() { appendLog(await call('device.file.pick', { multiple: true })) }
async function previewFile() {
  const type = prompt('预览类型: image / video / audio', 'image')
  const path = prompt('文件路径', type === 'image' ? '/path/to/photo.jpg' : '/path/to/file.mp4')
  if (!path) return
  appendLog(await call('device.file.preview', { path, type, title: '预览' }))
}
async function deleteFile() {
  const path = prompt('待删除文件路径', '/path/to/file')
  if (!path) return
  appendLog(await call('device.file.delete', { path }))
}

// ====== 网络 & 系统 ======
async function getNetworkStatus() { appendLog(await call('device.network.status')) }
async function getSystemInfo() { appendLog(await call('device.system.info')) }

// ====== 网页原生 Web API 权限 ======
function formatWebApiError(error: unknown) {
  if (error instanceof DOMException) {
    return { name: error.name, message: error.message }
  }
  if (error instanceof Error) {
    return { name: error.name, message: error.message }
  }
  return { error: String(error) }
}

function stopStream(stream: MediaStream) {
  stream.getTracks().forEach((track) => track.stop())
}

async function requestWebCamera() {
  try {
    if (!navigator.mediaDevices?.getUserMedia) {
      appendLog('当前环境不支持 navigator.mediaDevices.getUserMedia')
      return
    }
    const stream = await navigator.mediaDevices.getUserMedia({ video: true })
    appendLog({
      webApi: 'getUserMedia(video)',
      tracks: stream.getTracks().map((track) => ({
        kind: track.kind,
        label: track.label,
        readyState: track.readyState,
      })),
    })
    stopStream(stream)
  } catch (error) {
    appendLog({ webApi: 'getUserMedia(video)', error: formatWebApiError(error) })
  }
}

async function requestWebMicrophone() {
  try {
    if (!navigator.mediaDevices?.getUserMedia) {
      appendLog('当前环境不支持 navigator.mediaDevices.getUserMedia')
      return
    }
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    appendLog({
      webApi: 'getUserMedia(audio)',
      tracks: stream.getTracks().map((track) => ({
        kind: track.kind,
        label: track.label,
        readyState: track.readyState,
      })),
    })
    stopStream(stream)
  } catch (error) {
    appendLog({ webApi: 'getUserMedia(audio)', error: formatWebApiError(error) })
  }
}

async function requestWebCameraAndMicrophone() {
  try {
    if (!navigator.mediaDevices?.getUserMedia) {
      appendLog('当前环境不支持 navigator.mediaDevices.getUserMedia')
      return
    }
    const stream = await navigator.mediaDevices.getUserMedia({
      video: true,
      audio: true,
    })
    appendLog({
      webApi: 'getUserMedia(video+audio)',
      tracks: stream.getTracks().map((track) => ({
        kind: track.kind,
        label: track.label,
        readyState: track.readyState,
      })),
    })
    stopStream(stream)
  } catch (error) {
    appendLog({
      webApi: 'getUserMedia(video+audio)',
      error: formatWebApiError(error),
    })
  }
}

async function requestWebLocation() {
  try {
    if (!navigator.geolocation) {
      appendLog('当前环境不支持 navigator.geolocation')
      return
    }
    const position = await new Promise<GeolocationPosition>((resolve, reject) => {
      navigator.geolocation.getCurrentPosition(resolve, reject, {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 0,
      })
    })
    appendLog({
      webApi: 'geolocation.getCurrentPosition',
      coords: {
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
        accuracy: position.coords.accuracy,
      },
    })
  } catch (error) {
    appendLog({
      webApi: 'geolocation.getCurrentPosition',
      error: formatWebApiError(error),
    })
  }
}

async function requestWebScreenCapture() {
  try {
    const getDisplayMedia = (
      navigator.mediaDevices as MediaDevices & {
        getDisplayMedia?: (constraints?: MediaStreamConstraints) => Promise<MediaStream>
      }
    )?.getDisplayMedia
    if (!getDisplayMedia) {
      appendLog('当前环境不支持 navigator.mediaDevices.getDisplayMedia')
      return
    }
    const stream = await getDisplayMedia({ video: true, audio: false })
    appendLog({
      webApi: 'getDisplayMedia(video)',
      tracks: stream.getTracks().map((track) => ({
        kind: track.kind,
        label: track.label,
        readyState: track.readyState,
      })),
    })
    stopStream(stream)
  } catch (error) {
    appendLog({ webApi: 'getDisplayMedia(video)', error: formatWebApiError(error) })
  }
}

// ====== 导航 & UI ======
async function navigateTo() { appendLog(await call('navigation.navigateTo', { route: '/h2' })) }
async function setTitle() {
  const t = prompt('新标题', document.title)
  if (t) { document.title = t; appendLog(await call('navigation.setTitle', { title: t })) }
}
let tabVisible = true
async function toggleTabBar() { tabVisible = !tabVisible; appendLog(await call(tabVisible ? 'ui.showTabBar' : 'ui.hideTabBar')) }
async function closePage() { appendLog(await call('container.close', { reason: 'h5_request' })) }
</script>

<template>
  <div class="app">
    <header>
      <h1>BR_Web 首页</h1>
      <p class="user-info" v-if="isLoggedIn">👤 {{ userName }} &nbsp;|&nbsp; 🌐 {{ lang }}</p>
    </header>

    <nav class="tabs">
      <router-link to="/" class="tab" exact-active-class="active">🏠 主页</router-link>
      <router-link to="/nav" class="tab" active-class="active">🧭 导航</router-link>
      <router-link to="/profile" class="tab" active-class="active">👤 我的</router-link>
    </nav>

    <main>
      <button @click="takePhoto">📷 拍照（存相册）</button>
      <button @click="takeVideo(true)">🎥 录像（存相册）</button>
      <button @click="takeVideo(false)">🎥 录像（不入相册）</button>
      <button @click="pickFile">📂 选择文件</button>
      <button @click="pickVideo">🎬 从相册选视频</button>
      <button @click="startRecord">🎙️ 开始录音</button>
      <button @click="stopRecord">⏹️ 停止录音</button>
      <button @click="previewFile">👁️ 预览文件</button>
      <button @click="deleteFile">🗑️ 删除文件</button>

      <hr />

      <button @click="requestWebCamera">🌐 Web API 相机权限</button>
      <button @click="requestWebMicrophone">🌐 Web API 麦克风权限</button>
      <button @click="requestWebCameraAndMicrophone">🌐 Web API 音视频权限</button>
      <button @click="requestWebLocation">🌐 Web API 定位权限</button>
      <button @click="requestWebScreenCapture">🌐 Web API 屏幕捕获</button>

      <hr />

      <button @click="getNetworkStatus">📶 查询网络状态</button>
      <button @click="getSystemInfo">📱 查询系统信息</button>
      <button @click="setTitle">✏️ 设置标题</button>
      <button @click="navigateTo">➡️ 跳转到 H2</button>
      <button @click="toggleTabBar">👁️ 切换 TabBar 显隐</button>
      <button class="secondary" @click="closePage">🚪 退出</button>

      <pre class="log"><div v-for="(l, i) in logs" :key="i">{{ l.time }}  {{ l.text }}</div></pre>
    </main>
  </div>
</template>

<style scoped>
* { box-sizing: border-box; margin: 0; padding: 0; }
.app { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: #172033; background: #f7f8fb; min-height: 100vh; padding-bottom: 40px; }
header { padding: 20px 18px 12px; background: #ffffff; border-bottom: 1px solid #e7e9ef; }
h1 { font-size: 22px; margin-bottom: 6px; }
.user-info { color: #667085; line-height: 1.5; font-size: 13px; }
.tabs { display: flex; background: #fff; border-bottom: 1px solid #e7e9ef; }
.tab { flex: 1; text-align: center; padding: 12px 0; color: #667085; font-size: 14px; font-weight: 600; text-decoration: none; border-bottom: 2px solid transparent; }
.tab.active { color: #2563eb; border-bottom-color: #2563eb; }
main { padding: 16px; }
button { width: 100%; height: 46px; margin: 7px 0; border: 0; border-radius: 8px; color: white; background: #2563eb; font-size: 16px; font-weight: 600; cursor: pointer; }
button:active { opacity: 0.85; }
button.secondary { background: #475467; }
hr { margin: 14px 0; border: none; border-top: 1px solid #e7e9ef; }
pre.log { margin-top: 14px; padding: 12px; min-height: 200px; max-height: 400px; overflow: auto; border: 1px solid #e7e9ef; border-radius: 8px; background: #ffffff; white-space: pre-wrap; word-break: break-word; font-size: 12px; line-height: 1.6; }
</style>
