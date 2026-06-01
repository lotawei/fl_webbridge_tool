import 'package:fl_webbridge_tool/fl_webbridge_tool.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 收集系统信息
  final sysInfo = await BRWebSystemInfo.collect();
  DefaultBRWebCapabilityHandler.systemInfo = sysInfo;

  // 注册路由
  BRWebNavigator.register(
    '/h1',
    const BRWebRouteConfig(url: 'assets/h5/demo.html', title: 'H1 首页'),
  );
  BRWebNavigator.register(
    '/h2',
    const BRWebRouteConfig(url: 'assets/h5/demo.html', title: 'H2 详情'),
  );

  runApp(const DemoApp());
}

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});
  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  final List<String> _logs = <String>[];
  final List<Widget?> _pages = List<Widget?>.filled(3, null);
  final BRWebRouteObserver _routeObserver = BRWebRouteObserver();
  int _index = 0;
  bool _tabBarVisible = true;
  late final CallbackBRWebLogger _logger;

  @override
  void initState() {
    super.initState();
    _logger = CallbackBRWebLogger(
      onLog: (entry) => _appendLog(entry.toString()),
    );
    _logger.native('App started');
  }

  void _appendLog(String message) {
    void updateLogs() {
      if (!mounted) return;
      final now = DateTime.now();
      final t =
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}';
      _logs.insert(0, '$t  $message');
      if (_logs.length > 200) _logs.removeLast();
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(updateLogs));
      return;
    }
    setState(updateLogs);
  }

  @override
  Widget build(BuildContext context) {
    _pages[0] ??= _buildPage(0);
    _pages[1] ??= _buildPage(1);
    _pages[2] ??= LogPage(logs: _logs);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BR_Web Demo',
      navigatorObservers: [_routeObserver],
      builder: (context, child) =>
          _routeObserver.scope(child ?? const SizedBox.shrink()),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: IndexedStack(
          index: _index,
          children: List.generate(
            _pages.length,
            (i) => _pages[i] ?? const SizedBox.shrink(),
          ),
        ),
        bottomNavigationBar: _tabBarVisible
            ? NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (v) => setState(() => _index = v),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    label: '原生',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.web_asset),
                    label: 'BR_Web',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long),
                    label: '日志',
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildPage(int index) {
    return switch (index) {
      0 => NativeHomePage(onOpenWeb: () => setState(() => _index = 1)),
      1 => BRWebContainerPage(
        url: 'http://localhost:5173/',
        title: 'Vue3 Demo',
        logger: _logger,
        initialData: BRWebInitialData(
          accessToken: 'demo_token_vue',
          userData: {'id': '1001', 'name': 'lotawei'},
          lang: 'zh',
          extra: {'appVersion': '1.0.0'},
        ),
        capabilityHandler: BRWebDevGuard(
          inner: _buildHandler(),
          logger: _logger,
        ),
        onUiRequest: _handleUiRequest,
        onTitleRequest: (title) => _logger.native('setTitle', detail: title),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  void _handleUiRequest(String action, Map<String, dynamic>? params) {
    _logger.uiRequest(action, params);
    final nextVisible = switch (action) {
      'hideTabBar' => false,
      'showTabBar' => true,
      _ => _tabBarVisible,
    };
    if (nextVisible == _tabBarVisible) return;
    setState(() => _tabBarVisible = nextVisible);
  }

  DefaultBRWebCapabilityHandler _buildHandler() {
    final handler = DefaultBRWebCapabilityHandler();
    // 网络监听
    final monitor = BRWebNetworkMonitor(
      logger: _logger,
      onChanged: (status) {
        _logger.native('Network changed', detail: status);
      },
    );
    monitor.start();
    handler.networkMonitor = monitor;
    return handler;
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
          Text(
            '通用 BR_Web 容器方案',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text('底部 TabBar 由 Flutter 承载，网页页面作为业务容器嵌入。'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onOpenWeb,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('打开 BR_Web Vue3 Demo'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfilePage())),
            icon: const Icon(Icons.info_outline),
            label: const Text('查看设备/系统信息'),
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设备 & 系统信息')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _row(
            '设备型号',
            DefaultBRWebCapabilityHandler.systemInfo?.deviceModel ?? 'N/A',
          ),
          _row(
            '系统',
            '${DefaultBRWebCapabilityHandler.systemInfo?.os ?? ''} ${DefaultBRWebCapabilityHandler.systemInfo?.osVersion ?? 'N/A'}',
          ),
          _row(
            'App 版本',
            DefaultBRWebCapabilityHandler.systemInfo?.appVersion ?? 'N/A',
          ),
          _row(
            'Build',
            DefaultBRWebCapabilityHandler.systemInfo?.buildNumber ?? 'N/A',
          ),
          _row(
            '模拟器',
            '${DefaultBRWebCapabilityHandler.systemInfo?.isEmulator ?? false}',
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class LogPage extends StatelessWidget {
  const LogPage({super.key, required this.logs});
  final List<String> logs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('全链路日志 (${logs.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () => logs.clear(),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: logs.length,
        itemBuilder: (ctx, i) => Text(
          logs[i],
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        ),
      ),
    );
  }
}
