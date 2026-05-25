import 'package:fl_webbridge_tool/fl_webbridge_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses BR_Web bridge message from map args', () {
    final message = BRWebBridgeMessage.fromArgs([
      {
        'id': 'request_1',
        'action': 'device.camera.takePhoto',
        'params': {'quality': 80},
      },
    ]);

    expect(message.id, 'request_1');
    expect(message.action, 'device.camera.takePhoto');
    expect(message.params['quality'], 80);
  });
}
