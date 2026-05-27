<template>
  <div class="view">
    <h2 class="title">📷 设备能力</h2>

    <button class="btn" @click="takePhoto">📷 拍照（存相册）</button>
    <button class="btn" @click="takeVideo(true)">🎥 录像（存相册）</button>
    <button class="btn btn-outline" @click="takeVideo(false)">🎥 录像（不入相册）</button>
    <button class="btn" @click="startRecord">🎙️ 开始录音</button>
    <button class="btn btn-outline" @click="stopRecord">⏹️ 停止录音</button>

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

async function takePhoto() { append(await call('device.camera.takePhoto', { quality: 80, maxWidth: 1600 })) }

async function takeVideo(save) {
  append(await call('device.camera.takeVideo', { maxDuration: 15, camera: 'rear', saveToGallery: save }))
}

async function startRecord() { append(await call('device.audio.startRecord')) }
async function stopRecord()  { append(await call('device.audio.stopRecord')) }
</script>
