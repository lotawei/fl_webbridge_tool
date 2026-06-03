<script setup lang="ts">
import { useBridge, getBRData } from 'br-web-bridge-vue'
import { computed } from 'vue'

const { logs, call, appendLog } = useBridge()
const brData = computed(() => getBRData())
const isLoggedIn = computed(() => !!brData.value.accessToken)
const userName = computed(() => (brData.value.user as any)?.name ?? '')
const lang = computed(() => (brData.value.lang as string) || 'zh-CN')

// ====== Bridge API (推荐，所有平台可用) ======
async function takePhoto() { appendLog(await call('device.camera.takePhoto', { quality: 80, maxWidth: 1600, saveToGallery: true })) }
async function pickPhoto() { appendLog(await call('device.camera.pickPhoto', { maxSizeKB: 1024 })) }
async function takeVideo(save: boolean) { appendLog(await call('device.camera.takeVideo', { maxDuration: 15, camera: 'rear', saveToGallery: save })) }
async function pickVideo() { appendLog(await call('device.camera.pickVideo', { maxDuration: 600 })) }
async function startRecord() { appendLog(await call('device.audio.startRecord')) }
async function stopRecord() { appendLog(await call('device.audio.stopRecord')) }
async function pickFile() { appendLog(await call('device.file.pick', { multiple: true })) }
async function previewFile() { const type = prompt('预览类型: image / video / audio', 'image'); const path = prompt('文件路径'); if (!path) return; appendLog(await call('device.file.preview', { path, type, title: '预览' })) }
async function deleteFile() { const path = prompt('待删除文件路径'); if (!path) return; appendLog(await call('device.file.delete', { path })) }
async function getNetworkStatus() { appendLog(await call('device.network.status')) }
async function getSystemInfo() { appendLog(await call('device.system.info')) }
async function navigateTo() { appendLog(await call('navigation.navigateTo', { route: '/h2' })) }
async function setTitle() { const t = prompt('新标题'); if (t) { document.title = t; appendLog(await call('navigation.setTitle', { title: t })) } }
let tabVisible = true
async function toggleTabBar() { tabVisible = !tabVisible; appendLog(await call(tabVisible ? 'ui.showTabBar' : 'ui.hideTabBar')) }
async function closePage() { appendLog(await call('container.close', { reason: 'h5_request' })) }

// ====== Web API 探测器（仅供调试了解平台限制） ======
function isWebView(): boolean {
  return !!(window as any).flutter_inappwebview
}

function isIOS(): boolean {
  return /iPhone|iPad|iPod/i.test(navigator.userAgent)
}

function isAndroid(): boolean {
  return /Android/i.test(navigator.userAgent)
}

// ====== 相机（Web API → Bridge 降级） ======
async function requestWebCamera() {
  appendLog('🔍 尝试 Web API: navigator.mediaDevices.getUserMedia({video})...')
  
  if (isIOS()) {
    appendLog('❌ iOS WKWebView 不支持 getUserMedia（Apple 限制）。\n→ 请使用 Bridge API: 点击上方"📷 拍照"按钮')
    return
  }
  if (isAndroid() && isWebView()) {
    appendLog('⚠️ Android WebView 对 getUserMedia 支持不稳定。\n→ 推荐使用 Bridge API: 点击上方"📷 拍照"按钮')
    return
  }
  // 只有桌面 Chrome 才走这个分支
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ video: true })
    appendLog('✅ getUserMedia(video) 成功')
    stream.getTracks().forEach((t: MediaStreamTrack) => t.stop())
  } catch (e: any) {
    appendLog({ webApi: 'getUserMedia(video)', error: e.message || String(e) })
  }
}

// ====== 麦克风（Web API → Bridge 降级） ======
async function requestWebMicrophone() {
  appendLog('🔍 尝试 Web API: navigator.mediaDevices.getUserMedia({audio})...')
  
  if (isIOS()) {
    appendLog('❌ iOS WKWebView 不支持 getUserMedia（Apple 限制）。\n→ 请使用 Bridge API: 点击上方"🎙️ 开始录音"按钮')
    return
  }
  if (isAndroid() && isWebView()) {
    appendLog('⚠️ Android WebView 对 getUserMedia 支持不稳定。\n→ 推荐使用 Bridge API: 点击上方"🎙️ 开始录音"按钮')
    return
  }
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    appendLog('✅ getUserMedia(audio) 成功')
    stream.getTracks().forEach((t: MediaStreamTrack) => t.stop())
  } catch (e: any) {
    appendLog({ webApi: 'getUserMedia(audio)', error: e.message || String(e) })
  }
}

