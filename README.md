# fl_webbridge_tool

通用可扩展 Flutter WebBridge 插件 — Flutter 做壳 + H5 做业务，统一 Bridge 双向通信。

## 方案定位

- Flutter 负责：App 壳、导航、TabBar、登录态、权限、原生能力、日志、生命周期
- H5 负责：高频变化的页面业务
- `fl_webbridge_tool` 插件：暴露稳定 API，默认能力开箱可用，业务可按需扩展

## 标准插件结构

```text
fl_webbridge_tool/
  android/                      # Android 插件注册
  ios/                          # iOS 插件注册
  lib/                          # Dart API + BR_Web 容器实现
    src/
      br_web_bridge.dart             # 双向通信桥（统一消息模型）
      br_web_bridge_message.dart     # 消息模型（含 meta）
      br_web_capability_handler.dart # 能力处理器（30+ action）
      br_web_container_page.dart     # 容器页面（双模式：URL/离线文件）
      br_web_lifecycle.dart          # 生命周期枚举
      br_web_logger.dart             # 统一日志器 + bridgeError 栈追踪
      br_web_global_log.dart         # 全局单例日志（maxCapacity=2000）
      br_web_log_widgets.dart        # 内置日志 UI（过滤/搜索/颜色编码）
      br_web_network_monitor.dart    # 网络状态监听（checkNow 实时查询）
      br_web_system_info.dart        # 设备/系统信息
      br_web_resource_manager.dart   # 离线资源包管理（去重+排序）
      br_web_database_manager.dart   # 通用数据库 CRUD + 工单模型
      br_web_preview_page.dart       # 文件预览（单文件 + PageView 多文件）
      br_web_permission_helper.dart  # 统一权限申请（三级弹窗）
      br_web_navigator.dart          # 路由注册 + 跳转
      br_web_dev_guard.dart          # 开发期合约检查
      br_web_initial_data.dart       # 通用数据注入（TS 类型完备）
  example/                      # 宿主 App，演示接入
    vuedemo/                        # Vue3 业务 Demo
      packages/br-web-bridge-vue/   # NPM 包（本地 link）
  docs/                         # 方案文档 + 集成手册 + 架构图
  pubspec.yaml
```

## 完整能力矩阵

### 设备能力（DefaultBRWebCapabilityHandler）

| Action | 说明 | 权限 | 关键参数 |
|--------|------|------|---------|
| `device.camera.takePhoto` | 拍照 + 自动压缩 + 默认存相册 | `CAMERA` | `quality`, `maxWidth`(默认1600), `saveToGallery` |
| `device.camera.pickPhoto` | 从相册选照片 | `PHOTOS` | `quality`, `maxWidth` |
| `device.camera.pickMultiPhoto` | **多选照片** | `PHOTOS` | `quality`, `maxWidth` → `{files: [...]}` |
| `device.camera.takeVideo` | 录像 + 默认存相册 | `CAMERA` + `MIC` | `maxDuration`(秒), `camera`, `saveToGallery` |
| `device.camera.pickVideo` | 从相册选视频 | `PHOTOS` | `maxDuration`(秒,默认600) |
| `device.file.pick` | 文件选择（单/多） | - | `multiple` → `{files: [{name,path,size}]}` |
| `device.file.preview` | 预览单个文件（全屏图/视频/音频） | - | `path`, `type`, `title`, `mimeType`, `size` |
| `device.file.previewMulti` | **多文件翻页预览**（PageView 滑动） | - | `files: [{path, type, title}]`, `index` |
| `device.file.readAsDataUrl` | 读取文件为 base64 data URL | - | `path` → `{dataUrl}` |
| `device.file.delete` | 删除本地文件 | - | `path` |
| `device.audio.startRecord` | 开始录音（AAC/m4a） | `MIC` | - |
| `device.audio.stopRecord` | 停止录音（返回 mimeType/name/size） | - | → `{path, name, mimeType, size}` |
| `device.network.status` | 实时查询网络（checkNow 非缓存） | - | → `{status: wifi/mobile/offline}` |
| `device.system.info` | 查询设备/系统信息 | - | → `{deviceModel, os, osVersion, appVersion}` |

### 导航 & UI

