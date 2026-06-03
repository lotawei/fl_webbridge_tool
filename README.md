# fl_webbridge_tool

通用可扩展 Flutter WebBridge 插件 — Flutter 做壳 + H5 做业务，通过统一 Bridge 双向通信。

## 方案定位

- Flutter 负责：App 壳、导航、TabBar、登录态、权限、原生能力、日志、生命周期
- H5 负责：高频变化的页面业务
- `fl_webbridge_tool` 插件：暴露稳定 API，默认能力开箱可用，业务可按需扩展

## 标准插件结构

```text
fl_webbridge_tool/
  android/                  # Android 插件注册
  ios/                      # iOS 插件注册
  lib/                      # Dart API + BR_Web 容器实现
    src/
      br_web_bridge.dart          # 双向通信桥
      br_web_bridge_message.dart  # 消息模型
      br_web_capability_handler.dart  # 能力处理器（30+ action）
      br_web_container_page.dart  # 容器页面
      br_web_lifecycle.dart       # 生命周期枚举
      br_web_logger.dart          # 统一日志器 + ⚡ bridgeError 栈追踪
      br_web_global_log.dart      # 全局单例日志集线器
      br_web_log_widgets.dart     # 内置日志 UI 组件
      br_web_network_monitor.dart # 网络状态监听
      br_web_system_info.dart     # 设备/系统信息
      br_web_resource_manager.dart # 离线资源包管理
      br_web_database_manager.dart # 通用数据库 CRUD + 工单模型
      br_web_preview_page.dart    # 文件预览（图/视频/音频）
      br_web_permission_helper.dart # 统一权限申请
      br_web_navigator.dart       # 路由注册 + 跳转
      br_web_dev_guard.dart       # 开发期合约检查
      br_web_initial_data.dart    # 通用数据注入
  example/                  # 宿主 App，演示接入
  docs/                     # 方案文档 + 集成手册
  pubspec.yaml
```

## 完整能力矩阵

### 设备能力（DefaultBRWebCapabilityHandler）

| Action | 说明 | 权限 | 关键参数 |
|--------|------|------|---------|
| `device.camera.takePhoto` | 拍照（默认存系统相册） | `CAMERA` | `maxSizeKB`, `maxWidth`, `maxHeight`, `saveToGallery` |
| `device.camera.pickPhoto` | 从相册选照片 | `PHOTOS` | `maxSizeKB` |
| `device.camera.takeVideo` | 录像（默认存系统相册） | `CAMERA` + `MICROPHONE` | `maxDuration`, `camera`, `saveToGallery` |
| `device.camera.pickVideo` | 从相册选视频 | `PHOTOS` | `maxDuration` |
| `device.file.pick` | 文件选择 | - | `multiple` |
| `device.file.preview` | 预览文件（全屏图/视频/音频） | - | `path`, `type`, `title`, `mimeType`, `size` |
| `device.file.delete` | 删除本地文件 | - | `path` |
| `device.audio.startRecord` | 开始录音 | `MICROPHONE` | - |
| `device.audio.stopRecord` | 停止录音 | - | - |
| `device.network.status` | 查询网络状态（wifi/mobile/offline） | - | - |
| `device.system.info` | 查询设备/系统信息 | - | - |

### 导航 & UI

| Action | 说明 | 参数 |
|--------|------|------|
| `navigation.navigateTo` | 跳转到已注册路由 | `route`, `params` |
| `navigation.goBack` | 返回上一页 | - |
| `navigation.setTitle` | 修改页面标题 | `title` |
| `ui.hideTabBar` | 隐藏底部 TabBar | - |
| `ui.showTabBar` | 显示底部 TabBar | - |
| `container.close` | 关闭当前容器 | - |

### 离线资源包（BRWebResourceManager）

| Action | 说明 |
|--------|------|
| `resource.getStatus` | 获取资源包状态（版本/下载进度/已安装列表） |
| `resource.checkUpdate` | 检查服务端新版本 |
| `resource.startUpdate` | 开始下载更新 |
| `resource.cancelUpdate` | 取消下载 |
| `resource.switchTo` | 切换到指定版本 |

### 数据库——工单示例（NativeDataBaseManager\<T\>）

| Action | 说明 | 参数 |
|--------|------|------|
| `database.workOrder.query` | 查询工单列表 | `where`, `whereArgs`, `limit` |
| `database.workOrder.getById` | 按 ID 查询 | `id` |
| `database.workOrder.insert` | 插入新工单 | `title`, `description`, `status`, `priority`, `assignee`, `address` |
| `database.workOrder.update` | 更新工单 | `id` + 同 insert 字段 |
| `database.workOrder.delete` | 删除工单 | `id` |

