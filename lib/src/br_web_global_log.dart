import 'dart:async';

import 'br_web_bridge_message.dart';
import 'br_web_lifecycle.dart';
import 'br_web_logger.dart';

/// 全局单例日志集线器 —— 不侵入业务代码，任何地方都能写入和订阅
///
/// 用法：
/// ```dart
/// // 订阅（UI 层）
/// BRWebGlobalLog.instance.addListener((entry) => setState(() => _logs.insert(0, entry)));
///
/// // 任意位置写入
/// BRWebGlobalLog.instance.native('页面切换', detail: '原生 → BR_Web');
/// BRWebGlobalLog.instance.navigatorPush('/h2');
/// BRWebGlobalLog.instance.navigatorPop('/h2');
/// ```
class BRWebGlobalLog {
  BRWebGlobalLog._();

  static final BRWebGlobalLog instance = BRWebGlobalLog._();

  /// 最大保留条数，超出后自动移除旧条目（默认 2000）
  int maxCapacity = 2000;

  final List<BRWebLogEntry> _entries = <BRWebLogEntry>[];
  final List<void Function(BRWebLogEntry)> _listeners =
      <void Function(BRWebLogEntry)>[];

  // ───────────────── 订阅 ─────────────────

  void addListener(void Function(BRWebLogEntry) callback) {
    _listeners.add(callback);
  }

  void removeListener(void Function(BRWebLogEntry) callback) {
    _listeners.remove(callback);
  }

  // ───────────────── 写入 ─────────────────

  void log(BRWebLogEntry entry) {
    _entries.add(entry);
    // 超出上限时移除最旧的条目
    while (_entries.length > maxCapacity) {
      _entries.removeAt(0);
    }
    // 延迟到下一微任务派发 listener，避免 build 阶段 setState 崩溃
    for (final listener in _listeners) {
      scheduleMicrotask(() => listener(entry));
    }
  }

  void native(String message, {String? detail}) {
    log(BRWebLogEntry(
      type: BRWebLogType.native,
      timestamp: DateTime.now(),
      message: message,
      detail: detail,
    ));
  }

  void lifecycle(BRWebLifecycleEvent event) {
    log(BRWebLogEntry(
      type: BRWebLogType.lifecycle,
      timestamp: event.timestamp,
      action: event.type.name,
      message: _lifecycleDetail(event),
    ));
  }

  void request(BRWebBridgeMessage message) {
    log(BRWebLogEntry(
      type: BRWebLogType.request,
      timestamp: DateTime.now(),
      action: message.action,
      detail: message.params.toString(),
    ));
  }

  void response(String id, Object? response) {
    log(BRWebLogEntry(
      type: BRWebLogType.response,
      timestamp: DateTime.now(),
      message: id,
      detail: response.toString(),
    ));
  }

  void uiRequest(String action, Map<String, dynamic>? params) {
    log(BRWebLogEntry(
      type: BRWebLogType.ui,
      timestamp: DateTime.now(),
      action: action,
      detail: params?.toString(),
    ));
  }

  void console(String message) {
    log(BRWebLogEntry(
      type: BRWebLogType.console,
      timestamp: DateTime.now(),
      detail: message,
    ));
  }

  void jsError(String message, String? url, int? line) {
    log(BRWebLogEntry(
      type: BRWebLogType.error,
      timestamp: DateTime.now(),
      message: message,
      detail: url != null ? '$url:$line' : null,
    ));
  }

  // ───────────────── 路由追踪 ─────────────────

  void routePush(String routeName) {
    native('路由 push', detail: routeName);
  }

  void routePop(String? routeName) {
    native('路由 pop', detail: routeName ?? 'root');
  }

  void tabSwitch(int from, int to, {String? labels}) {
    native('Tab 切换', detail: labels != null ? '$labels [$from→$to]' : '$from → $to');
  }

  // ───────────────── 导出 ─────────────────

  List<BRWebLogEntry> get entries => List<BRWebLogEntry>.unmodifiable(_entries);

  /// 最新的 N 条（按时间倒序）
  List<BRWebLogEntry> recent(int n) {
    final start = _entries.length > n ? _entries.length - n : 0;
    return _entries.sublist(start).reversed.toList();
  }

  void clear() {
    _entries.clear();
  }

  // ───────────────── 适配器（无侵入注入到现有 BRWebLogger 接口） ─────────────────

  /// 生成一个 CallbackBRWebLogger，自动路由到全局单例
  static CallbackBRWebLogger get adapter =>
      CallbackBRWebLogger(onLog: (entry) => instance.log(entry));

  String _lifecycleDetail(BRWebLifecycleEvent event) {
    final parts = <String>[];
    if (event.url != null) parts.add('url=${event.url}');
    if (event.title != null) parts.add('title=${event.title}');
    if (event.progress != null) parts.add('progress=${event.progress}%');
    if (event.message != null) parts.add(event.message!);
    return parts.join(' | ');
  }
}
