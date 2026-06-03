<script setup lang="ts">
import { useBridge, getBRData } from 'br-web-bridge-vue'
import { computed, ref } from 'vue'

const { logs, call, appendLog } = useBridge()
const brData = computed(() => getBRData())
const isLoggedIn = computed(() => !!brData.value.accessToken)
const userName = computed(() => (brData.value.user as any)?.name ?? '')
const lang = computed(() => (brData.value.lang as string) || 'zh-CN')

// ====== 文件画廊（Vue 端自建预览） ======
interface GalleryItem {
  path: string; name: string; type: 'image' | 'video' | 'audio' | 'file'
  dataUrl?: string; size?: number; sizeKB?: number; mimeType?: string
}
const gallery = ref<GalleryItem[]>([])
const viewingIndex = ref(-1)  // -1 = 不展示，>=0 = 全屏看第 N 张图

function inferType(item: any): GalleryItem['type'] {
  const mime = item?.mimeType as string | undefined
  if (mime) {
    if (mime.startsWith('image/')) return 'image'
    if (mime.startsWith('video/')) return 'video'
    if (mime.startsWith('audio/')) return 'audio'
  }
  const ext = (item?.name as string ?? '').split('.').pop()?.toLowerCase()
  if (['jpg','jpeg','png','gif','webp','heic','bmp','svg'].includes(ext ?? '')) return 'image'
  if (['mp4','mov','avi','mkv','3gp'].includes(ext ?? '')) return 'video'
  if (['m4a','aac','mp3','wav','ogg','flac'].includes(ext ?? '')) return 'audio'
  return 'file'
}

