import 'br_web_bridge_message.dart';
import 'br_web_lifecycle.dart';

/// 日志事件类型
enum BRWebLogType {
  lifecycle,   // 生命周期事件
  request,     // bridge 请求
  response,    // bridge 响应
  console,     // H5 console 输出
  error,       // H5 JS 错误
  bridgeError, // bridge 通信异常
  ui,          // H5 → Native UI 控制
  native,      // Native 层自定义日志
}

/// 统一日志条目
class BRWebLogEntry {
  const BRWebLogEntry({
    required this.type,
    required this.timestamp,
    this.message,
    this.action,
    this.detail,
  });

  final BRWebLogType type;
  final DateTime timestamp;
  final String? message;
  final String? action;
  final String? detail;

  @override
  String toString() {
    final t = '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
    final label = switch (type) {
      BRWebLogType.lifecycle => '📡',
      BRWebLogType.request => '⬆️ REQ',
      BRWebLogType.response => '⬇️ RES',
      BRWebLogType.console => '📜',
      BRWebLogType.error => '💥',
      BRWebLogType.bridgeError => '🔌',
      BRWebLogType.ui => '🎨 UI',
      BRWebLogType.native => '🦴',
    };
    final actionStr = action != null ? ' [$action]' : '';
    final detailStr = detail != null ? ' $detail' : '';
    return '$t $label$actionStr ${message ?? ""}$detailStr';
  }
}

/// 日志回调（业务层实现即可将日志接入自定义 UI）
typedef BRWebLogCallback = void Function(BRWebLogEntry entry);

abstract interface class BRWebLogger {
  void bridgeRequest(BRWebBridgeMessage message);
  void bridgeResponse(String id, Object? response);
  void bridgeError(String action, Object error, StackTrace stack);
  void lifecycle(BRWebLifecycleEvent event);
  void console(String message);
  void jsError(String message, String? url, int? line);
  void uiRequest(String action, Map<String, dynamic>? params);
  void native(String message, {String? detail});
}

/// 回调日志器——所有日志通过 [onLog] 回调传出
///
/// 用法：
/// ```dart
/// final logger = CallbackBRWebLogger(onLog: (entry) => _logs.add(entry.toString()));
/// BRWebContainerPage(logger: logger, ...)
/// ```
class CallbackBRWebLogger implements BRWebLogger {
  const CallbackBRWebLogger({this.onLog});

  final BRWebLogCallback? onLog;

  void _log(BRWebLogEntry entry) => onLog?.call(entry);

  @override
  void bridgeRequest(BRWebBridgeMessage message) {
    final detail = StringBuffer(message.params.toString());
    if (message.meta.isNotEmpty) {
      detail.write(' meta=${message.meta}');
    }
    _log(BRWebLogEntry(
      type: BRWebLogType.request,
      timestamp: DateTime.now(),
      action: message.action,
      detail: detail.toString(),
    ));
  }

  @override
  void bridgeResponse(String id, Object? response) {
    _log(BRWebLogEntry(
      type: BRWebLogType.response,
      timestamp: DateTime.now(),
      message: id,
      detail: response.toString(),
    ));
  }

  @override
  void bridgeError(String action, Object error, StackTrace stack) {
    final lines = stack.toString().split('\n');
    // 取前 3 行关键堆栈（跳过 Flutter/Bridge 框架层）
    final top = lines
        .where((l) => l.contains('br_web_') || l.contains('fl_webbridge'))
        .take(3)
        .join(' ← ');
    _log(BRWebLogEntry(
      type: BRWebLogType.bridgeError,
      timestamp: DateTime.now(),
      action: action,
      message: '$error',
      detail: top.isNotEmpty ? top : lines.take(2).join(' ← '),
    ));
  }

  @override
  void lifecycle(BRWebLifecycleEvent event) {
    final msg = <String>[];
    if (event.url != null) msg.add('url=${event.url}');
    if (event.title != null) msg.add('title=${event.title}');
    if (event.progress != null) msg.add('progress=${event.progress}%');

    _log(BRWebLogEntry(
      type: BRWebLogType.lifecycle,
      timestamp: event.timestamp,
      action: event.type.name,
      message: msg.isEmpty ? null : msg.join(' | '),
      detail: event.message,
    ));
  }

  @override
  void console(String message) {
    _log(BRWebLogEntry(
      type: BRWebLogType.console,
      timestamp: DateTime.now(),
      detail: message,
    ));
  }

  @override
  void jsError(String message, String? url, int? line) {
    final loc = url != null ? '$url:$line' : null;
    _log(BRWebLogEntry(
      type: BRWebLogType.error,
      timestamp: DateTime.now(),
      message: message,
      detail: loc,
    ));
  }

  @override
  void uiRequest(String action, Map<String, dynamic>? params) {
    _log(BRWebLogEntry(
      type: BRWebLogType.ui,
      timestamp: DateTime.now(),
      action: action,
      detail: params?.toString(),
    ));
  }

  @override
  void native(String message, {String? detail}) {
    _log(BRWebLogEntry(
      type: BRWebLogType.native,
      timestamp: DateTime.now(),
      message: message,
      detail: detail,
    ));
  }
}

/// 控制台 Logger（开发调试用，输出到 print）
class DebugBRWebLogger extends CallbackBRWebLogger {
  const DebugBRWebLogger() : super(
    onLog: _printLog,
  );

  static void _printLog(BRWebLogEntry entry) {
    // ignore: avoid_print
    print(entry.toString());
  }
}
