# BR_Web Bridge API 参考手册

H5 与 Flutter 通信全部通过 `window.flutter_inappwebview.callHandler('BR_WebNativeBridge', message)` 完成，封装在 `useBridge()` composable 中。

---

## 快速上手

```vue
<script setup lang="ts">
import { useBridge } from '../composables/useBridge'
import { useBRData } from '../composables/useBRData'
import { useAppLifecycle } from '../composables/useAppLifecycle'

const { call, appendLog, isInWebView } = useBridge()           // 通信核心
const { userName, isLoggedIn, lang } = useBRData()              // 注入数据
const { appState, pageVisible, label: stateLabel } = useAppLifecycle()  // 生命周期
</script>

<template>
  <!-- 用户信息：Flutter 注入的 window.__BR_Data__，零延迟读取 -->
  <p>👤 {{ userName() }} · 🌐 {{ lang() }} · {{ stateLabel() }}</p>

  <!-- 调用 bridge -->
  <button @click="call('device.camera.takePhoto', { maxWidth: 1600 })">📷</button>
</template>
```

---

## 一、通信基础 —— `useBridge()`

### `call(action, params?)`

通用 bridge 调用，返回 `Promise<Record<string, unknown>>`。

| 参数 | 类型 | 说明 |
|------|------|------|
| `action` | `string` | action 名，见下方各模块 |
| `params` | `Record<string, unknown>` | 可选参数 |

```ts
const result = await call('device.camera.takePhoto', { maxWidth: 1600 })
// →  { cancelled: false, path: '/tmp/xxx.jpg', size: 345678, sizeKB: 337, ... }
```

### `appendLog(value)`

H5 侧本地日志，写入 BridgeDemo 底部的 `<pre class="log">`。

### `isInWebView`

`ref<boolean>` —— `true` 表示在 Flutter WebView 里运行，`false` 表示浏览器开发模式（mock 返回）。

---

## 二、注入数据 —— `useBRData()`

Flutter 在页面加载前注入 `window.__BR_Data__`，H5 无需 bridge 即可同步读取。

```ts
const { brData, isLoggedIn, userName, lang } = useBRData()

isLoggedIn()   // boolean — 是否有 accessToken + user
userName()     // string — user.name ?? user.id
lang()         // string — 默认 'zh'
brData.value   // 原始对象 { accessToken, user, lang, ... }
```

Flutter 侧注入内容由 `BRWebInitialData` 决定：
```dart
BRWebContainerPage(
  initialData: BRWebInitialData(
    accessToken: 'xxx',
    userData: { 'id': '1001', 'name': '李四' },
    lang: 'zh',
    extra: { 'appVersion': '1.0.0' },
  ),
)
```

---

## 三、生命周期 —— `useAppLifecycle()`

Flutter 侧通过 `_bridge.callWeb('app.lifecycle', ...)` 推送事件。

```ts
const { appState, pageVisible, label, history } = useAppLifecycle()

appState.value      // 'foreground' | 'background' | 'inactive' | 'hidden' | 'detached'
pageVisible.value   // boolean — 页面是否可见
label()             // string — "🟢 foreground · 可见"
history.value       // LifecycleEntry[]
```

典型用法：暂停/恢复视频、定时器。
```ts
watch(appState, (state) => {
  if (state === 'background') video.pause()
  if (state === 'foreground') video.play()
})
```

---

## 四、设备能力 API

所有 action 前缀 `device.`。

### 📷 拍照

| action | `device.camera.takePhoto` |
|--------|--------------------------|

| 参数 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `maxWidth` | `number` | - | 最大宽度 px |
| `maxHeight` | `number` | - | 最大高度 px |
| `maxSizeKB` | `number` | `1024` | 文件大小上限 KB（默认 1MB） |
| `saveToGallery` | `boolean` | `true` | 是否保存到系统相册 |

```ts
// 拍照 → 1MB 压缩 → 存相册
const r = await call('device.camera.takePhoto', { maxWidth: 1600, maxSizeKB: 1024 })
// 返回: { cancelled: false, path, size, sizeKB, savedToGallery, galleryPath }

// 拍照 → 500KB（需小图时）
await call('device.camera.takePhoto', { maxWidth: 800, maxSizeKB: 500 })
```