function formatSize(bytes?: number) {
  if (!bytes) return ''
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

function removeFile(index: number) { gallery.value.splice(index, 1) }
function clearGallery() { gallery.value = []; viewingIndex.value = -1 }

// 添加到画廊（如果已存在同路径文件则更新，否则新增）
async function addToGallery(item: any) {
  const itemPath = item.path ?? '';
  
  const gi: GalleryItem = { 
    path: itemPath, 
    name: item.name ?? 'unknown', 
    type: inferType(item), 
    size: item.size as number | undefined, 
    sizeKB: item.sizeKB as number | undefined, 
    mimeType: item.mimeType as string | undefined 
  }
  
  if (gi.type === 'image' && gi.path) {
    try {
      const data = await call('device.file.readAsDataUrl', { path: gi.path })
      gi.dataUrl = (data as any)?.dataUrl as string | undefined
    } catch (e) { /* fallback: no preview */ }
  }

  // Find if the path already exists
  const existingIndex = gallery.value.findIndex(g => g.path === itemPath);
  
  if (existingIndex !== -1) {
    // Replace the old item with the fresh one
    gallery.value[existingIndex] = gi;
  } else {
    // Otherwise, push it as a new item
    gallery.value.push(gi);
  }
}


async function addMultiToGallery(items: any[]) {
  for (const item of items) { await addToGallery(item) }
}

// ====== Bridge API ======
async function takePhoto() {
  const res = await call('device.camera.takePhoto', { quality: 80, maxWidth: 1600, saveToGallery: true })
  appendLog(res)
  if (res?.cancelled !== false) return
  await addToGallery(res)
}

async function pickPhoto() {
  const res = await call('device.camera.pickPhoto', { maxSizeKB: 1024 })
  appendLog(res)
  if (res?.cancelled !== false) return
  await addToGallery(res)
}

async function pickMultiPhoto() {
  const res = await call('device.camera.pickMultiPhoto', { quality: 85 })
  appendLog(res)
  const files = res?.files as any[] | undefined
  if (files && files.length) await addMultiToGallery(files)
}

async function takeVideo(save: boolean) {
  const res = await call('device.camera.takeVideo', { maxDuration: 15, camera: 'rear', saveToGallery: save })
  appendLog(res)
  if (res?.cancelled !== false) return
  await addToGallery(res)
}

async function pickVideo() {
  const res = await call('device.camera.pickVideo', { maxDuration: 600 })
  appendLog(res)
  if (res?.cancelled !== false) return
  await addToGallery(res)
}

async function startRecord() { appendLog(await call('device.audio.startRecord')) }
async function stopRecord() {
  const res = await call('device.audio.stopRecord')
  appendLog(res)
  if (res?.path) await addToGallery(res)
}

async function pickFile() {
  const res = await call('device.file.pick', { multiple: true })
  appendLog(res)
  const files = res?.files as any[] | undefined
  if (files && files.length) await addMultiToGallery(files)
}

// 点击视频/音频/文件 → 用原生预览
async function openNativePreview(item: GalleryItem) {
  appendLog(await call('device.file.preview', { path: item.path, type: item.type === 'file' ? undefined : item.type, title: item.name, mimeType: item.mimeType, size: item.size }))
}

async function deleteFile() { const path = prompt('待删除文件路径'); if (!path) return; appendLog(await call('device.file.delete', { path })) }
async function getNetworkStatus() { appendLog(await call('device.network.status')) }
async function getSystemInfo() { appendLog(await call('device.system.info')) }
async function navigateTo() { appendLog(await call('navigation.navigateTo', { route: '/h2' })) }
async function setTitle() { const t = prompt('新标题'); if (t) { document.title = t; appendLog(await call('navigation.setTitle', { title: t })) } }
let tabVisible = true
async function toggleTabBar() { tabVisible = !tabVisible; appendLog(await call(tabVisible ? 'ui.showTabBar' : 'ui.hideTabBar')) }
async function closePage() { appendLog(await call('container.close', { reason: 'h5_request' })) }

// ====== Web API 探测器（仅供调试） ======
function isWebView(): boolean { return !!(window as any).flutter_inappwebview }
function isIOS(): boolean { return /iPhone|iPad|iPod/i.test(navigator.userAgent) }
function isAndroid(): boolean { return /Android/i.test(navigator.userAgent) }

async function requestWebCamera() {
  appendLog('🔍 尝试 Web API: navigator.mediaDevices.getUserMedia({video})...')
  if (isIOS()) { appendLog('❌ iOS WKWebView 不支持 getUserMedia（Apple 限制）。\n→ 请使用 Bridge API: 点击上方"📷 拍照"按钮'); return }
  if (isAndroid() && isWebView()) { appendLog('⚠️ Android WebView 对 getUserMedia 支持不稳定。\n→ 推荐使用 Bridge API'); return }
  try { const stream = await navigator.mediaDevices.getUserMedia({ video: true }); appendLog('✅ getUserMedia(video) 成功'); stream.getTracks().forEach(t => t.stop()) }
  catch (e: any) { appendLog({ webApi: 'getUserMedia(video)', error: e.message || String(e) }) }
}
async function requestWebMicrophone() {
  appendLog('🔍 尝试 Web API: navigator.mediaDevices.getUserMedia({audio})...')
  if (isIOS()) { appendLog('❌ iOS WKWebView 不支持 getUserMedia（Apple 限制）。\n→ 请使用 Bridge API: 点击上方"🎙️"按钮'); return }
  if (isAndroid() && isWebView()) { appendLog('⚠️ Android WebView 对 getUserMedia 支持不稳定。\n→ 推荐使用 Bridge API'); return }
  try { const stream = await navigator.mediaDevices.getUserMedia({ audio: true }); appendLog('✅ getUserMedia(audio) 成功'); stream.getTracks().forEach(t => t.stop()) }
  catch (e: any) { appendLog({ webApi: 'getUserMedia(audio)', error: e.message || String(e) }) }
}
async function requestWebCameraAndMicrophone() {
  appendLog('🔍 尝试 Web API: navigator.mediaDevices.getUserMedia({video, audio})...')
  if (isIOS()) { appendLog('❌ iOS WKWebView 不支持 getUserMedia（Apple 限制）。\n→ 请使用 Bridge API'); return }
  if (isAndroid() && isWebView()) { appendLog('⚠️ Android WebView 对 getUserMedia 支持不稳定。\n→ 推荐使用 Bridge API'); return }
  try { const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true }); appendLog('✅ getUserMedia(video+audio) 成功'); stream.getTracks().forEach(t => t.stop()) }
  catch (e: any) { appendLog({ webApi: 'getUserMedia(video+audio)', error: e.message || String(e) }) }
}
async function requestWebLocation() {
  appendLog('🔍 尝试 Web API: navigator.geolocation.getCurrentPosition()...')
  try {
    if (!navigator.geolocation) { appendLog('❌ 当前环境不支持 navigator.geolocation'); return }
    const pos = await new Promise<GeolocationPosition>((res, rej) => navigator.geolocation.getCurrentPosition(res, rej, { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }))
    appendLog({ webApi: 'geolocation', coords: { latitude: pos.coords.latitude, longitude: pos.coords.longitude, accuracy: `${pos.coords.accuracy}m` } })
  } catch (e: any) { appendLog({ webApi: 'geolocation', error: e.message || String(e) }) }
}
async function requestWebScreenCapture() {
  appendLog('🔍 尝试 Web API: navigator.mediaDevices.getDisplayMedia()...')
  if (isIOS() || isAndroid()) { appendLog('❌ 移动端不支持 getDisplayMedia'); return }
  try { const stream = await (navigator.mediaDevices as any).getDisplayMedia({ video: true }); appendLog('✅ getDisplayMedia 成功'); stream.getTracks().forEach((t: MediaStreamTrack) => t.stop()) }
  catch (e: any) { appendLog({ webApi: 'getDisplayMedia', error: e.message || String(e) }) }
}
</script>

