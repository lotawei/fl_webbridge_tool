# BR_Web Bridge Vue

Vue 3 SDK for BR_Web Flutter bridge.

## Install

```bash
npm install br-web-bridge-vue
```

## Quick Start

### 1. Register plugin (optional)

```ts
// main.ts
import { createApp } from 'vue'
import { BRWebBridgePlugin } from 'br-web-bridge-vue'
import App from './App.vue'

const app = createApp(App)
app.use(BRWebBridgePlugin)
app.mount('#app')
```

### 2. Use composable

```vue
<script setup lang="ts">
import { useBridge, getBRData } from 'br-web-bridge-vue'

const { takePhoto, takeVideo, startRecord, stopRecord, navigateTo, hideTabBar } = useBridge()

// Read injected native data
const token = getBRData().accessToken
</script>

<template>
  <button @click="takePhoto()">📷 拍照</button>
  <button @click="takeVideo()">🎥 录像</button>
  <button @click="startRecord()">🎙️ 录音</button>
  <button @click="navigateTo({ route: '/h2' })">➡️ 跳转 H2</button>
</template>
```

### 3. Low-level API

```ts
import { brCall, getBRData, waitForBridge } from 'br-web-bridge-vue'

// Call any bridge action
const result = await brCall('device.camera.takePhoto', { quality: 80 })

// Read injected data
const token = getBRData().accessToken

// Wait for native bridge
await waitForBridge()
```

## API

### Composable: `useBridge()`

Returns methods for all bridge actions:
- `takePhoto()`, `takeVideo()`, `pickVideo()`
- `startRecord()`, `stopRecord()`
- `pickFile()`, `previewFile()`, `deleteFile()`
- `navigateTo()`, `goBack()`, `setTitle()`
- `hideTabBar()`, `showTabBar()`
- `getNetworkStatus()`, `getSystemInfo()`
- `closePage()`

### Low-level: `brCall(action, params)`

Generic bridge call.

### `getBRData()`

Read `window.__BR_Data__` injected by native.

### `waitForBridge()`

Returns Promise that resolves when bridge is ready.
