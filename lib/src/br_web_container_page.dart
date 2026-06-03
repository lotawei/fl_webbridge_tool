import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

import 'br_web_bridge.dart';
import 'br_web_capability_handler.dart';
import 'br_web_dev_guard.dart';
import 'br_web_initial_data.dart';
import 'br_web_lifecycle.dart';
import 'br_web_logger.dart';
import 'br_web_permission_helper.dart';
import 'br_web_route_observer.dart';

typedef BRWebLifecycleCallback = void Function(BRWebLifecycleEvent event);
typedef BRWebCreatedCallback =
    void Function(BRWebBridge bridge, InAppWebViewController controller);

/// H5 请求原生控制 UI 时的回调
///
/// [action] — 如 `hideTabBar` / `showTabBar`
/// [params] — 附加参数
typedef BRWebUiRequestCallback =
    void Function(String action, Map<String, dynamic>? params);

/// H5 请求修改页面标题时的回调
typedef BRWebTitleRequestCallback = void Function(String title);

class BRWebContainerPage extends StatefulWidget {
  const BRWebContainerPage({
    super.key,
    this.url,
    this.initialFile,     // asset 路径 或 绝对文件系统路径（如 /data/.../index.html）
    this.title,
    this.initialData,
    this.capabilityHandler,
    this.logger = const DebugBRWebLogger(),
    this.onLifecycle,
    this.onCreated,
    this.onUiRequest,
    this.onTitleRequest,
    this.showAppBar = true,
    this.pullToRefreshEnabled = false,
  }) : assert(url != null || initialFile != null, 'url or initialFile is required.');

  /// H5 页面 URL（HTTP/HTTPS 或 file://）
  final String? url;

  /// 本地文件路径 — asset 路径或绝对文件系统路径（如 /data/.../index.html）
  final String? initialFile;

  /// 页面标题（H5 可通过 bridge `navigation.setTitle` 覆盖）
  final String? title;

  /// 注入到 H5 的通用数据（token、用户信息、语言等）
  ///
  /// 插件在页面加载前将其注入为 `window.__BR_Data__`，
  /// H5 无需调用 bridge 即可同步读取。
  final BRWebInitialData? initialData;

  /// 自定义能力注册器（替换默认）
  final BRWebCapabilityHandler? capabilityHandler;

  /// 日志器
  final BRWebLogger? logger;

  /// 生命周期事件回调
  final BRWebLifecycleCallback? onLifecycle;

  /// WebView 创建完成回调
  final BRWebCreatedCallback? onCreated;

  /// H5 请求 UI 控制回调（hideTabBar / showTabBar 等）
  final BRWebUiRequestCallback? onUiRequest;

  /// H5 通过 bridge 修改标题时的回调
  final BRWebTitleRequestCallback? onTitleRequest;

  /// 是否显示 AppBar
  final bool showAppBar;

  /// 是否启用下拉刷新
  final bool pullToRefreshEnabled;

  @override
  State<BRWebContainerPage> createState() => _BRWebContainerPageState();
}