<template>
  <div class="app">
    <main>
      <!-- Bridge API 按钮 -->
      <button @click="takePhoto">📷 拍照（存相册）</button>
      <button @click="pickPhoto">🖼️ 从相册选照片</button>
      <button @click="pickMultiPhoto">🖼️🖼️ 多选照片</button>
      <button @click="takeVideo(true)">🎥 录像（存相册）</button>
      <button @click="takeVideo(false)">🎥 录像（不入相册）</button>
      <button @click="pickFile">📂 选择文件</button>
      <button @click="pickVideo">🎬 从相册选视频</button>
      <button @click="startRecord">🎙️ 开始录音</button>
      <button @click="stopRecord">⏹️ 停止录音</button>
      <button @click="deleteFile">🗑️ 删除文件</button>

      <!-- 文件画廊 -->
      <div v-if="gallery.length" class="gallery-section">
        <div class="gallery-header">
          <span class="gallery-title">📁 已选文件 ({{ gallery.length }})</span>
          <button class="btn-clear" @click="clearGallery">清空</button>
        </div>
        <div class="gallery-grid">
          <div v-for="(item, i) in gallery" :key="i" class="gallery-card" @click="item.type === 'image' ? (viewingIndex = i) : openNativePreview(item)">
            <!-- 图片缩略图 -->
            <img v-if="item.type === 'image' && item.dataUrl" :src="item.dataUrl" class="card-thumb" />
            <div v-else class="card-icon">
              <span v-if="item.type === 'image' && !item.dataUrl">🖼️</span>
              <span v-else-if="item.type === 'video'">🎬</span>
              <span v-else-if="item.type === 'audio'">🎵</span>
              <span v-else>📄</span>
            </div>
            <div class="card-name">{{ item.name }}</div>
            <div class="card-size" v-if="item.size">{{ formatSize(item.size) }}</div>
            <button class="card-del" @click.stop="removeFile(i)">✕</button>
          </div>
        </div>
      </div>

      <hr />

      <!-- Web API 探测器 -->
      <div class="section-label">🔬 Web API 探测器</div>
      <button class="btn-debug" @click="requestWebCamera">📷 Web API 相机</button>
      <button class="btn-debug" @click="requestWebMicrophone">🎤 Web API 麦克风</button>
      <button class="btn-debug" @click="requestWebCameraAndMicrophone">📷🎤 Web API 音视频</button>
      <button class="btn-debug" @click="requestWebLocation">📍 Web API 定位</button>
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

    <!-- 图片全屏查看器 -->
    <div v-if="viewingIndex >= 0" class="fullscreen-viewer" @click="viewingIndex = -1">
      <div class="viewer-nav">
        <button class="viewer-close" @click.stop="viewingIndex = -1">✕</button>
        <span class="viewer-count">{{ viewingIndex + 1 }} / {{ gallery.length }}</span>
        <button class="viewer-del" @click.stop="removeFile(viewingIndex); if (gallery.length === 0) viewingIndex = -1">🗑️</button>
      </div>
      <img v-if="gallery[viewingIndex]?.dataUrl" :src="gallery[viewingIndex].dataUrl!" class="viewer-img" @click.stop />
      <div class="viewer-actions">
        <button class="viewer-prev" @click.stop="viewingIndex > 0 ? viewingIndex-- : viewingIndex = gallery.length - 1">◀</button>
        <button class="viewer-next" @click.stop="viewingIndex < gallery.length - 1 ? viewingIndex++ : viewingIndex = 0">▶</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
