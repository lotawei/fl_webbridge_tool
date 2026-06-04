## v0.3.0 (2026-06-04)

### 新增 / 架构变更

- **通信模型统一**：双向统一为 `{id, action, params, meta?}` → `{id, ok, data/error}`，不再有 `{method, params}` 旧格式
- **meta 元信息**：H5 每次 `brCall` 自动注入 h5Version/h5Branch/platform/appVersion/lang，`setBridgeMeta()` 可扩展
- **onNativeCall 支持响应**：H5 可返回 `{ok, data/error}` 给 Native
- **统一 TS 类型**：删除 `NativeCallMessage`，全用 `BRWebBridgeMessage`
- **`BRWebInitialData` 类型扩展**：新增 `appVersion` / `resourceVersion` / `extra` 字段

### 修复

- 图片选择器死循环 → 移除 `_pickWithMaxSize` 循环重试逻辑
- LogPage 长日志 → maxLines: 3 + 点击弹窗查看详情
- 资源去重：`_loadManifest` 按路径去重 + `installedVersions` 自动排序
- `_safeSetState()` + schedulerPhase 检查，防止 build 阶段 setState 崩溃
- 音频 `stopRecord` 返回结构统一（含 mimeType/name/size）
- 网络状态首次查询改为 `checkNow()` 实时获取
- `window.__BR_Data__.accessToken` TypeScript 类型完整性

### 改进

- `BRWebGlobalLog.maxCapacity = 2000` 防止 OOM
- LogPage 操作：过滤 + 长按复制 + 长日志弹窗详情 + 全选复制 + 清空确认
- DB 错误走 `throw` → bridge 返回 `{ok:false, error}`，前端可正确展示

### 新增

- 资源包管理器 `BRWebResourceManager`：checkUpdate / startUpdate / cancelUpdate / switchTo
- 数据库 CRUD 框架 `NativeDataBaseManager<T>` + 工单模型 `WorkOrder` / `WorkOrderManager`
- 文件预览 `BRWebPreviewPage`：图片（缩放）/ 视频（播放控制）/ 音频（圆盘播放器）/ 未知类型提示
- 权限申请 `BRWebPermissionHelper`：普通拒绝弹窗 + 永久拒绝跳设置
- 路由注册 `BRWebNavigator`：register / push / pop
- 全局日志 `BRWebGlobalLog`：单例写入 + 订阅 + 路由追踪
- 日志 UI `BRWebGlobalLogPage`：类型过滤 + 搜索 + 颜色编码 + 清空
- 日志 TabBar `BRWebLoggableBottomBar`：切 Tab 自动写全局日志
- 开发合约 `BRWebDevGuard`：debug 模式下检测回调绑定
- `BridgeError` 日志类型 + 自动栈追踪

### 修复

- `device.network.status` 首次调用返回 unknown → 改为实时 `checkNow()` 查询
- DB 错误 `{ok:true, data:{error:...}}` → 改为 `throw` → `{ok:false, error:...}`
- Resource 5 个方法 `Future as Map` 类型转换错误 → 先判空再 await
- LogPage 加清空按钮 + 确认弹窗防误触
- dev server 页面缺少 `capabilityHandler` 注入 → 补传 `_handler`
- `workOrderManager` 未初始化 → 在 main() 中 init + seed + 注到 handler

### 改进

- Bridge catch 块捕获 `StackTrace`，错误日志显示文件行号
- LogPage 从 Stateless → StatefulWidget，支持过滤 + 选中复制 + 长按复制

## v0.1.0

- 初始版本：双向 Bridge + 相机/录音/文件选择 + 生命周期日志
