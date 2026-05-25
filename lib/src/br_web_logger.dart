import 'br_web_bridge_message.dart';
import 'br_web_lifecycle.dart';

abstract interface class BRWebLogger {
  void bridgeRequest(BRWebBridgeMessage message);

  void bridgeResponse(String id, Object? response);

  void lifecycle(BRWebLifecycleEvent event);
}

class DebugBRWebLogger implements BRWebLogger {
  const DebugBRWebLogger();

  @override
  void bridgeRequest(BRWebBridgeMessage message) {
    // ignore: avoid_print
    print(
      '[BR_Web][request] ${message.id} ${message.action} ${message.params}',
    );
  }

  @override
  void bridgeResponse(String id, Object? response) {
    // ignore: avoid_print
    print('[BR_Web][response] $id $response');
  }

  @override
  void lifecycle(BRWebLifecycleEvent event) {
    // ignore: avoid_print
    print(
      '[BR_Web][lifecycle] ${event.type.name} url=${event.url} message=${event.message}',
    );
  }
}
