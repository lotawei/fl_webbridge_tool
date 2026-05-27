import 'dart:async';
import 'package:fl_webbridge_tool/fl_webbridge_tool.dart';
import 'package:flutter/material.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      MCPToolkitBinding.instance
        ..initialize()
        ..initializeFlutterToolkit();

  BRWebNavigator.register('/h1', const BRWebRouteConfig(
    url: 'assets/h5/demo.html', title: 'H1 首页',
  ));
  BRWebNavigator.register('/h2', const BRWebRouteConfig(
    url: 'assets/h5/demo.html', title: 'H2 详情',
  ));
  BRWebNavigator.register('/vue', BRWebRouteConfig(
    url: 'http://172.16.2.158:5173',
    title: 'Vue3 演示',
    initialData: BRWebInitialData(
      accessToken: 'demo_token_vue',
      userData: {'id': '1001', 'name': 'lotawei'},
      lang: 'zh',
    ),
  ));

  runApp(const DemoApp());
    },
    (error, stack) =>
        MCPToolkitBinding.instance.handleZoneError(error, stack),
  );
}

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});
  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  final List<Widget?> _pages = List<Widget?>.filled(3, null);
  int _index = 0;
  bool _tabBarVisible = true;

  @override
  void initState() {
    super.initState();
    BRWebGlobalLog.instance.native('App started, logger ready');
  }

  @override
  Widget build(BuildContext context) {
    _pages[0] ??= NativeHomePage(onOpenWeb: () => _updateIndex(1));
    _pages[1] ??= _buildBRWebTab();
    _pages[2] ??= const BRWebGlobalLogPage(maxEntries: 300);

    final routeObserver = BRWebRouteObserver();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BR_Web Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      navigatorObservers: [routeObserver],
      builder: (context, child) => routeObserver.scope(child!),
      home: Scaffold(
        body: IndexedStack(
          index: _index,
          children: List.generate(
              _pages.length, (i) => _pages[i] ?? const SizedBox.shrink()),
        ),
        bottomNavigationBar: _tabBarVisible
            ? BRWebLoggableBottomBar(
                selectedIndex: _index,
                onTabChanged: (from, to, _) => setState(() => _index = to),
                tabs: const [
                  ('native', '原生', Icons.home_outlined),
                  ('web', 'BR_Web', Icons.web_asset),
                  ('logs', '日志', Icons.receipt_long),
                ],
              )
            : null,
      ),
    );
  }

  void _updateIndex(int newIndex) {
    setState(() => _index = newIndex);
  }

  Widget _buildBRWebTab() {
    return BRWebContainerPage(
      url: 'http://172.16.2.158:5173',
      title: 'Vue3 Demo',
      logger: BRWebGlobalLog.adapter,
      initialData: BRWebInitialData(
        accessToken: 'demo_token_vue',
        userData: {'id': '1001', 'name': 'lotawei'},
        lang: 'zh',
        extra: {'appVersion': '1.0.0', 'systemVersion': 'iOS 18.0'},
      ),
      onUiRequest: (action, params) {
        if (action == 'hideTabBar') {
          setState(() => _tabBarVisible = false);
        } else if (action == 'showTabBar') {
          setState(() => _tabBarVisible = true);
        }
      },
    );
  }
}

class NativeHomePage extends StatelessWidget {
  const NativeHomePage({super.key, required this.onOpenWeb});
  final VoidCallback onOpenWeb;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter 壳')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('通用 BR_Web 容器方案',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          const Text('底部 TabBar 由 Flutter 承载，网页页面作为业务容器嵌入。'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              BRWebGlobalLog.instance.native('用户点击', detail: '打开 BR_Web 容器');
              onOpenWeb();
            },
            icon: const Icon(Icons.open_in_browser),
            label: const Text('打开 BR_Web 容器 (Vue3)'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              BRWebGlobalLog.instance.native('用户点击', detail: '通过 Navigator 打开 H2');
              BRWebNavigator.push(context, '/h2');
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('通过 Navigator 打开 H2'),
          ),
        ],
      ),
    );
  }
}
