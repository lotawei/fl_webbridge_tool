# 通用 BR_Web 容器化方案

## 分层设计

1. App Shell：Flutter 主工程，承载 TabBar、路由、登录态、主题、全局错误和 APM。
2. fl_webbridge_tool：可复用插件 SDK，即当前仓库根目录。
3. Capability Handlers：原生能力插件点，如相机、录音、文件、定位、支付、分享、账号。
4. BR_Web Bridge SDK：网页侧 JS 封装，统一 promise 化调用和错误处理。
5. Observability：生命周期、API 日志、console、错误、性能指标统一上报。

## 为什么使用 flutter_inappwebview

`flutter_inappwebview` 比基础 WebView 包更适合容器化场景：JS handler 更直接，WebView 生命周期事件更丰富，权限请求、下载、history 变化、console、资源拦截等能力更完整。代价是升级 Flutter/Android/iOS 时要更认真做兼容测试。

## 接入形态

推荐把容器做成 Flutter package，而不是散落在业务工程里：

- 独立版本号，方便灰度和回滚。
- 对外 API 稳定，业务只关心 URL、能力注册、生命周期回调。
- 默认能力内置，业务能力通过 `BRWebCapabilityHandler` 扩展。
- 可以沉淀统一安全策略，如域名白名单、URL 拦截、bridge action 白名单。

## 生命周期治理

容器需要记录：

- created / disposed：容器创建和销毁。
- loadStart / loadStop / error / progress：传统页面加载。
- historyUpdate：SPA 的 pushState、replaceState、hash 路由变化。
- titleChanged：同步网页标题。
- console：用于调试和日志采样。

这些事件不只用于 UI，也应该进入 APM：首屏慢、白屏、JS 错误、接口失败通常都需要结合生命周期判断。

## 通信协议

Bridge 请求必须包含：

- `id`：请求 ID，用于日志关联。
- `action`：能力名，建议按 namespace 管理，如 `device.camera.takePhoto`。
- `params`：参数对象，只传 JSON 可序列化数据。

响应统一为：

- `ok=true, data=...`
- `ok=false, error=...`

不要让网页直接知道平台差异；平台差异由 Flutter handler 屏蔽。

## 性能和稳定性

- Tab 容器用 `IndexedStack` 或缓存路由，减少 WebView 重建。
- 大文件用本地 path、临时 token 或上传任务 ID，避免 bridge 传 base64。
- Bridge action 做白名单和参数校验，避免 H5 任意调用原生能力。
- 权限按需申请，拒绝后给网页明确错误码。
- 关闭页面、返回键、刷新、重试要由容器统一处理，避免每个网页重复造。
- iOS/Android 分别真机验证相机、录音、文件选择，模拟器覆盖不够。

## 后续可增强

- BR_Web JS SDK 单独发布 npm 包。
- 支持离线包版本管理、预加载、校验和回滚。
- 支持 Cookie/Token 注入和 SSO。
- 支持 URL 白名单、scheme 拦截、下载管理。
- 支持 bridge 权限矩阵和审计日志。
- 支持 WebView 池化或预热。