class _BRWebContainerPageState extends State<BRWebContainerPage>
    with WidgetsBindingObserver, RouteAware {
  late final DefaultBRWebCapabilityHandler _handler;
  late final BRWebCapabilityHandler _capabilityHandler;
  late final BRWebBridge _bridge;
  late final PullToRefreshController _pullToRefreshController;
  BRWebRouteObserver? _routeObserver;
  InAppWebViewController? _controller;
  String? _title;
  int _progress = 0;
  bool _pageVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _title = widget.title;
    _handler = DefaultBRWebCapabilityHandler();
    _capabilityHandler = widget.capabilityHandler ?? _handler;

    // 回调连接：H5 → Native 标题控制
    _bindHostCallbacks(_capabilityHandler);

    _bridge = BRWebBridge(
      context: context,
      capabilityHandler: _capabilityHandler,
      logger: widget.logger,
    );
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(enabled: widget.pullToRefreshEnabled),
      onRefresh: () async => _controller?.reload(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 订阅 RouteAware 用于检测页面显隐
      final route = ModalRoute.of(context);
      final observer = BRWebRouteObserver.maybeOf(context);
      if (route != null && observer != null) {
        _routeObserver = observer;
        observer.subscribe(this, route);
      }
      _log(BRWebLifecycleType.created, url: _effectiveUrl);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // RouteAware 订阅在首次 post-frame 时执行
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final type = switch (state) {
      AppLifecycleState.resumed => 'foreground',
      AppLifecycleState.paused => 'background',
      AppLifecycleState.inactive => 'inactive',
      AppLifecycleState.hidden => 'hidden',
      AppLifecycleState.detached => 'detached',
    };
    _bridge.callWeb('app.lifecycle', <String, dynamic>{
      'state': type,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    widget.logger?.native('App $type');
  }

  // ─── RouteAware：页面自身显隐 ───
  @override
  void didPush() {
    _notifyPageVisible(true);
  }

  @override
  void didPopNext() {
    _notifyPageVisible(true);
  }

  @override
  void didPushNext() {
    _notifyPageVisible(false);
  }

  @override
  void didPop() {
    _notifyPageVisible(false);
  }

  void _notifyPageVisible(bool visible) {
    if (_pageVisible == visible) return;
    _pageVisible = visible;
    _bridge.callWeb('page.visibility', <String, dynamic>{
      'visible': visible,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    widget.logger?.native('Page ${visible ? "visible" : "hidden"}');
  }

  /// 有效的 URL
  String? get _effectiveUrl => widget.url;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeObserver?.unsubscribe(this);
    _log(BRWebLifecycleType.disposed);
    _bridge.callWeb('app.lifecycle', <String, dynamic>{
      'state': 'disposed',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAbsPath = widget.initialFile != null && widget.initialFile!.startsWith('/');
    final webView = InAppWebView(
      initialUrlRequest: _effectiveUrl != null
          ? URLRequest(url: WebUri(_effectiveUrl!))
          : isAbsPath
              ? URLRequest(url: WebUri('file://${widget.initialFile}'))
              : null,
      initialFile: isAbsPath ? null : widget.initialFile,
      initialUserScripts: _buildUserScripts(),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: false,
        geolocationEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
        transparentBackground: false,
        useShouldOverrideUrlLoading: true,
        useOnDownloadStart: true,
        supportZoom: false,
        verticalScrollBarEnabled: false,
        horizontalScrollBarEnabled: false,
      ),
      pullToRefreshController: _pullToRefreshController,
      onWebViewCreated: (controller) {
        _controller = controller;
        _bridge.bind(controller);
        _injectInitialData(controller);
        widget.onCreated?.call(_bridge, controller);
      },
      onLoadStart: (controller, url) {
        _injectInitialData(controller);
        _log(BRWebLifecycleType.loadStart, url: url?.toString());
        _bridge.emitLifecycle('loadStart', <String, dynamic>{
          'url': url?.toString(),
        });
      },
      onLoadStop: (controller, url) async {
        _pullToRefreshController.endRefreshing();
        _log(BRWebLifecycleType.loadStop, url: url?.toString());
        await _bridge.emitLifecycle('loadStop', <String, dynamic>{
          'url': url?.toString(),
        });
      },
      onReceivedError: (controller, request, error) {
        _pullToRefreshController.endRefreshing();
        widget.logger?.jsError(
          '${error.type}: ${error.description}',
          request.url.toString(),
          null,
        );
        _log(
          BRWebLifecycleType.error,
          url: request.url.toString(),
          message: '${error.type}: ${error.description}',
        );
      },
      onProgressChanged: (controller, progress) {
        setState(() => _progress = progress);
        _log(BRWebLifecycleType.progress, progress: progress);
      },
      onTitleChanged: (controller, title) {
        // 只有 H5 没有通过 bridge 覆盖时，才用 WebView 的 title
        if (_title == widget.title) {
          setState(() => _title = title);
        }
        _log(BRWebLifecycleType.titleChanged, title: title);
      },
      onUpdateVisitedHistory: (controller, url, isReload) {
        _log(
          BRWebLifecycleType.historyUpdate,
          url: url?.toString(),
          message: 'reload=$isReload',
        );
      },
      onConsoleMessage: (controller, consoleMessage) {
        widget.logger?.console(
          '${consoleMessage.messageLevel}: ${consoleMessage.message}',
        );
        _log(
          BRWebLifecycleType.console,
          message: '${consoleMessage.messageLevel}: ${consoleMessage.message}',
        );
      },
      onPermissionRequest: (controller, request) async {
        return _handleWebPermissionRequest(request);
      },
      onGeolocationPermissionsShowPrompt: (controller, origin) async {
        final allowed = await _ensureWebRuntimePermission(
          permission: Permission.locationWhenInUse,
          permissionName: '定位',
          purpose: '网页定位',
        );
        return GeolocationPermissionShowPromptResponse(
          origin: origin,
          allow: allowed,
          retain: allowed,
        );
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        return NavigationActionPolicy.ALLOW;
      },
    );

    if (!widget.showAppBar) {
      return webView;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_title ?? 'BR_Web Container'),
        actions: [
          IconButton(
            tooltip: 'Call BR_Web',
            icon: const Icon(Icons.send_to_mobile),
            onPressed: () {
              _bridge.callWeb('native.ping', <String, dynamic>{
                'time': DateTime.now().toIso8601String(),
              });
            },
          ),
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller?.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          webView,
          if (_progress > 0 && _progress < 100)
            LinearProgressIndicator(value: _progress / 100),
        ],
      ),
    );
  }

  /// 构建初始注入脚本（DOM 创建前执行，保证比 Vue 脚本先跑）
  UnmodifiableListView<UserScript> _buildUserScripts() {
    final data = widget.initialData;
    final js = data != null ? data.toJsScript() : 'window.__BR_Data__ = {};';
    return UnmodifiableListView<UserScript>([
      UserScript(
        source: js,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
    ]);
  }

  /// 页面加载后补充注入（处理 SPA 跳转等场景）
  void _injectInitialData(InAppWebViewController controller) {
    final data = widget.initialData;
    if (data == null) return;
    controller.evaluateJavascript(source: data.toJsScript());
  }

  void _bindHostCallbacks(BRWebCapabilityHandler handler) {
    switch (handler) {
      case DefaultBRWebCapabilityHandler():
        handler.onSetTitle = (title) {
          if (mounted) {
            setState(() => _title = title);
          }
          widget.onTitleRequest?.call(title);
        };
        handler.onUiRequest = (action, params) {
          widget.onUiRequest?.call(action, params);
        };
      case CompositeBRWebCapabilityHandler(:final handlers):
        for (final child in handlers) {
          _bindHostCallbacks(child);
        }
      case BRWebDevGuard(:final inner):
        _bindHostCallbacks(inner);
      default:
        break;
    }
  }

  Future<PermissionResponse> _handleWebPermissionRequest(
    PermissionRequest request,
  ) async {
    var allowed = true;

    if (_hasWebResource(request, PermissionResourceType.CAMERA) ||
        _hasWebResource(
          request,
          PermissionResourceType.CAMERA_AND_MICROPHONE,
        )) {
      allowed = await _ensureWebRuntimePermission(
        permission: Permission.camera,
        permissionName: '相机',
        purpose: '网页拍照或视频通话',
      );
    }

    if (allowed &&
        (_hasWebResource(request, PermissionResourceType.MICROPHONE) ||
            _hasWebResource(
              request,
              PermissionResourceType.CAMERA_AND_MICROPHONE,
            ))) {
      allowed = await _ensureWebRuntimePermission(
        permission: Permission.microphone,
        permissionName: '麦克风',
        purpose: '网页录音或视频通话',
      );
    }

    widget.logger?.native(
      'Web permission ${allowed ? "granted" : "denied"}',
      detail: request.resources
          .map((resource) => resource.toString())
          .join(', '),
    );

    return PermissionResponse(
      resources: request.resources,
      action: allowed
          ? PermissionResponseAction.GRANT
          : PermissionResponseAction.DENY,
    );
  }

  Future<bool> _ensureWebRuntimePermission({
    required Permission permission,
    required String permissionName,
    required String purpose,
  }) async {
    if (!mounted) return false;
    return BRWebPermissionHelper.ensurePermission(
      permission: permission,
      context: context,
      permissionName: permissionName,
      purpose: purpose,
    );
  }

  bool _hasWebResource(
    PermissionRequest request,
    PermissionResourceType resource,
  ) {
    return request.resources.any(
      (requested) => requested.toValue() == resource.toValue(),
    );
  }

  void _log(
    BRWebLifecycleType type, {
    String? url,
    String? title,
    int? progress,
    String? message,
  }) {
    final event = BRWebLifecycleEvent(
      type: type,
      timestamp: DateTime.now(),
      url: url,
      title: title,
      progress: progress,
      message: message,
    );
    widget.logger?.lifecycle(event);
    widget.onLifecycle?.call(event);
  }
}