### 🖼️ 从相册选照片

| action | `device.camera.pickPhoto` |
|--------|--------------------------|

参数同上（无 `saveToGallery`，因已在相册）。

```ts
const r = await call('device.camera.pickPhoto', { maxWidth: 1600, maxSizeKB: 1024 })
// 返回: { cancelled: false, path, size, sizeKB }
```

### 🎥 录像

| action | `device.camera.takeVideo` |
|--------|--------------------------|

| 参数 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `maxDuration` | `number` | `30` | 最长录制秒数 |
| `camera` | `string` | `rear` | `'front'` / `'rear'` |
| `saveToGallery` | `boolean` | `true` | 是否存相册 |

```ts
// 后置录像 15s → 存相册
await call('device.camera.takeVideo', { maxDuration: 15, camera: 'rear', saveToGallery: true })

// 前置录像 10s → 不存相册（自拍发服务端）
await call('device.camera.takeVideo', { maxDuration: 10, camera: 'front', saveToGallery: false })

// 返回: { cancelled: false, path, mimeType, savedToGallery }
```

### 🎬 从相册选视频

| action | `device.camera.pickVideo` |
|--------|--------------------------|

| 参数 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `maxDuration` | `number` | `600` | 最长秒数 |

```ts
await call('device.camera.pickVideo', { maxDuration: 600 })
// 返回: { cancelled: false, path, name, mimeType }
```

### 🎙️ 录音

| action | `device.audio.startRecord` |
|--------|---------------------------|

无参数。

```ts
await call('device.audio.startRecord')
// 返回: { recording: true, path: '/documents/br_web_record_xxx.m4a' }
```

| action | `device.audio.stopRecord` |
|--------|--------------------------|

```ts
await call('device.audio.stopRecord')
// 返回: { recording: false, path }
```

### 📂 选择文件

| action | `device.file.pick` |
|--------|-------------------|

| 参数 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `multiple` | `boolean` | `false` | 多选 |

```ts
const r = await call('device.file.pick', { multiple: true })
// 返回: { cancelled: false, files: [{ name, path, size, extension }, ...] }
```

### 👁️ 预览文件

| action | `device.file.preview` |
|--------|----------------------|

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `path` | `string` | ✅ | 文件路径 |
| `type` | `string` | - | `image` / `video` / `audio`（不传自动推断） |
| `title` | `string` | - | 预览页标题 |
| `mimeType` | `string` | - | MIME 类型 |

```ts
await call('device.file.preview', {
  path: '/path/to/contract.pdf', type: 'image', title: '合同预览'
})
// 返回: { closed: true }  ← 用于判断用户是否已退出预览
```

### 🗑️ 删除文件

| action | `device.file.delete` |
|--------|---------------------|

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `path` | `string` | ✅ | 待删除文件绝对路径 |

```ts
// 上传成功后清理本地文件
const uploadRes = await uploadToServer(photoPath)
if (uploadRes.ok) {
  await call('device.file.delete', { path: photoPath })
}
// 返回: { deleted: true/false, path }
```

---

## 五、导航 & UI API

### ➡️ 跳转到指定路由（Flutter Navigator push）

| action | `navigation.navigateTo` |
|--------|------------------------|

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `route` | `string` | ✅ | 路由名（与 `BRWebNavigator.register()` 对应） |
| `params` | `object` | - | 传给目标页面的参数 |

```ts
await call('navigation.navigateTo', { route: '/h2' })
await call('navigation.navigateTo', { route: '/orderDetail', params: { orderId: '123' } })
// 返回: { success: true, route: '/h2' }
```

> ⚠️ 路由必须先在 Flutter 侧注册：`BRWebNavigator.register('/h2', BRWebRouteConfig(...))`

### ⬅️ 返回上一页

| action | `navigation.goBack` |
|--------|--------------------|

```ts
await call('navigation.goBack')
// 返回: { success: true }
```

### ✏️ 设置页面标题

| action | `navigation.setTitle` |
|--------|----------------------|

```ts
await call('navigation.setTitle', { title: '订单详情 #123' })
// 返回: { success: true, title: '订单详情 #123' }
```

---

## 六、UI 控制 API

