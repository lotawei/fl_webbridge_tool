# 通用 BR_Web 容器化方案

## 分层设计

```
┌─────────────────────────────────────────────────┐
│  1. App Shell (Flutter)                          │
│     TabBar / 路由 / 登录态 / 主题 / APM            │
├─────────────────────────────────────────────────┤
│  2. fl_webbridge_tool (可复用插件 SDK)              │
│     BRWebContainerPage / BRWebBridge / Logger     │
├─────────────────────────────────────────────────┤
│  3. Capability Handlers (能力插件点)               │
│     DefaultBRWebCapabilityHandler (30+ action)    │
│     CompositeBRWebCapabilityHandler (链式组合)     │
│     BRWebDevGuard (开发期合约检查)                  │
├─────────────────────────────────────────────────┤
│  4. BR_Web Bridge (双向通信桥)                     │
│     H5 ↔ JSON ↔ WebView IPC ↔ Dart 分发            │
├─────────────────────────────────────────────────┤
│  5. BR_Web Bridge Vue (NPM 包)                    │
│     Vue3 composable + TypeScript 类型              │
├─────────────────────────────────────────────────┤
│  6. Observability (全链路可观测)                    │
│     生命周期 / Bridge API / Console / 网络 / 系统    │
└─────────────────────────────────────────────────┘
```

## 完整能力矩阵

### 设备能力（DefaultBRWebCapabilityHandler）

| Action | 说明 | 权限 | 关键参数 |
|--------|------|------|---------|
| `device.camera.takePhoto` | 拍照 + 自动压缩 + 默认存相册 | `CAMERA` | `maxSizeKB`(默认1024), `maxWidth`(默认1600), `maxHeight`, `saveToGallery`(默认true) |
| `device.camera.pickPhoto` | 从相册选照片 + 自动压缩 | `PHOTOS` | `maxSizeKB`(默认1024) |
| `device.camera.pickMultiPhoto` | **多选照片** | `PHOTOS` | `quality`, `maxWidth` → `{files: [{path, name, mimeType, size}]}` |
| `device.camera.takeVideo` | 录像 + 默认存相册 | `CAMERA` + `MICROPHONE` | `maxDuration`(秒,默认30), `camera`(front/rear), `saveToGallery` |
| `device.camera.pickVideo` | 从相册选视频 | `PHOTOS` | `maxDuration`(秒,默认600) |
| `device.file.pick` | 文件选择（单/多） | - | `multiple` |
| `device.file.preview` | 全屏预览（图/视频/音频） | - | `path`, `type`(image/video/audio), `title`, `mimeType`, `size` |
| `device.file.delete` | 删除本地文件 | - | `path` |
| `device.audio.startRecord` | 开始录音（AAC/m4a） | `MICROPHONE` | - |
| `device.audio.stopRecord` | 停止录音，返回路径 | - | - |
| `device.network.status` | 实时查询网络状态 | - | 返回 `{status: wifi/mobile/offline/ethernet}` |
| `device.system.info` | 查询设备/系统/App信息 | - | `deviceModel`, `os`, `osVersion`, `appVersion` |

### 导航 & UI

| Action | 说明 |
|--------|------|
| `navigation.navigateTo` | 跳转到已注册路由（支持传参） |
| `navigation.goBack` | 返回上一页 |
| `navigation.setTitle` | H5 端修改 Native AppBar 标题 |
| `ui.hideTabBar` | 隐藏底部 TabBar |
| `ui.showTabBar` | 显示底部 TabBar |
| `container.close` | 关闭当前 WebView 容器 |

### 离线资源包（BRWebResourceManager）

| Action | 说明 |
|--------|------|
| `resource.getStatus` | 返回 `{currentVersion, downloading, progress, installedVersions, latestVersion, needUpdate}` |
| `resource.checkUpdate` | Mock 服务端检查，返回 `{hasUpdate, latestVersion, forceUpdate, releaseNotes}` |
| `resource.startUpdate` | 开始下载（Mock 进度模拟），完成后自动切换到新版本 |
| `resource.cancelUpdate` | 取消下载 |
| `resource.switchTo` | 切换到已安装的指定版本 `{version: "1.0.0"}` |

### 数据库——工单 CRUD（NativeDataBaseManager\<WorkOrder\>）