// ====== 音视频（Web API → Bridge 降级） ======
async function requestWebCameraAndMicrophone() {
  appendLog('🔍 尝试 Web API: navigator.mediaDevices.getUserMedia({video, audio})...')
  
  if (isIOS()) {
    appendLog('❌ iOS WKWebView 不支持 getUserMedia（Apple 限制）。\n→ 请使用 Bridge API: "📷 拍照" + "🎙️ 开始录音"')
    return
  }
  if (isAndroid() && isWebView()) {
    appendLog('⚠️ Android WebView 对 getUserMedia 支持不稳定。\n→ 推荐使用 Bridge API')
    return
  }
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true })
    appendLog('✅ getUserMedia(video+audio) 成功')
    stream.getTracks().forEach((t: MediaStreamTrack) => t.stop())
  } catch (e: any) {
    appendLog({ webApi: 'getUserMedia(video+audio)', error: e.message || String(e) })
  }
}

// ====== 定位（✅ 全平台可用） ======
async function requestWebLocation() {
  appendLog('🔍 尝试 Web API: navigator.geolocation.getCurrentPosition()...')
  try {
    if (!navigator.geolocation) {
      appendLog('❌ 当前环境不支持 navigator.geolocation')
      return
    }
    const position = await new Promise<GeolocationPosition>((resolve, reject) => {
      navigator.geolocation.getCurrentPosition(resolve, reject, { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 })
    })
    appendLog({
      webApi: 'geolocation',
      coords: { latitude: position.coords.latitude, longitude: position.coords.longitude, accuracy: `${position.coords.accuracy}m` },
    })
  } catch (e: any) {
    appendLog({ webApi: 'geolocation', error: e.message || String(e) })
  }
}

// ====== 屏幕捕获（❌ 移动端均不支持） ======
async function requestWebScreenCapture() {
  appendLog('🔍 尝试 Web API: navigator.mediaDevices.getDisplayMedia()...')
  
  if (isIOS()) {
    appendLog('❌ iOS 所有浏览器和 WebView 均不支持 getDisplayMedia')
    return
  }
  if (isAndroid()) {
    appendLog('❌ Android 所有浏览器和 WebView 均不支持 getDisplayMedia')
    return
  }
  // 只有桌面 Chrome 才走这个分支
  try {
    const stream = await (navigator.mediaDevices as any).getDisplayMedia({ video: true })
    appendLog('✅ getDisplayMedia 成功')
    stream.getTracks().forEach((t: MediaStreamTrack) => t.stop())
  } catch (e: any) {
    appendLog({ webApi: 'getDisplayMedia', error: e.message || String(e) })
  }
}
</script>

<template>
  <div class="app">


    <main>
      <!-- Bridge API（主线，所有平台可用） -->
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

      <!-- Web API 探测器（仅调试用） -->
      <div class="section-label">🔬 Web API 探测器 — 查看哪些浏览器 API 在当前 WebView 中可用</div>
      <button class="btn-debug" @click="requestWebCamera">📷 Web API 相机</button>
      <button class="btn-debug" @click="requestWebMicrophone">🎤 Web API 麦克风</button>
      <button class="btn-debug" @click="requestWebCameraAndMicrophone">📷🎤 Web API 音视频</button>
      <button class="btn-debug" @click="requestWebLocation">📍 Web API 定位（✅ 可用）</button>
      <button class="btn-debug" @click="requestWebScreenCapture">🖥️ Web API 屏幕捕获</button>

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
.section-label { font-size: 12px; color: #98a2b3; margin: 8px 0 4px; text-align: center; }
.btn-debug { background: #6b7280; color: #f9fafb; font-size: 14px; height: 38px; }
hr { margin: 14px 0; border: none; border-top: 1px solid #e7e9ef; }
pre.log { margin-top: 14px; padding: 12px; min-height: 200px; max-height: 400px; overflow: auto; border: 1px solid #e7e9ef; border-radius: 8px; background: #ffffff; white-space: pre-wrap; word-break: break-word; font-size: 12px; line-height: 1.6; }
</style>
