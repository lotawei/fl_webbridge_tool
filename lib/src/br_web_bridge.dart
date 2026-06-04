import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'br_web_bridge_message.dart';
import 'br_web_capability_handler.dart';
import 'br_web_logger.dart';

class BRWebBridge {
  BRWebBridge({
    required this.context,
    required this.capabilityHandler,
    this.logger,
  });

  static const handlerName = 'BR_WebNativeBridge';

  final BuildContext context;
  final BRWebCapabilityHandler capabilityHandler;
  final BRWebLogger? logger;

  InAppWebViewController? _controller;

  void bind(InAppWebViewController controller) {
    _controller = controller;
    controller.addJavaScriptHandler(
      handlerName: handlerName,
      callback: (args) async {
        final message = BRWebBridgeMessage.fromArgs(args);
        logger?.bridgeRequest(message);
        try {
          final data = await capabilityHandler.handle(context, message);
          final response = message.ok(data);
          logger?.bridgeResponse(message.id, response);
          return response;
        } catch (error, stack) {
          final response = message.fail(error);
          logger?.bridgeResponse(message.id, response);
          logger?.bridgeError(message.action, error, stack);
          return response;
        }
      },
    );
  }

  static int _seq = 0;
  static String _nextId() => '${DateTime.now().microsecondsSinceEpoch}_n_${(++_seq).toRadixString(36)}';

  /// Native → H5 调用（统一消息模型）
  /// 发送 `{id, action, params}`，H5 可通过 onNativeCall 接收
  Future<dynamic> callWeb(String action, [Map<String, dynamic>? params]) async {
    final payload = jsonEncode(<String, dynamic>{
      'id': _nextId(),
      'action': action,
      'params': params ?? const <String, dynamic>{},
    });
    return _controller?.evaluateJavascript(
      source:
          'window.BR_WebContainer && window.BR_WebContainer.__nativeCall($payload);',
    );
  }

  Future<void> emitLifecycle(String type, Map<String, dynamic> data) async {
    await callWeb('container.lifecycle', <String, dynamic>{
      'type': type,
      ...data,
    });
  }
}