> 业务可通过扩展 `NativeDataBaseManager<T>` + 自定义 `BRWebCapabilityHandler` 新增任意 table。

### 数据注入（BRWebInitialData）

无需 bridge 调用的同步数据注入，H5 直接读 `window.__BR_Data__`：

```dart
BRWebContainerPage(
  initialData: BRWebInitialData(
    accessToken: 'xxx',
    userData: {'id': '1001', 'name': '张三'},
    lang: 'zh',
    extra: {'appVersion': '1.2.3'},
  ),
)
```

### 全链路日志

| 组件 | 说明 |
|------|------|
| `BRWebLogger` | 日志接口（request/response/lifecycle/console/error/bridgeError/ui/native） |
| `CallbackBRWebLogger` | 回调日志器，所有事件通过 `onLog` 统一输出 |
| `BRWebGlobalLog` | 全局单例日志集线器，任意位置写入/订阅 |
| `BRWebGlobalLogPage` | 内置工业级日志查看页（过滤 + 搜索 + 颜色编码 + 清空） |
| `BRWebLoggableBottomBar` | 自动写全局日志的 NavigationBar |

**日志类型标签**：📡 lifecycle / ⬆️ REQ / ⬇️ RES / 📜 console / 💥 JS错误 / 🔌 bridge异常 / 🎨 UI / 🦴 native

**Bridge 异常日志含堆栈**：错误发生时自动捕获 stack trace，优先显示 `br_web_*.dart` 相关定位行。

### 权限体系

- `BRWebPermissionHelper` — 三级处理：
  1. 已授予 → 直接通过
  2. 普通拒绝 → 弹出说明弹窗 → 重试
  3. 永久拒绝 → 弹出引导弹窗 → 跳转系统设置

### 开发期合约检查（BRWebDevGuard）

```dart
BRWebContainerPage(
  capabilityHandler: BRWebDevGuard(
    inner: _handler,
    logger: _logger,
  ),
)
```

- Debug 模式下自动检测回调绑定完整性
- H5 调了 UI action 但 Native 没绑 `onUiRequest` → 立即打印 ⚠️ 警告
- 启动时可调用 `runStartupChecks()` 做全量检查

### 网络 & 系统信息

- `BRWebNetworkMonitor` — 自动监听 WiFi/移动网络/离线变化，实时推送
- `BRWebSystemInfo` — 设备型号/系统版本/App版本一键收集

## Bridge 协议

H5 调 Native：

```js
window.flutter_inappwebview.callHandler('BR_WebNativeBridge', {
  id: 'request_id',
  action: 'device.camera.takePhoto',
  params: { quality: 80, saveToGallery: true }
})
```

Native 响应：

```json
// 成功
{ "id": "request_id", "ok": true, "data": { ... } }

// 失败（含栈追踪）
{ "id": "request_id", "ok": false, "error": "Bad state: db not configured" }
```

Native 调 H5：

```dart
BRWebBridge.callWeb('container.lifecycle', { type: 'loadStop', url: '...' });
```

## 快速接入

```yaml
dependencies:
  fl_webbridge_tool:
    git:
      url: ssh://your-git/fl_webbridge_tool.git
      ref: v0.1.0
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
  onLifecycle: (event) => apm.report(event),
)
```

离线模式：

```dart
BRWebContainerPage(initialFile: 'assets/h5/demo.html')
```

## 扩展原生能力

```dart
class MyHandler implements BRWebCapabilityHandler {
  @override
  Future<Object?> handle(BuildContext context, BRWebBridgeMessage msg) {
    return switch (msg.action) {
      'user.getToken' => {'token': 'xxx'},
      'payment.pay' => _pay(msg.params),
      _ => Future.value(BRWebCapabilityHandlerResult.notHandled),
    };
  }
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

# 运行 App
cd example && flutter run
```

## 性能建议

- Tab 容器用 `IndexedStack`，减少 WebView 重建
- 大文件传 path/id，不传 base64
- 日志采样上报，避免高频刷屏
- SPA 页面监听 history 变化
- 权限按需申请，不一次性索取
- **⚠️ 每个 BRWebContainerPage 实例必须传入 `capabilityHandler`**，否则使用空默认实例（所有 manager 为 null）
