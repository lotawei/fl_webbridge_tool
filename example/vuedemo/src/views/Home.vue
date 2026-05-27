<script setup lang="ts">
import { useBridge } from '../composables/useBridge'
import { useBRData } from '../composables/useBRData'
import { useAppLifecycle } from '../composables/useAppLifecycle'

const { call, appendLog } = useBridge()
const { isLoggedIn, userName, lang } = useBRData()
const { label: stateLabel } = useAppLifecycle()

// ====== 拍照（默认 ≤1MB）======
async function takePhoto() {
  appendLog(await call('device.camera.takePhoto', {
    maxWidth: 1600,
    maxHeight: 2400,
    maxSizeKB: 1024,
    saveToGallery: true,
  }))
}

// ====== 录像 ======
async function takeVideo(save: boolean) {
  appendLog(await call('device.camera.takeVideo', {
    maxDuration: 15,
    camera: 'rear',
    saveToGallery: save,
  }))
}

// ====== 录音 ======
async function startRecord() {
  appendLog(await call('device.audio.startRecord'))
}
async function stopRecord() {
  appendLog(await call('device.audio.stopRecord'))
}

// ====== 文件操作 ======
async function pickFile() {
  appendLog(await call('device.file.pick', { multiple: true }))
}
async function previewFile() {
  const type = prompt('预览类型: image / video / audio', 'image')
  const path = prompt('文件路径', type === 'image' ? '/path/to/photo.jpg' : '/path/to/file.mp4')
  if (!path) return
  appendLog(await call('device.file.preview', { path, type, title: '预览' }))
}
async function deleteFile() {
  const path = prompt('待删除文件路径')
  if (!path) return
  appendLog(await call('device.file.delete', { path }))
}
</script>