* { box-sizing: border-box; margin: 0; padding: 0; }
.app { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: #172033; background: #f7f8fb; min-height: 100vh; padding-bottom: 40px; }
main { padding: 16px; }
button { width: 100%; height: 46px; margin: 7px 0; border: 0; border-radius: 8px; color: white; background: #2563eb; font-size: 16px; font-weight: 600; cursor: pointer; }
button:active { opacity: 0.85; }
button.secondary { background: #475467; }
.section-label { font-size: 12px; color: #98a2b3; margin: 8px 0 4px; text-align: center; }
.btn-debug { background: #6b7280; color: #f9fafb; font-size: 14px; height: 38px; }
hr { margin: 14px 0; border: none; border-top: 1px solid #e7e9ef; }
pre.log { margin-top: 14px; padding: 12px; min-height: 120px; max-height: 200px; overflow: auto; border: 1px solid #e7e9ef; border-radius: 8px; background: #ffffff; white-space: pre-wrap; word-break: break-word; font-size: 12px; line-height: 1.6; }

/* 文件画廊 */
.gallery-section { margin: 14px 0; padding: 12px; background: #fff; border-radius: 8px; border: 1px solid #e7e9ef; }
.gallery-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; }
.gallery-title { font-size: 14px; font-weight: 600; color: #172033; }
.btn-clear { width: auto; height: 30px; padding: 0 14px; font-size: 13px; background: #ef4444; margin: 0; }
.gallery-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.gallery-card { position: relative; border-radius: 8px; overflow: hidden; background: #f1f5f9; cursor: pointer; border: 1px solid #e7e9ef; min-height: 100px; display: flex; flex-direction: column; align-items: center; justify-content: center; }
.card-thumb { width: 100%; height: 100px; object-fit: cover; }
.card-icon { font-size: 32px; padding: 16px 0 4px; }
.card-name { font-size: 10px; color: #172033; padding: 4px 6px; text-align: center; word-break: break-all; max-width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.card-size { font-size: 9px; color: #98a2b3; padding-bottom: 4px; }
.card-del { position: absolute; top: 2px; right: 2px; width: 22px; height: 22px; font-size: 11px; background: rgba(0,0,0,0.5); color: white; border-radius: 50%; padding: 0; margin: 0; display: flex; align-items: center; justify-content: center; line-height: 1; }

/* 全屏查看器 */
.fullscreen-viewer { position: fixed; inset: 0; background: rgba(0,0,0,0.95); z-index: 1000; display: flex; flex-direction: column; align-items: center; justify-content: center; }
.viewer-nav { position: absolute; top: 0; left: 0; right: 0; display: flex; align-items: center; justify-content: space-between; padding: 12px 16px; color: white; }
.viewer-close, .viewer-del { background: none; border: none; color: white; font-size: 22px; width: 40px; height: 40px; margin: 0; cursor: pointer; }
.viewer-count { font-size: 14px; }
.viewer-img { max-width: 95vw; max-height: 75vh; object-fit: contain; border-radius: 4px; }
.viewer-actions { position: absolute; bottom: 24px; display: flex; gap: 48px; }
.viewer-prev, .viewer-next { width: 52px; height: 52px; border-radius: 50%; background: rgba(255,255,255,0.15); color: white; font-size: 22px; border: none; margin: 0; cursor: pointer; display: flex; align-items: center; justify-content: center; }
</style>