### 隐藏/显示底部 TabBar

```ts
await call('ui.hideTabBar')    // 隐藏
await call('ui.showTabBar')    // 显示
// 返回: { success: true, action: 'hideTabBar' }
```

通常用于进入详情页时隐藏 TabBar，返回时显示：
```ts
onMounted(() => call('ui.hideTabBar'))
onUnmounted(() => call('ui.showTabBar'))
```

---

## 七、容器控制

### 🚪 关闭当前页面

```ts
await call('container.close', { reason: 'user_cancel' })
// 等于 Flutter 侧 Navigator.maybePop()
```

---

## 八、完整示例 —— Home.vue

```vue
<script setup lang="ts">
import { useBridge } from '../composables/useBridge'
import { useBRData } from '../composables/useBRData'
import { useAppLifecycle } from '../composables/useAppLifecycle'
import { ref, watch } from 'vue'

const { call, appendLog } = useBridge()
const { userName, isLoggedIn, lang } = useBRData()
const { appState, label: stateLabel } = useAppLifecycle()

const photo = ref<string | null>(null)

async function takePhoto() {
  const r: any = await call('device.camera.takePhoto', { maxWidth: 1600 })
  if (!r.cancelled && r.path) {
    photo.value = r.path
    appendLog(`照片 ${r.sizeKB}KB → ${r.path}`)
  }
}

async function pickPhoto() {
  const r: any = await call('device.camera.pickPhoto', { maxWidth: 1600, maxSizeKB: 500 })
  if (!r.cancelled && r.path) {
    photo.value = r.path
    appendLog(`选图 ${r.sizeKB}KB → ${r.path}`)
  }
}

async function goDetail() {
  await call('navigation.navigateTo', { route: '/h2' })
}

// 进页面隐藏 TabBar，离开恢复
call('ui.hideTabBar')
onUnmounted(() => call('ui.showTabBar'))
</script>

<template>
  <div class="home">
    <!-- 顶栏 -->
    <div class="bar">
      <span>{{ stateLabel() }}</span>
      <span v-if="isLoggedIn()">👤 {{ userName() }}</span>
    </div>

    <!-- 主体 -->
    <div class="body">
      <img v-if="photo" :src="'file://' + photo" class="photo" />
      <button @click="takePhoto">📷 拍照</button>
      <button @click="pickPhoto">🖼️ 相册选图</button>
      <button @click="goDetail">➡️ 详情页</button>
    </div>
  </div>
</template>

<style scoped>
.home { font-family: sans-serif; color: #333; background: #f5f5f5; min-height: 100vh; }
.bar { display: flex; justify-content: space-between; padding: 12px 16px; background: #fff; font-size: 13px; }
.body { padding: 16px; }
button { width: 100%; height: 48px; margin: 6px 0; border: 0; border-radius: 8px; color: #fff; background: #2563eb; font-size: 16px; }
.photo { width: 100%; border-radius: 8px; margin-bottom: 12px; }
</style>
```

---

## 九、压缩说明

所有图片操作（拍照 / 选照片）都有内置渐进压降策略：

| 参数 | 默认值 | 含义 |
|------|--------|------|
| `maxSizeKB` | `1024` | 文件上限 1MB。`0` = 不限制。 |
| `maxWidth` | 不传 | 最大宽度。传给 image_picker 控制分辨率。 |

压降过程：quality 85 → 60 → 40 → 20 → 10，直到满足 `maxSizeKB` 或到极限质量。

```ts
// 1MB 默认
call('device.camera.takePhoto', { maxWidth: 1600 })

// 500KB 严格限制
call('device.camera.pickPhoto', { maxWidth: 1200, maxSizeKB: 500 })

// 不压缩原图
call('device.camera.takePhoto', { maxSizeKB: 0 })
```

---

## 十、错误处理

```ts
const r: any = await call('device.camera.takePhoto', { maxWidth: 1600 })

if (r.cancelled) {
  return // 用户取消 或 权限拒绝
}

if (r.reason === 'permission_denied') {
  // 权限被拒绝（Flutter 侧已弹出设置引导弹窗）
  console.warn('用户拒绝了相机权限')
  return
}

// 正常使用
uploadToServer(r.path)
```