<template>
  <div class="home">
    <!-- ═══ 设备能力 ═══ -->
    <h2>📷 设备能力</h2>
    <button @click="takePhoto">📷 拍照 → 相册</button>
    <button @click="takeVideo(true)">🎥 录像 → 相册</button>
    <button @click="takeVideo(false)">🎥 录像（不入相册）</button>
    <button @click="startRecord">🎙️ 开始录音</button>
    <button @click="stopRecord">⏹️ 停止录音</button>
    <button @click="pickFile">📂 选择文件</button>
    <button @click="previewFile">👁️ 预览文件</button>
    <button @click="deleteFile">🗑️ 删除文件</button>

    <pre class="log"><div v-for="(l, i) in logs" :key="i">{{ l.time }}  {{ l.text }}</div></pre>

    <hr />

    <!-- ═══ API 文档 ═══ -->
    <h2>📖 Bridge API 参考</h2>
    <p class="doc-desc">所有接口通过 <code>call(action, params)</code> 调用，返回值通过 <code>appendLog</code> 展示。</p>

    <!-- 设备 -->
    <h3>📷 设备能力</h3>
    <div class="api">
      <h4><code>device.camera.takePhoto</code> 拍照</h4>
      <table>
        <tr><th>参数</th><th>类型</th><th>默认</th><th>说明</th></tr>
        <tr><td>maxWidth</td><td>number</td><td>—</td><td>最大宽度 px</td></tr>
        <tr><td>maxHeight</td><td>number</td><td>—</td><td>最大高度 px</td></tr>
        <tr><td>maxSizeKB</td><td>number</td><td>1024</td><td>文件大小上限 KB（≤1MB）</td></tr>
        <tr><td>saveToGallery</td><td>boolean</td><td>true</td><td>是否存入系统相册</td></tr>
      </table>
      <p class="example">H5: <code>call('device.camera.takePhoto', { maxWidth: 1600, maxSizeKB: 1024 })</code></p>
      <p class="returns">返回: <code>{ cancelled, path, name, mimeType, size, sizeKB, savedToGallery, galleryPath }</code></p>

      <h4><code>device.camera.pickPhoto</code> 从相册选照片</h4>
      <table>
        <tr><th>参数</th><th>类型</th><th>默认</th><th>说明</th></tr>
        <tr><td>maxWidth</td><td>number</td><td>—</td><td>最大宽度 px</td></tr>
        <tr><td>maxHeight</td><td>number</td><td>—</td><td>最大高度 px</td></tr>
        <tr><td>maxSizeKB</td><td>number</td><td>1024</td><td>文件大小上限 KB（≤1MB）</td></tr>
      </table>
      <p class="example">H5: <code>call('device.camera.pickPhoto', { maxSizeKB: 500 })</code></p>
      <p class="returns">返回: <code>{ cancelled, path, name, mimeType, size, sizeKB }</code></p>

      <h4><code>device.camera.takeVideo</code> 录像</h4>
      <table>
        <tr><th>参数</th><th>类型</th><th>默认</th><th>说明</th></tr>
        <tr><td>maxDuration</td><td>number</td><td>30</td><td>最长录制秒数</td></tr>
        <tr><td>camera</td><td>string</td><td>'rear'</td><td>'front' | 'rear'</td></tr>
        <tr><td>saveToGallery</td><td>boolean</td><td>true</td><td>是否存入系统相册</td></tr>
      </table>
      <p class="returns">返回: <code>{ cancelled, path, name, mimeType, savedToGallery, galleryPath }</code></p>

      <h4><code>device.camera.pickVideo</code> 从相册选视频</h4>
      <table>
        <tr><th>参数</th><th>类型</th><th>默认</th><th>说明</th></tr>
        <tr><td>maxDuration</td><td>number</td><td>600</td><td>最大时长秒数</td></tr>
      </table>
      <p class="returns">返回: <code>{ cancelled, path, name, mimeType }</code></p>

      <h4><code>device.audio.startRecord</code> / <code>device.audio.stopRecord</code> 录音</h4>
      <table>
        <tr><th>参数</th><th>类型</th><th>默认</th><th>说明</th></tr>
        <tr><td>—</td><td>—</td><td>—</td><td>无参数，文件存入 documents 目录</td></tr>
      </table>
      <p class="example">H5: <code>call('device.audio.startRecord')</code> → <code>call('device.audio.stopRecord')</code></p>
      <p class="returns">开始: <code>{ recording: true, path }</code> · 停止: <code>{ recording: false, path }</code></p>

      <h4><code>device.file.pick</code> 选择文件</h4>
      <table>
        <tr><th>参数</th><th>类型</th><th>默认</th><th>说明</th></tr>
        <tr><td>multiple</td><td>boolean</td><td>false</td><td>是否允许多选</td></tr>
      </table>
      <p class="returns">返回: <code>{ cancelled, files: [{ name, path, size, extension }] }</code></p>

      <h4><code>device.file.preview</code> 预览文件</h4>
      <table>
        <tr><th>参数</th><th>类型</th><th>默认</th><th>说明</th></tr>
        <tr><td>path</td><td>string</td><td>必填</td><td>本地文件绝对路径</td></tr>
        <tr><td>type</td><td>string</td><td>—</td><td>'image' / 'video' / 'audio'，不填自动推断</td></tr>
        <tr><td>title</td><td>string</td><td>—</td><td>预览页标题</td></tr>
      </table>
      <p class="returns">返回: <code>{ closed: true }</code></p>

      <h4><code>device.file.delete</code> 删除本地文件</h4>
      <table>
        <tr><th>参数</th><th>类型</th><th>默认</th><th>说明</th></tr>
        <tr><td>path</td><td>string</td><td>必填</td><td>本地文件绝对路径</td></tr>
      </table>
      <p class="returns">返回: <code>{ deleted: boolean, path, reason? }</code></p>
    </div>

    <!-- 导航 -->
    <h3>🧭 导航 & UI</h3>
    <div class="api">
      <h4><code>navigation.navigateTo</code> 跳转页面</h4>
      <table>
        <tr><th>参数</th><th>类型</th><th>默认</th><th>说明</th></tr>
        <tr><td>route</td><td>string</td><td>必填</td><td>路由名，需 Native 侧 BRWebNavigator.register() 注册</td></tr>
        <tr><td>params</td><td>object</td><td>{}</td><td>传给目标页面的参数</td></tr>
      </table>
      <p class="example">H5: <code>call('navigation.navigateTo', { route: '/h2', params: { id: 42 } })</code></p>

      <h4><code>navigation.goBack</code> 返回上一页</h4>
      <p class="returns">返回: <code>{ success: true }</code></p>

      <h4><code>navigation.setTitle</code> 设置页面标题</h4>
      <table>
        <tr><th>参数</th><th>类型</th><th>默认</th><th>说明</th></tr>
        <tr><td>title</td><td>string</td><td>必填</td><td>新标题文本</td></tr>
      </table>
      <p class="returns">返回: <code>{ success: true, title }</code></p>

      <h4><code>ui.hideTabBar</code> / <code>ui.showTabBar</code> 控制底部 TabBar</h4>
      <p class="returns">返回: <code>{ success: true, action: 'hideTabBar' | 'showTabBar' }</code></p>
    </div>

    <!-- 容器 -->
    <h3>📦 容器</h3>
    <div class="api">
      <h4><code>container.close</code> 关闭当前 WebView 页面</h4>
      <table>
        <tr><th>参数</th><th>类型</th><th>默认</th><th>说明</th></tr>
        <tr><td>reason</td><td>string</td><td>—</td><td>关闭原因（日志用）</td></tr>
      </table>
      <p class="returns">返回: <code>{ closing: true }</code></p>
    </div>

    <!-- Composables -->
    <h3>🔧 H5 Composables</h3>
    <div class="api">
      <h4><code>useBridge()</code> Bridge 通信封装</h4>
      <table>
        <tr><th>导出</th><th>类型</th><th>说明</th></tr>
        <tr><td>call(action, params)</td><td><code>(string, object?) => Promise&lt;object&gt;</code></td><td>调用 Native 能力</td></tr>
        <tr><td>appendLog(value)</td><td><code>(unknown) => void</code></td><td>追加日志到 logs[]</td></tr>
        <tr><td>logs</td><td><code>Ref&lt;LogEntry[]&gt;</code></td><td>响应式日志列表</td></tr>
        <tr><td>bridgeReady</td><td><code>Ref&lt;boolean&gt;</code></td><td>bridge 是否就绪</td></tr>
        <tr><td>isInWebView</td><td><code>Ref&lt;boolean&gt;</code></td><td>是否在 WebView 中运行</td></tr>
      </table>

      <h4><code>useBRData()</code> 注入数据读取</h4>
      <table>
        <tr><th>导出</th><th>类型</th><th>说明</th></tr>
        <tr><td>brData</td><td><code>DeepReadonly&lt;Ref&lt;BRData&gt;&gt;</code></td><td>window.__BR_Data__ 响应式副本</td></tr>
        <tr><td>isLoggedIn()</td><td><code>() => boolean</code></td><td>是否已登录</td></tr>
        <tr><td>userName()</td><td><code>() => string</code></td><td>用户姓名/id</td></tr>
        <tr><td>lang()</td><td><code>() => string</code></td><td>当前语言</td></tr>
      </table>

      <h4><code>useAppLifecycle()</code> App 生命周期</h4>
      <table>
        <tr><th>导出</th><th>类型</th><th>说明</th></tr>
        <tr><td>appState</td><td><code>DeepReadonly&lt;Ref&lt;AppLifecycleState&gt;&gt;</code></td><td>foreground / background / inactive / hidden</td></tr>
        <tr><td>pageVisible</td><td><code>DeepReadonly&lt;Ref&lt;boolean&gt;&gt;</code></td><td>当前页面是否可见</td></tr>
        <tr><td>label()</td><td><code>() => string</code></td><td>🟢 foreground · 可见</td></tr>
      </table>
    </div>
  </div>
