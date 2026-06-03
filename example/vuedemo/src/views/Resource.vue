<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { brCall, getBRData } from 'br-web-bridge-vue'

type ResourceStatus = {
  currentVersion: string
  downloading: boolean
  downloadProgress: number
  installedVersions: string[]
  latestRemoteVersion: string | null
  needUpdate: boolean
}

type CheckResult = {
  hasUpdate: boolean
  latestVersion?: string
  forceUpdate?: boolean
  sizeBytes?: number
  releaseNotes?: string
  error?: string
}

const status = ref<ResourceStatus>({
  currentVersion: 'builtin',
  downloading: false,
  downloadProgress: 0,
  installedVersions: [],
  latestRemoteVersion: null,
  needUpdate: false,
})

const logs = ref<string[]>([])
const loading = ref(false)

function addLog(msg: string) {
  const time = new Date().toLocaleTimeString()
  logs.value.unshift(`${time}  ${msg}`)
  if (logs.value.length > 50) logs.value.pop()
}

async function refreshStatus() {
  try {
    status.value = await brCall<ResourceStatus>('resource.getStatus') as any || status.value
  } catch (e: any) {
    addLog(`❌ ${e.message || e}`)
  }
}

async function checkUpdate() {
  loading.value = true
  addLog('🔍 检查更新...')
  try {
    const r = await brCall<CheckResult>('resource.checkUpdate') as any
    if (r.hasUpdate) {
      addLog(`✅ 发现新版本: v${r.latestVersion}`)
      if (r.releaseNotes) addLog(`📝 ${r.releaseNotes}`)
      if (r.forceUpdate) addLog('⚠️ 此版本需要强制更新')
    } else if (r.error) {
      addLog(`⚠️ ${r.error}`)
    } else {
      addLog('✅ 已是最新版本')
    }
    await refreshStatus()
  } catch (e: any) {
    addLog(`❌ ${e.message || e}`)
  } finally {
    loading.value = false
  }
}

async function startUpdate() {
  loading.value = true
  addLog('📥 开始下载...')
  try {
    const r = await brCall<{ ok?: boolean; version?: string; error?: string }>('resource.startUpdate') as any
    if (r.ok) {
      addLog(`✅ 更新完成! 当前版本: v${r.version}`)
    } else {
      addLog(`⚠️ ${r.error}`)
    }
    await refreshStatus()
  } catch (e: any) {
    addLog(`❌ ${e.message || e}`)
  } finally {
    loading.value = false
  }
}

async function cancelUpdate() {
  await brCall('resource.cancelUpdate')
  addLog('⏹️ 已取消下载')
  await refreshStatus()
}

onMounted(refreshStatus)
</script>

<template>
  <div class="page">
    <h2>📦 资源包管理</h2>

    <div class="card">
      <div class="row" v-for="(label, key) in {
        '当前版本': 'v' + status.currentVersion,
        '网络状态': status.downloading ? '下载中...' : '空闲',
        '已安装版本': status.installedVersions.length ? status.installedVersions.map(v => 'v' + v).join(', ') : '无',
      }" :key="String(key)">
        <span class="label">{{ key }}</span>
        <span class="value">{{ label }}</span>
      </div>

      <div class="progress-section" v-if="status.downloading">
        <div class="progress-bar">
          <div class="progress-fill" :style="{ width: status.downloadProgress + '%' }"></div>
        </div>
        <span class="progress-text">{{ status.downloadProgress }}%</span>
        <button class="btn-cancel" @click="cancelUpdate">取消</button>
      </div>
    </div>

    <div class="actions">
      <button :disabled="loading" @click="checkUpdate">🔍 检查更新</button>
      <button :disabled="loading || !status.needUpdate" @click="startUpdate">📥 下载更新</button>
    </div>

    <div class="logs">
      <div class="log-entry" v-for="(l, i) in logs" :key="i">{{ l }}</div>
      <div v-if="!logs.length" class="empty">暂无日志</div>
    </div>
  </div>
</template>

<style scoped>
.page { padding: 16px; padding-bottom: 40px; }
h2 { font-size: 20px; margin-bottom: 16px; }
.card { padding: 16px; background: #fff; border-radius: 8px; border: 1px solid #e7e9ef; }
.row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #f0f1f5; font-size: 14px; }
.row:last-child { border-bottom: none; }
.label { color: #667085; }
.value { font-weight: 600; }

.progress-section { margin-top: 16px; display: flex; align-items: center; gap: 12px; }
.progress-bar { flex: 1; height: 8px; background: #e7e9ef; border-radius: 4px; overflow: hidden; }
.progress-fill { height: 100%; background: #2563eb; border-radius: 4px; transition: width 0.3s; }
.progress-text { font-size: 13px; color: #2563eb; font-weight: 600; min-width: 36px; }
.btn-cancel { padding: 4px 12px; font-size: 13px; background: #ef4444; color: white; border: 0; border-radius: 6px; cursor: pointer; }

.actions { display: flex; gap: 8px; margin-top: 14px; }
.actions button { flex: 1; padding: 12px; border: 0; border-radius: 8px; background: #2563eb; color: white; font-size: 15px; font-weight: 600; cursor: pointer; }
.actions button:disabled { opacity: 0.4; cursor: not-allowed; }
.actions button:last-child { background: #16a34a; }

.logs { margin-top: 16px; padding: 12px; border: 1px solid #e7e9ef; border-radius: 8px; background: #fff; max-height: 300px; overflow: auto; }
.log-entry { font-size: 12px; font-family: monospace; padding: 3px 0; color: #344054; }
.empty { font-size: 12px; color: #98a2b3; text-align: center; padding: 20px; }
</style>
