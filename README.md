# fl_webbridge_tool

这是一个最小化但可扩展的 Flutter WebBridge 插件。当前仓库根目录是 `fl_webbridge_tool` 插件本体，`example/` 是宿主示例工程，其它 Flutter 工程可以用 Git / private pub / path 的方式快速接入。

## 方案定位

- Flutter 负责 App 壳、导航、TabBar、登录态、权限、原生能力、日志和生命周期治理。
- 网页业务负责高频变化的页面，通过统一 Bridge 调用 Flutter 能力。
- `fl_webbridge_tool` 插件只暴露稳定入口，不把业务能力写死；默认能力可用，业务也可以扩展或替换。

## 标准插件结构

```text
fl_webbridge_tool/
  android/                 # Android 插件注册代码
  ios/                     # iOS 插件注册代码
  lib/                     # Dart API 和 BR_Web 容器实现
  example/                 # 宿主 App，演示其它项目如何接入
  docs/                    # 集成手册和方案文档
  pubspec.yaml             # 插件 pubspec，包含 flutter.plugin.platforms
```

## 当前最小能力

- BR_Web -> Flutter：`window.flutter_inappwebview.callHandler('BR_WebNativeBridge', message)`
- Flutter -> BR_Web：`BRWebBridge.callWeb(method, params)`
- BR_Web 调用原生拍照：`device.camera.takePhoto`
- BR_Web 调用文件选择：`device.file.pick`
- BR_Web 调用录音开始/停止：`device.audio.startRecord` / `device.audio.stopRecord`
- BR_Web 关闭当前容器：`container.close`
- Flutter 感知 BR_Web 生命周期：创建、加载开始、加载完成、进度、SPA history、标题变化、console、错误、销毁
- API 日志：请求、响应、生命周期统一接入 `BRWebLogger`

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
  onLifecycle: (event) {
    // 上报 APM / 埋点 / Debug console
  },
)
```

离线包或本地资源：

```dart
BRWebContainerPage(
  initialFile: 'assets/h5/demo.html',
)
```

## Bridge 协议

BR_Web 请求：

```js
window.flutter_inappwebview.callHandler('BR_WebNativeBridge', {
  id: 'request_id',
  action: 'device.camera.takePhoto',
  params: { quality: 80 }
})
```

Flutter 响应：

```json
{
  "id": "request_id",
  "ok": true,
  "data": {}
}
```

失败响应：

```json
{
  "id": "request_id",
  "ok": false,
  "error": "reason"
}
```

## 扩展原生能力

```dart
class AppCapabilityHandler implements BRWebCapabilityHandler {
  @override
  Future<Object?> handle(BuildContext context, BRWebBridgeMessage message) async {
    if (message.action == 'user.getToken') {
      return {'token': 'xxx'};
    }
    return BRWebCapabilityHandlerResult.notHandled;
  }
}

BRWebContainerPage(
  initialUrl: 'https://your-domain.example/page',
  capabilityHandler: CompositeBRWebCapabilityHandler([
    AppCapabilityHandler(),
    DefaultBRWebCapabilityHandler(),
  ]),
)
```

## 性能建议

- WebView 页面保持常驻：底部 Tab 使用 `IndexedStack`，避免频繁销毁和重建。
- 大型网页首屏资源走 CDN/离线包，开启 gzip/br，减少同步 JS。
- Flutter 和 BR_Web 通信传小 JSON；大文件传 path/id，不传 base64。
- 日志采样上报，避免 console 和 bridge 高频刷屏拖慢低端机。
- SPA 页面必须监听 history 变化，不能只依赖 `onLoadStop`。
- 权限申请放在原生能力调用前，不在容器初始化时一次性索取。

## 平台配置

Android 需要声明 `INTERNET`、`CAMERA`、`RECORD_AUDIO`、媒体读取权限。

iOS 需要声明 `NSCameraUsageDescription`、`NSMicrophoneUsageDescription`、`NSPhotoLibraryUsageDescription`。

示例工程已经配置，可参考：

- `example/android/app/src/main/AndroidManifest.xml`
- `example/ios/Runner/Info.plist`

## 运行

运行示例工程：

```sh
cd example
flutter pub get
flutter run
```

## 其它项目集成手册

浏览器打开 `docs/fl_webbridge_tool_integration.html`，里面包含依赖配置、Flutter 页面接入、网页 JS 调用、平台权限、能力扩展和验证清单。
