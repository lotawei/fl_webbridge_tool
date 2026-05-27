<template>
  <div class="view">
    <h2 class="title">📂 文件管理</h2>

    <button class="btn" @click="pickFile">📂 选择文件</button>
    <button class="btn" @click="pickVideo">🎬 从相册选视频</button>
    <button class="btn" @click="previewFile">👁️ 预览文件</button>
    <button class="btn btn-danger" @click="deleteFile">🗑️ 删除文件</button>

    <pre class="log">{{ log }}</pre>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { call } from '../utils/bridge.js'

const log = ref('')

function append(value) {
  const text = typeof value === 'string' ? value : JSON.stringify(value, null, 2)
  const time = new Date().toLocaleTimeString()
  log.value = `${time}  ${text}\n\n${log.value}`
}

async function pickFile()   { append(await call('device.file.pick', { multiple: true })) }
async function pickVideo()  { append(await call('device.camera.pickVideo', { maxDuration: 600 })) }

async function previewFile() {
  const type = prompt('预览类型: image / video / audio', 'image')
  const path = prompt('文件路径', type === 'image' ? '/path/to/photo.jpg' : '/path/to/file.mp4')
  if (!path) return
  append(await call('device.file.preview', { path, type, title: '预览' }))
}

async function deleteFile() {
  const path = prompt('待删除文件路径', '/path/to/file')
  if (!path) return
  append(await call('device.file.delete', { path }))
}
</script>
