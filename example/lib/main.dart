import 'package:fl_webbridge_tool/fl_webbridge_tool.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

late final BRWebResourceManager resourceManager;
late final WorkOrderManager workOrderManager;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sysInfo = await BRWebSystemInfo.collect();
  DefaultBRWebCapabilityHandler.systemInfo = sysInfo;

  resourceManager = BRWebResourceManager();
  await resourceManager.init();

  workOrderManager = WorkOrderManager();
  await workOrderManager.init();
  await workOrderManager.seedIfEmpty();

  BRWebNavigator.register('/h1', const BRWebRouteConfig(
    initialFile: 'assets/h5/demo.html', title: 'H1 首页',
  ));
  BRWebNavigator.register('/vue', const BRWebRouteConfig(
    url: 'http://localhost:5173', title: 'Vue3 演示 (dev)',
  ));

  runApp(const DemoApp());
}

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});
  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  final List<String> _logs = <String>[];
  int _index = 0;
  bool _tabBarVisible = true;
  late final CallbackBRWebLogger _logger;
  late final DefaultBRWebCapabilityHandler _handler;

  @override
  void initState() {
    super.initState();
    _logger = CallbackBRWebLogger(onLog: (entry) => _appendLog(entry.toString()));
    _handler = DefaultBRWebCapabilityHandler();

    final monitor = BRWebNetworkMonitor(logger: _logger);
    monitor.start();
    _handler.networkMonitor = monitor;
    _handler.resourceManager = resourceManager;
    _handler.workOrderManager = workOrderManager;

    _handler.onSetTitle = (t) => _logger.native('setTitle', detail: t);
    _handler.onUiRequest = (action, params) {
      _logger.uiRequest(action, params);
      if (action == 'hideTabBar') setState(() => _tabBarVisible = false);
      if (action == 'showTabBar') setState(() => _tabBarVisible = true);
    };

    _logger.native('App started', detail: 'resource=${resourceManager.activeVersion}');
  }

  void _appendLog(String message) {
    final t = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';
    _logs.insert(0, '$t  $message');
    if (_logs.length > 200) _logs.removeLast();
    if (mounted) setState(() {});
  }

  void _clearLogs() {
    _logs.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)), useMaterial3: true),
      home: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            _buildNativeTab(),
            // ── 离线资源包模式 ──
            BRWebContainerPage(
              initialFile: 'assets/vuedemo/index.html',  // 离线 Vue 应用
              title: 'BR_Web (离线 Vue)',
              logger: _logger,
              capabilityHandler: BRWebDevGuard(inner: _handler, logger: _logger),
              initialData: BRWebInitialData(
                accessToken: 'demo_token', userData: {'id': '1001', 'name': '张三'}, lang: 'zh',
                extra: {'resourceVersion': resourceManager.activeVersion},
              ),
            ),
            LogPage(logs: _logs, onClear: _clearLogs),
          ],
        ),
        bottomNavigationBar: _tabBarVisible
            ? NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (v) => setState(() => _index = v),
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home_outlined), label: '原生'),
                  NavigationDestination(icon: Icon(Icons.web_asset), label: 'BR_Web'),
                  NavigationDestination(icon: Icon(Icons.receipt_long), label: '日志'),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildNativeTab() {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter 壳')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('通用 BR_Web 容器方案', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        _buildResourceSection(),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => setState(() => _index = 1),
          icon: const Icon(Icons.open_in_browser),
          label: Text('打开 BR_Web (离线资源 v${resourceManager.activeVersion ?? "builtin"})'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => BRWebContainerPage(
                  url: 'http://localhost:5173',
                  title: 'Vue3 演示 (dev)',
                  capabilityHandler: BRWebDevGuard(inner: _handler, logger: _logger),
                  logger: _logger,
                ),
              ),
            );
          },
          icon: const Icon(Icons.developer_mode),
          label: const Text('Vue3 Dev Server (hot reload)'),
        ),
      ]),
    );
  }

  Widget _buildResourceSection() {
    return StatefulBuilder(
      builder: (context, setLocalState) => Card(
        child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📦 资源包管理', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('当前: v${resourceManager.activeVersion ?? "builtin"}'),
            Text('已安装: ${resourceManager.installedVersions.isEmpty ? "无" : resourceManager.installedVersions.map((v) => "v$v").join(", ")}'),
            if (resourceManager.isDownloading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: resourceManager.downloadProgress / 100),
              Text('下载中: ${resourceManager.downloadProgress.toInt()}%', style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: resourceManager.isDownloading ? null : () async {
                final r = await resourceManager.checkUpdate();
                _logger.native('检查更新', detail: r.toString());
                if (!mounted) return;
                if (!context.mounted) return;
                if (r['hasUpdate'] == true) {
                  showDialog(
                    context: context, builder: (_) => AlertDialog(
                      title: Text('发现新版本 v${r['latestVersion']}'),
                      content: Text('${r['releaseNotes'] ?? ''}${r['forceUpdate'] == true ? '\n\n(强制更新)' : ''}'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('以后再说')),
                        FilledButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            final u = await resourceManager.startUpdate();
                            _logger.native('更新', detail: u.toString());
                            setLocalState(() {});
                            if (u['ok'] == true) {
                              // 重新加载 BR_Web Tab
                              setState(() {});
                            }
                          },
                          child: const Text('立即更新'),
                        ),
                      ],
                    ),
                  );
                }
              },
              icon: const Icon(Icons.system_update_alt, size: 16),
              label: const Text('检查更新'),
            ),
          ],
        )),
      ),
    );
  }
}

class LogPage extends StatefulWidget {
  const LogPage({super.key, required this.logs, this.onClear});
  final List<String> logs;
  final VoidCallback? onClear;
  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  final _filterCtrl = TextEditingController();
  String _filter = '';

  List<String> get _filtered =>
      _filter.isEmpty
          ? widget.logs
          : widget.logs
              .where((l) => l.toLowerCase().contains(_filter.toLowerCase()))
              .toList();

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  void _copyAll() {
    Clipboard.setData(ClipboardData(text: widget.logs.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制 ${widget.logs.length} 条日志'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _copyOne(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制'), duration: Duration(milliseconds: 800)),
    );
  }

  Future<void> _confirmClear(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('清空日志'),
        content: Text('确定清除全部 ${widget.logs.length} 条日志吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok == true) widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text('全链路日志 (${list.length}/${widget.logs.length})'),
        actions: [
          if (widget.onClear != null)
            IconButton(
              tooltip: '清空日志',
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => _confirmClear(context),
            ),
          IconButton(
            tooltip: '复制全部',
            icon: const Icon(Icons.copy_all),
            onPressed: _copyAll,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _filterCtrl,
              decoration: InputDecoration(
                hintText: '过滤日志...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _filterCtrl.clear();
                          setState(() => _filter = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text(
                      '无匹配日志',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8,vertical: 4),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) => InkWell(
                      onLongPress: () => _copyOne(list[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: 
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.black),
                          ),
                          child:
                        SelectableText(
                          list[i],
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      )),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