| Action | 说明 |
|--------|------|
| `database.workOrder.query` | 查询：`{where, whereArgs, limit}` → `{rows: [...]}` |
| `database.workOrder.getById` | 按 ID 查：`{id}` → `{row: {...}}` |
| `database.workOrder.insert` | 新增：`{title, description, status, priority, assignee, address}` → `{id}` |
| `database.workOrder.update` | 更新：`{id, title, ...}` → `{id}` |
| `database.workOrder.delete` | 删除：`{id}` → `{id}` |

> 通用泛型 `NativeDataBaseManager<T>` 可扩展任意 table。错误通过 `throw StateError` 走 bridge `{ok:false, error:...}` 通道。

### 数据注入（BRWebInitialData）

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

注入方式：`UserScript AT_DOCUMENT_START` → H5 直接读 `window.__BR_Data__`

### 全链路日志

| 组件 | 说明 |
|------|------|
| `BRWebLogger` | 接口：8 种日志类型（request/response/lifecycle/console/error/bridgeError/ui/native） |
| `CallbackBRWebLogger` | 回调实现，所有事件通过 `onLog: (BRWebLogEntry) {}` 统一输出 |
| `DebugBRWebLogger` | 打印到 `print()`，开发调试用 |
| `BRWebGlobalLog` | **全局单例**，任意位置写入/订阅，支持路由追踪 `routePush/routePop/tabSwitch` |
| `BRWebGlobalLogPage` | **内置工业级日志页**：终端风格 + 颜色编码 + 类型过滤 + 搜索 + 清空 + 可选中复制 |
| `BRWebLoggableBottomBar` | 切 Tab 自动写全局日志的 `NavigationBar` 替代品 |

日志标签：`📡` lifecycle / `⬆️` REQ / `⬇️` RES / `📜` console / `💥` JS错误 / `🔌` bridge异常 / `🎨` UI / `🦴` native

**Bridge 异常自动栈追踪**：
```
15:18:00 🔌 [resource.checkUpdate] Bad state: no resourceManager
         ← br_web_capability_handler.dart:191
         ← br_web_bridge.dart:37
```

### 权限体系（BRWebPermissionHelper）

三级处理：

| 状态 | 行为 |
|------|------|
| 已授予 | ✅ 直接通过 |
| 普通拒绝 | 弹出说明弹窗 → 用户点击"去授权" → 系统弹窗重试 |
| 永久拒绝 | 弹出引导弹窗 → 点击"去设置" → 跳转系统设置页 |

### 开发期合约检查（BRWebDevGuard）

```dart
BRWebContainerPage(
  capabilityHandler: BRWebDevGuard(
    inner: _handler,
    logger: _logger,
    expectedUiActions: ['hideTabBar', 'showTabBar'],
    expectedTitleHandler: true,
  ),
)
```

- Debug 模式下自动拦截 action，检查 `onUiRequest`/`onSetTitle` 是否绑定
- H5 调了未绑定的 action → 立即打印 `⚠️ BR_WEB_DEVMODE` 警告
- 启动时 `runStartupChecks()` 全量扫描

### 文件预览（BRWebPreviewPage / BRWebPreviewMultiPage）

| 类型 | 组件 | 特性 |
|------|------|------|
| 图片 | `InteractiveViewer` | 双指缩放 1x~5x，jpg/png/gif/webp/heic |
| 视频 | `VideoPlayer` | 播放/暂停/拖动进度条/重播 |
| 音频 | `AudioPlayer` | 圆盘播放器，进度条可拖拽 |
| 多文件 | `BRWebPreviewMultiPage` | PageView 左右滑动，标题栏 "文件名 (2/5)" |
| 未知 | 友好提示 | "不支持预览此文件类型" |

支持扩展名自动推断 >30 种文件类型。

> Bridge action `device.file.previewMulti` 接收 `{files: [{path, type, title}], index}`，`device.audio.stopRecord` 返回结构已统一（含 mimeType/name/size）。

### 网络 & 系统信息

| 组件 | 说明 |
|------|------|
| `BRWebNetworkMonitor` | `connectivity_plus` 监听，start/stop/checkNow，自动通知 lifecycle |
| `BRWebSystemInfo` | `device_info_plus` + `package_info_plus`，一键 `collect()` |

## 通信协议

**统一消息模型**（H5 ↔ Native 双向一致，唯一格式）：

```
请求消息:
{
  "id": "req_001",            // 唯一请求 ID（自动生成）
  "action": "device.camera.takePhoto",
  "params": { quality: 80 },
  "meta": {                    // 元信息（H5 自动注入，Native 可选）
    "h5Version": "2.0.1",
    "h5Branch": "master",
    "platform": "ios",
    "appVersion": "1.0.0",
    "lang": "zh"
  }
}

响应消息:
// 成功
{ "id": "req_001", "ok": true, "data": { "path": "/tmp/photo.jpg" } }

// 失败
{ "id": "req_001", "ok": false, "error": "Bad state: db not configured" }
```

