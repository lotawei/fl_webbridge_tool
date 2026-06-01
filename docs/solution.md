# 通用 BR_Web 容器化方案

## 分层设计

1. App Shell：Flutter 主工程，承载 TabBar、路由、登录态、主题、全局错误和 APM。
2. fl_webbridge_tool：可复用插件 SDK，即当前仓库根目录。
3. Capability Handlers：原生能力插件点，如相机、录音、文件、定位、支付、分享、账号。
   - `DefaultBRWebCapabilityHandler` — 内置 15+ action
   - `CompositeBRWebCapabilityHandler` — 链式组合（自定义 → 默认）
   - `BRWebDevGuard` — 开发期合约检查
4. BR_Web Bridge：双向通信桥 + 通用数据注入 + 全链路日志
5. BR_Web Bridge Vue（NPM 包）：`br-web-bridge-vue` — Vue3 composable + types
6. Observability：生命周期、Bridge API 日志、H5 console/error、网络状态、系统信息、权限变化

## 完整能力矩阵

### 设备能力（DefaultBRWebCapabilityHandler）

| Action | 说明 | 权限 |
|--------|------|------|
| `device.camera.takePhoto` | 拍照（默认存系统相册） | CAMERA |
| `device.camera.takeVideo` | 录像（默认存系统相册） | CAMERA + MICROPHONE |
| `device.camera.pickVideo` | 从相册选视频 | PHOTOS |
| `device.file.pick` | 文件选择 | - |
| `device.file.preview` | 预览文件（图片/视频/音频） | - |
| `device.file.delete` | 删除本地文件 | - |
| `device.audio.startRecord` | 开始录音 | MICROPHONE |
| `device.audio.stopRecord` | 停止录音 | - |
| `device.network.status` | 查询网络状态 | - |
| `device.system.info` | 查询设备/系统信息 | - |

### 导航 & UI

| Action | 说明 |
|--------|------|
| `navigation.navigateTo` | 跳转到已注册路由 |
| `navigation.goBack` | 返回上一页 |
| `navigation.setTitle` | 修改页面标题 |
| `ui.hideTabBar` | 隐藏底部 TabBar |
| `ui.showTabBar` | 显示底部 TabBar |
| `container.close` | 关闭当前容器 |

### 数据注入

- `BRWebInitialData` — 通用数据模型（token / user / lang / extra）
- 注入方式：`UserScript AT_DOCUMENT_START` → H5 直接读 `window.__BR_Data__`
- 每个页面启动时重新注入（`onLoadStart` + `initialUserScripts`）

### 网络 & 系统信息

- `BRWebNetworkMonitor` — 自动监听 WiFi/移动网络/离线变化
- `BRWebSystemInfo` — 设备型号/系统版本/App版本一键收集

### 全链路日志

- `CallbackBRWebLogger` — 将所有事件（生命周期/Bridge/H5 console/error/网络/自定义）通过 `onLog` 回调统一输出
- 日志条目含时间戳、类型标签（📡⬆️⬇️📜💥🎨🦴）
- 业务层自定义日志通过 `logger.native()` 混入

### 开发期合约检查 (BRWebDevGuard)

- Debug 模式下自动检测回调绑定完整性
- H5 调了 UI action 但 Native 没绑 `onUiRequest` → 立即打印 ⚠️ 警告
- App 启动时可调用 `runStartupChecks()` 做全量检查

## 权限体系

### Android
```xml
INTERNET, CAMERA, RECORD_AUDIO,
READ_MEDIA_IMAGES, READ_MEDIA_VIDEO, READ_MEDIA_AUDIO,
READ_EXTERNAL_STORAGE(maxSdkVersion=32),
WRITE_EXTERNAL_STORAGE(maxSdkVersion=28)
```

### iOS
```
NSCameraUsageDescription, NSMicrophoneUsageDescription,
NSPhotoLibraryUsageDescription, NSPhotoLibraryAddUsageDescription
```

### 运行时权限
- `BRWebPermissionHelper.ensurePermission()` — 统一权限申请
- 普通拒绝 → 弹说明窗 + 重试
- 永久拒绝 → 弹窗引导跳系统设置

## 性能和稳定性

- Tab 容器用 `IndexedStack`，减少 WebView 重建
- 大文件传 path/id，不传 base64
- Bridge action 参数校验 + 错误码统一
- 权限按需申请，拒绝后返回清晰错误码
- iOS/Android 真机验证相机、录音、文件选择

## 后续可增强

- BR_Web JS SDK 独立发布 npm 包（已完成：`br-web-bridge-vue`）
- 支持离线包版本管理、预加载、校验和回滚
- 支持 Cookie/Token 注入和 SSO
- 支持 WebView 池化或预热
- Stagewise / 21st toolbar 调试集成（已完成基础安装）
