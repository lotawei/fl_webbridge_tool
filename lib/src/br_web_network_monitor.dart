import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'br_web_logger.dart';

/// 网络状态监听器
///
/// 自动监听设备网络变化，通过 [onChanged] 回调通知。
/// 用法：
/// ```dart
/// final monitor = BRWebNetworkMonitor(
///   logger: logger,
///   onChanged: (status) => bridge.emitLifecycle('networkChange', {'status': status}),
/// );
/// monitor.start();
/// ```
class BRWebNetworkMonitor {
  BRWebNetworkMonitor({
    this.logger,
    this.onChanged,
  });

  final BRWebLogger? logger;
  final void Function(String status)? onChanged;

  final Connectivity _connectivity = Connectivity();
  late final StreamSubscription<List<ConnectivityResult>> _subscription;

  String _currentStatus = 'unknown';

  /// 当前网络状态：wifi / mobile / offline / unknown
  String get currentStatus => _currentStatus;

  /// 开始监听
  void start() {
    _subscription = _connectivity.onConnectivityChanged.listen(_handleChange);

    // 初始化当前状态
    _connectivity.checkConnectivity().then((results) {
      _handleChange(results);
    });
  }

  void _handleChange(List<ConnectivityResult> results) {
    final status = _toStatus(results);
    if (status == _currentStatus) return;

    final previous = _currentStatus;
    _currentStatus = status;

    logger?.native(
      'Network changed: $previous → $status',
      detail: results.toString(),
    );
    onChanged?.call(status);
  }

  String _toStatus(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return 'offline';
    }
    if (results.contains(ConnectivityResult.wifi)) return 'wifi';
    if (results.contains(ConnectivityResult.ethernet)) return 'ethernet';
    if (results.contains(ConnectivityResult.mobile)) return 'mobile';
    return 'online';
  }

  /// 立即获取当前状态
  Future<String> checkNow() async {
    final results = await _connectivity.checkConnectivity();
    return _toStatus(results);
  }

  /// 停止监听
  void stop() {
    _subscription.cancel();
  }
}