</template>

<style scoped>
* { box-sizing: border-box; }
.home {
  font-family: -apple-system, sans-serif;
  color: #172033;
  background: #f7f8fb;
  min-height: 100vh;
  padding: 16px;
  padding-bottom: 80px;
}
h2 { margin: 24px 0 12px; font-size: 20px; }
h3 { margin: 20px 0 8px; font-size: 17px; color: #2563eb; }
h4 { margin: 14px 0 4px; font-size: 14px; }
h4 code { background: #e8ecf4; padding: 1px 6px; border-radius: 3px; font-size: 13px; }
button {
  width: 100%;
  height: 46px;
  margin: 7px 0;
  border: 0;
  border-radius: 8px;
  color: white;
  background: #2563eb;
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
}
button:active { opacity: 0.85; }
pre.log {
  margin-top: 14px;
  padding: 12px;
  min-height: 120px;
  max-height: 300px;
  overflow: auto;
  border: 1px solid #e7e9ef;
  border-radius: 8px;
  background: #ffffff;
  white-space: pre-wrap;
  word-break: break-word;
  font-size: 12px;
  line-height: 1.6;
}
hr { margin: 24px 0; border: none; border-top: 1px solid #e7e9ef; }

/* ═══ 文档样式 ═══ */
.api table {
  width: 100%;
  border-collapse: collapse;
  font-size: 12px;
  margin: 6px 0 10px;
}
.api th, .api td {
  border: 1px solid #e7e9ef;
  padding: 5px 8px;
  text-align: left;
}
.api th { background: #eef2ff; font-weight: 600; }
.api td { background: #fff; }
.doc-desc { font-size: 13px; color: #667085; margin-bottom: 8px; }
.doc-desc code { background: #e8ecf4; padding: 1px 4px; border-radius: 3px; }
.example { font-size: 12px; color: #374151; margin: 4px 0 2px; background: #f0fdf4; padding: 4px 8px; border-radius: 4px; }
.example code { color: #166534; }
.returns { font-size: 12px; color: #6b7280; margin: 2px 0 8px; }
.returns code { background: #f3f4f6; padding: 1px 4px; border-radius: 3px; }
</style>