| 方向 | 传输方式 | 格式 |
|------|---------|------|
| H5 → Native | `callHandler('BR_WebNativeBridge', msg)` | `{id, action, params, meta}` |
| Native → H5 | `BRWebBridge.callWeb(action, params)` | `{id, action, params}` |
| H5 响应 Native | `onNativeCall` 回调返回值 | `{id, ok, data/error}` |
| Native 响应 H5 | handler 返回值 / throw | `{id, ok, data/error}` |

> H5 端 `setBridgeMeta({...})` 可追加自定义 meta（如 userId/role），后续所有请求自动携带。
> 错误统一走 `throw` → bridge catch → `{ok: false, error: ...}`，**不在 data 中嵌套 error**。

## Bridge 数据流

```
           callHandler({id,action,params,meta})
  ┌──────┐ ────────────────────────────▶ ┌──────┐
  │  H5  │                                │Dart  │
  │ Vue3 │ ◀──────────────────────────── │      │
  └──────┘   return {id,ok,data/error}    └──────┘
       ▲                                    │
       │  onNativeCall({id,action,params})  │
       │  return {id,ok,data}               │
       └────────────────────────────────────┘
              evaluateJavascript
              (BRWebBridge.callWeb)
```

## 权限配置

### Android `AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28"/>
```

### iOS `Info.plist`
```xml
<key>NSCameraUsageDescription</key>   <string>需要相机权限用于拍照和录像</string>
<key>NSMicrophoneUsageDescription</key> <string>需要麦克风权限用于录音</string>
<key>NSPhotoLibraryUsageDescription</key> <string>需要相册权限用于选择照片</string>
<key>NSPhotoLibraryAddUsageDescription</key> <string>需要保存照片到相册</string>
```

## 性能和稳定性

| 原则 | 说明 |
|------|------|
| `IndexedStack` 保活 | Tab 容器不销毁 WebView，避免白屏重建 |
| 传 path 不传 base64 | 大文件走文件路径，不占 JSON 带宽 |
| 权限按需申请 | 不在容器初始化时一次性索取所有权限 |
| SPA history 监听 | 不只依赖 `onLoadStop`，监听 `onUpdateVisitedHistory` |
| 日志采样 | 避免 console 和 bridge 高频刷屏 |
| ⚠️ handler 注入 | 每个 `BRWebContainerPage` 必须传入 `capabilityHandler`，否则默认新实例无 manager |
| 🧹 日志 OOM 防护 | `BRWebGlobalLog.maxCapacity = 2000`，超出自动 removeAt(0)；示例 `_logs` 限制 200 条 |
| 🔒 安全 setState | `_safeSetState()` 检测 `schedulerPhase`，build 阶段自动推迟到 `addPostFrameCallback` |
| 📦 资源去重 | `installedVersions` 自动排序；`_loadManifest` 按路径去重 |

## 构建方式

| 方式 | 命令 | 适用场景 |
|------|------|---------|
| 内联构建（推荐） | `cd example && bash build_vue_inline.sh` | 离线包，单文件加载，无 file:// 限制 |
| 标准构建 | `cd example/vuedemo && npm run build` | 多文件输出 |
| Dev Server | `cd example/vuedemo && npm run dev` | 开发热重载 |

## 后续增强路线

- [x] 资源包版本管理 + 增量更新（Mock 流程已就绪）
- [x] 数据库 CRUD 通用框架 + 工单示例         
- [x] 全局日志集线器 + 工业级日志 UI + OOM 防护
- [x] Bridge 异常自动栈追踪 + 安全 setState
- [x] 多文件翻页预览（BRWebPreviewMultiPage）
- [x] 多图选择（pickMultiPhoto）+ 音频返回格式统一
- [x] 图片选择器死循环修复 + 资源去重
- [x] Vue 端文件画廊 + 全屏查看器（支持图片/视频/音频）
- [x] 通信模型统一（meta + id/action/params 双向一致 + H5 响应回传）
- [ ] BR_Web Vue NPM 包独立发布
- [ ] 生产环境资源包 OTA（替换 Mock download）
- [ ] Cookie/Token 注入和 SSO
- [ ] WebView 池化/预热
- [ ] 离线包校验和回滚
