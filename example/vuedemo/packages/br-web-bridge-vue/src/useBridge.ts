import { ref, readonly } from 'vue'
import { brCall, getBRData, waitForBridge, onNativeCall } from './bridge'
import type {
  PhotoResult, VideoResult, RecordResult, FilePickResult,
  PreviewParams, NavigateParams, SystemInfo,
} from './types'

export { getBRData }

export function useBridge() {
  const logs = ref<Array<{ time: string; text: string }>>([])
  const bridgeReady = ref(false)
  const isInWebView = ref(typeof (window as any).flutter_inappwebview !== 'undefined')

  function appendLog(value: unknown) {
    const text = typeof value === 'string' ? value : JSON.stringify(value, null, 2)
    const time = new Date().toLocaleTimeString()
    logs.value.unshift({ time, text })
    if (logs.value.length > 100) logs.value.pop()
  }

  // 等待 bridge 就绪
  waitForBridge().then(() => {
    bridgeReady.value = true
    appendLog('bridge ready')
  })

  // 注册原生→H5 消息接收
  onNativeCall((payload) => {
    appendLog({ fromNative: payload })
  })

  // ====== 设备能力 ======

  async function takePhoto(params?: Record<string, unknown>) {
    const r = await brCall<PhotoResult>('device.camera.takePhoto', {
      quality: 80, maxWidth: 1600, ...params,
    })
    appendLog(r)
    return r
  }

  async function takeVideo(params?: Record<string, unknown>) {
    const r = await brCall<VideoResult>('device.camera.takeVideo', {
      maxDuration: 15, saveToGallery: true, ...params,
    })
    appendLog(r)
    return r
  }

  async function pickVideo(params?: Record<string, unknown>) {
    const r = await brCall<VideoResult>('device.camera.pickVideo', {
      maxDuration: 600, ...params,
    })
    appendLog(r)
    return r
  }

  async function startRecord() {
    const r = await brCall<RecordResult>('device.audio.startRecord')
    appendLog(r)
    return r
  }

  async function stopRecord() {
    const r = await brCall<RecordResult>('device.audio.stopRecord')
    appendLog(r)
    return r
  }

  async function pickFile(params?: Record<string, unknown>) {
    const r = await brCall<FilePickResult>('device.file.pick', {
      multiple: true, ...params,
    })
    appendLog(r)
    return r
  }

  async function previewFile(params: PreviewParams) {
    const r = await brCall('device.file.preview', params as unknown as Record<string, unknown>)
    appendLog(r)
    return r
  }

  async function deleteFile(path: string) {
    const r = await brCall('device.file.delete', { path })
    appendLog(r)
    return r
  }

  async function getNetworkStatus() {
    const r = await brCall<{ status: string }>('device.network.status')
    appendLog(r)
    return r
  }

  async function getSystemInfo() {
    const r = await brCall<SystemInfo>('device.system.info')
    appendLog(r)
    return r
  }

  // ====== 导航 & UI ======

  async function navigateTo(params: NavigateParams) {
    const r = await brCall('navigation.navigateTo', params as unknown as Record<string, unknown>)
    appendLog(r)
    return r
  }

  async function goBack() {
    const r = await brCall('navigation.goBack')
    appendLog(r)
    return r
  }

  async function setTitle(title: string) {
    document.title = title
    const r = await brCall('navigation.setTitle', { title })
    appendLog(r)
    return r
  }

  async function hideTabBar() {
    const r = await brCall('ui.hideTabBar')
    appendLog(r)
    return r
  }

  async function showTabBar() {
    const r = await brCall('ui.showTabBar')
    appendLog(r)
    return r
  }

  async function closePage(reason = 'h5_request') {
    const r = await brCall('container.close', { reason })
    appendLog(r)
    return r
  }

  return {
    logs: readonly(logs),
    bridgeReady,
    isInWebView,
    call: brCall,
    appendLog,
    // 设备能力
    takePhoto,
    takeVideo,
    pickVideo,
    startRecord,
    stopRecord,
    pickFile,
    previewFile,
    deleteFile,
    getNetworkStatus,
    getSystemInfo,
    // 导航
    navigateTo,
    goBack,
    setTitle,
    hideTabBar,
    showTabBar,
    closePage,
  }
}
