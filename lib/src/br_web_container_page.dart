import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'br_web_bridge.dart';
import 'br_web_capability_handler.dart';
import 'br_web_lifecycle.dart';
import 'br_web_logger.dart';

typedef BRWebLifecycleCallback = void Function(BRWebLifecycleEvent event);
typedef BRWebCreatedCallback =
    void Function(BRWebBridge bridge, InAppWebViewController controller);

class BRWebContainerPage extends StatefulWidget {
  const BRWebContainerPage({
    super.key,
    this.initialUrl,
    this.initialFile,
    this.title,
    this.capabilityHandler,
    this.logger = const DebugBRWebLogger(),
    this.onLifecycle,
    this.onCreated,
    this.showAppBar = true,
    this.pullToRefreshEnabled = false,
  }) : assert(
         initialUrl != null || initialFile != null,
         'initialUrl or initialFile is required.',
       );

  final String? initialUrl;
  final String? initialFile;
  final String? title;
  final BRWebCapabilityHandler? capabilityHandler;
  final BRWebLogger? logger;
  final BRWebLifecycleCallback? onLifecycle;
  final BRWebCreatedCallback? onCreated;
  final bool showAppBar;
  final bool pullToRefreshEnabled;

  @override
  State<BRWebContainerPage> createState() => _BRWebContainerPageState();
}

class _BRWebContainerPageState extends State<BRWebContainerPage> {
  late final BRWebBridge _bridge;
  late final PullToRefreshController _pullToRefreshController;
  InAppWebViewController? _controller;
  String? _title;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _bridge = BRWebBridge(
      context: context,
      capabilityHandler:
          widget.capabilityHandler ?? DefaultBRWebCapabilityHandler(),
      logger: widget.logger,
    );
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(enabled: widget.pullToRefreshEnabled),
      onRefresh: () async => _controller?.reload(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _log(
        BRWebLifecycleType.created,
        url: widget.initialUrl ?? widget.initialFile,
      );
    });
  }

  @override
  void dispose() {
    _log(BRWebLifecycleType.disposed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final webView = InAppWebView(
      initialUrlRequest: widget.initialUrl == null
          ? null
          : URLRequest(url: WebUri(widget.initialUrl!)),
      initialFile: widget.initialFile,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: false,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
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
        widget.onCreated?.call(_bridge, controller);
      },
      onLoadStart: (controller, url) {
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
        setState(() => _title = widget.title ?? title);
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
        _log(
          BRWebLifecycleType.console,
          message: '${consoleMessage.messageLevel}: ${consoleMessage.message}',
        );
      },
      onPermissionRequest: (controller, request) async {
        return PermissionResponse(
          resources: request.resources,
          action: PermissionResponseAction.GRANT,
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
