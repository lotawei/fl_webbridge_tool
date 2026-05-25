import 'package:flutter_test/flutter_test.dart';

import 'package:fl_webbridge_tool_example/main.dart';

void main() {
  testWidgets('shows native shell entry', (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());

    expect(find.text('Flutter 壳'), findsOneWidget);
    expect(find.text('通用 BR_Web 容器方案'), findsOneWidget);
  });
}