| Action | 说明 |
|--------|------|
| `navigation.navigateTo` | 跳转到已注册路由（支持传参） |
| `navigation.goBack` | 返回上一页 |
| `navigation.setTitle` | H5 端修改 Native AppBar 标题 |
| `ui.hideTabBar` | 隐藏底部 TabBar |
| `ui.showTabBar` | 显示底部 TabBar |
| `container.close` | 关闭当前容器 |

### 离线资源包（BRWebResourceManager）

| Action | 说明 |
|--------|------|
| `resource.getStatus` | → `{currentVersion, downloading, installedVersions, needUpdate}` |
| `resource.checkUpdate` | → `{hasUpdate, latestVersion, releaseNotes}` |
| `resource.startUpdate` | 开始下载 → `{ok, version}` |
| `resource.cancelUpdate` | 取消下载 |
| `resource.switchTo` | 切换版本 `{version: "1.0.0"}` |

> 安装版本自动按路径去重 + 排序。

### 数据库——工单 CRUD（NativeDataBaseManager\\<T\\>）

| Action | 说明 |
|--------|------|
| `database.workOrder.query` | `{where, whereArgs, limit}` → `{rows: [...]}` |
| `database.workOrder.getById` | `{id}` → `{row: {...}}` |
| `database.workOrder.insert` | `{title, description, ...}` → `{id}` |
| `database.workOrder.update` | `{id, title, ...}` → `{id}` |
| `database.workOrder.delete` | `{id}` → `{id}` |

> 通用泛型 `NativeDataBaseManager<T>` 可扩展任意 table。错误走 throw → `{ok:false, error}`。

### 数据注入（BRWebInitialData）

H5 无需 bridge 调用，同步读取 `window.__BR_Data__`：

```dart
BRWebContainerPage(
  initialData: BRWebInitialData(
    accessToken: 'xxx',
    userData: {'id': '1001', 'name': '张三'},
    lang: 'zh',
    extra: {'appVersion': '1.2.3', 'resourceVersion': '2.0.1'},
  ),
)
```

```ts
// H5 TypeScript 类型安全
import { getBRData } from 'br-web-bridge-vue'
const { accessToken, user, lang, appVersion, extra } = getBRData()
// 类型：BRWebInitialData { accessToken?, user?, lang?, appVersion?, resourceVersion?, extra? }
```

### 全链路日志

| 组件 | 说明 |
|------|------|
| `BRWebLogger` | 接口：request/response/lifecycle/console/error/bridgeError/ui/native |
| `CallbackBRWebLogger` | 回调实现，所有事件通过 `onLog` 统一输出 |
| `BRWebGlobalLog` | 全局单例，任意位置写入/订阅，`maxCapacity=2000` OOM 防护 |
| `BRWebGlobalLogPage` | 内置日志页：过滤 + 搜索 + 颜色编码 + 清空 + 可选中复制 |
| `BRWebLoggableBottomBar` | 切 Tab 自动写全局日志的 NavigationBar |

日志标签：`📡` lifecycle / `⬆️` REQ / `⬇️` RES / `📜` console / `💥` JS错误 / `🔌` bridge异常 / `🎨` UI / `🦴` native

**Bridge 异常自动栈追踪**：错误发生时自动捕获 StackTrace，优先显示 `br_web_*.dart` 相关定位行。

### 权限体系（BRWebPermissionHelper）

1. 已授予 → ✅ 直接通过
2. 普通拒绝 → 弹出说明弹窗 → 重试
3. 永久拒绝 → 弹出引导弹窗 → 跳转系统设置

### 开发期合约检查（BRWebDevGuard）

```dart
BRWebContainerPage(
  capabilityHandler: BRWebDevGuard(
    inner: _handler, logger: _logger,
    expectedUiActions: ['hideTabBar', 'showTabBar'],
  ),
)
```

- Debug 模式下自动检测回调绑定完整性
- H5 调了 UI action 但 Native 没绑回调 → ⚠️ 警告

### 网络 & 系统信息

- `BRWebNetworkMonitor` — 自动监听 WiFi/移动网络/离线变化，实时 `checkNow()` 查询
- `BRWebSystemInfo` — 设备型号/系统版本/App版本一键 `collect()`

