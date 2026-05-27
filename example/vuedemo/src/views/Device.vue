<script setup lang="ts">
import { useBridge } from '../composables/useBridge'
const { logs, call, appendLog } = useBridge()
async function takePhoto() { appendLog(await call('device.camera.takePhoto', { quality: 80 })) }
async function takeVideo() { appendLog(await call('device.camera.takeVideo', { maxDuration: 15 })) }
</script>
<template>
  <h2>⚙️ 设备操作</h2>
  <button @click="takePhoto">📷 拍照</button>
  <button @click="takeVideo">🎥 录像</button>
  <pre class="log"><div v-for="(l, i) in logs" :key="i">{{ l.time }}  {{ l.text }}</div></pre>
</template>
