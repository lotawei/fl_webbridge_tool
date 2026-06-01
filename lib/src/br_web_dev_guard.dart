import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'br_web_bridge_message.dart';
import 'br_web_capability_handler.dart';
import 'br_web_logger.dart';

/// 开发期合约检查器
///
/// 包装 [BRWebCapabilityHandler]，在 debug 模式下：
/// 1. 检查 H5 调用的 action 是否被正确处理
/// 2. 当常规 action 触发但没有对应回调时，打印警告
/// 3. 明确提示哪些回调未绑定，防止上线后才发现"事件漏了"
///
/// 用法：
/// ```dart
/// final handler = BRWebDevGuard(
///   inner: MyCapabilityHandler(),
///   logger: logger,
///   expectedActions: ['ui.hideTabBar', 'navigation.setTitle'],
/// );
/// ```
class BRWebDevGuard implements BRWebCapabilityHandler {
  BRWebDevGuard({
    required this.inner,
    this.logger,
    this.expectedUiActions = const ['hideTabBar', 'showTabBar'],
    this.expectedTitleHandler = true,
  });

  final BRWebCapabilityHandler inner;
  final BRWebLogger? logger;

  /// 期望 H5 可能调用的 UI action 列表
  ///
  /// 当 H5 调用这些 action 时，如果对应的回调（如 [onUiRequest]）未绑定，
  /// 会在 debug 模式下打印警告。
  final List<String> expectedUiActions;

  /// 是否期望有标题回调绑定
  final bool expectedTitleHandler;

  /// 最后一次调用的 action（用于调试日志上下文）

  @override
  Future<Object?> handle(BuildContext context, BRWebBridgeMessage message) {

    if (kDebugMode) {
      _validateExpectedActions(message);
    }

    return inner.handle(context, message);
  }

  void _validateExpectedActions(BRWebBridgeMessage message) {
    // 检查是否在期望的 UI action 列表中
    if (expectedUiActions.contains(message.action)) {
      final handler = inner;
      if (handler is DefaultBRWebCapabilityHandler) {
        if (handler.onUiRequest == null) {
          logger?.native(
            '⚠️ BR_WEB_DEVMODE: H5 called "${message.action}" '
            'but onUiRequest callback is NOT bound. '
            'The native side will not react to this action.',
          );
        }
      }
    }

    // 检查标题回调
    if (message.action == 'navigation.setTitle' && expectedTitleHandler) {
      final handler = inner;
      if (handler is DefaultBRWebCapabilityHandler) {
        if (handler.onSetTitle == null) {
          logger?.native(
            '⚠️ BR_WEB_DEVMODE: H5 called "navigation.setTitle" '
            'but onTitleRequest callback is NOT bound. '
            'The title will not be updated in native.',
          );
        }
      }
    }
  }

  /// 在 App 启动时调用此方法做一次全量检查
  ///
  /// 返回需要修复的警告列表
  List<String> runStartupChecks() {
    final warnings = <String>[];

    final handler = inner;
    if (handler is DefaultBRWebCapabilityHandler) {
      if (handler.onUiRequest == null && expectedUiActions.isNotEmpty) {
        warnings.add(
          'onUiRequest callback not set. '
          'H5 calls like ui.hideTabBar will be silently ignored.',
        );
      }
      if (handler.onSetTitle == null && expectedTitleHandler) {
        warnings.add(
          'onTitleRequest callback not set. '
          'H5 navigation.setTitle will have no effect.',
        );
      }
    }

    for (final w in warnings) {
      logger?.native('🛑 BR_WEB_DEVMODE: $w');
    }

    return warnings;
  }
}