### Vue3 画廊 <span style="font-size:14px;color:#667085">v0.3</span>

Vue Demo 内置文件画廊：选文件自动收集 → 网格缩略图 → 点击全屏查看器：

- 图片：dataUrl 全屏 + 左右滑动 ◀ ▶
- 视频/音频：图标 + 文件名 + "用原生预览打开" 按钮
- 支持清空 / 逐条删除

## Bridge 协议

**统一消息模型**（双向一致）：`{id, action, params, meta?}` → `{id, ok, data/error}`

```js
// H5 → Native（brCall 自动注入 meta）
window.flutter_inappwebview.callHandler('BR_WebNativeBridge', {
  id: 'request_id',
  action: 'device.camera.takePhoto',
  params: { quality: 80 },
  meta: { h5Version: '2.0.1', platform: 'ios' }  // 自动
})
```

```json
// Native 响应（统一格式）
{ "id": "...", "ok": true, "data": { "path": "/tmp/photo.jpg" } }
{ "id": "...", "ok": false, "error": "Bad state: db not configured" }
```

```dart
// Native → H5（同格式）
BRWebBridge.callWeb('container.lifecycle', { type: 'loadStop', url: '...' });
// H5 onNativeCall 接收 {id, action, params}，可回传 {id, ok, data}
```

```ts
// H5 自定义 meta 扩展
import { setBridgeMeta } from 'br-web-bridge-vue'
setBridgeMeta({ userId: '1001', role: 'admin' })
// 后续所有 brCall 自动带 { ..., meta: { userId, role } }
```

## 快速接入

```yaml
dependencies:
  fl_webbridge_tool:
    git:
      url: ssh://your-git/fl_webbridge_tool.git
      ref: v0.3.0
```

```dart
BRWebContainerPage(
  title: '业务页面',
  initialUrl: 'https://your-domain.example/page',
  capabilityHandler: CompositeBRWebCapabilityHandler([
    MyCustomHandler(),
    DefaultBRWebCapabilityHandler(),
  ]),
  logger: myLogger,
  initialData: BRWebInitialData(accessToken: token),
)
```

离线模式：`BRWebContainerPage(initialFile: 'assets/h5/demo.html')`

## 扩展原生能力

```dart
class MyHandler implements BRWebCapabilityHandler {
  Future<Object?> handle(BuildContext c, BRWebBridgeMessage msg) => switch (msg.action) {
    'user.getToken' => {'token': 'xxx'},
    _ => Future.value(BRWebCapabilityHandlerResult.notHandled),
  };
}
```

## 平台权限配置

### Android
```xml
INTERNET, CAMERA, RECORD_AUDIO,
READ_MEDIA_IMAGES, READ_MEDIA_VIDEO, READ_MEDIA_AUDIO,
READ_EXTERNAL_STORAGE(maxSdkVersion=32),
WRITE_EXTERNAL_STORAGE(maxSdkVersion=28)
```

### iOS
```plist
NSCameraUsageDescription
NSMicrophoneUsageDescription
NSPhotoLibraryUsageDescription
NSPhotoLibraryAddUsageDescription
```

## 构建 & 运行

```sh
# Vue3 离线包（单文件，推荐）
cd example && bash build_vue_inline.sh

# Vue3 Dev Server（热重载）
cd example/vuedemo && npm install && npm run dev

# 运行
cd example && flutter run
```

## 性能 & 稳定性

| 原则 | 说明 |
|------|------|
| `IndexedStack` 保活 | Tab 容器不销毁 WebView |
| 传 path 不传 base64 | 大文件走文件路径 |
| 权限按需申请 | 不一次性索取 |
| 🔒 安全 setState | `_safeSetState()` 检测 schedulerPhase |
| 🧹 OOM 防护 | `BRWebGlobalLog.maxCapacity=2000` · 示例 `_logs` 限制 200 条 |
| 📦 资源去重 | `_loadManifest` 按路径去重 + 自动排序 |
| ⚠️ handler 注入 | 每个 BRWebContainerPage 必须传入 capabilityHandler |
| 🚪 日志弹窗 | LogPage 长日志 maxLines:3 + 点击弹出详情对话框 |
