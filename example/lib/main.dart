import 'package:fl_webbridge_tool/fl_webbridge_tool.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  int _index = 0;

  void _appendLog(String message) {
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    void updateLogs() {
      if (!mounted) {
        return;
      }
      _logs.insert(0, '$time  $message');
      if (_logs.length > 80) {
        _logs.removeLast();
      }
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(updateLogs);
      });
      return;
    }

    setState(updateLogs);
  }

  @override
  Widget build(BuildContext context) {
    _pages[_index] ??= _buildPage(_index);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BR_Web Container Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: IndexedStack(
          index: _index,
          children: List.generate(
            _pages.length,
            (index) => _pages[index] ?? const SizedBox.shrink(),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: '原生'),
            NavigationDestination(icon: Icon(Icons.web_asset), label: 'BR_Web'),
            NavigationDestination(icon: Icon(Icons.receipt_long), label: '日志'),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(int index) {
    return switch (index) {
      0 => NativeHomePage(onOpenWeb: () => setState(() => _index = 1)),
      1 => BRWebContainerPage(
        title: 'BR_Web 容器',
        initialFile: 'assets/h5/demo.html',
        onLifecycle: (event) {
          final suffix =
              event.message ?? event.url ?? event.progress?.toString() ?? '';
          _appendLog('${event.type.name} $suffix');
        },
        onCreated: (bridge, controller) {
          _appendLog('bridge ready');
        },
      ),
      2 => LogPage(logs: _logs),
      _ => const SizedBox.shrink(),
    };
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
          const Text(
            '底部 TabBar 由 Flutter 承载，网页页面作为业务容器嵌入。能力通过 package 暴露，可被其它 Flutter 工程按需接入和扩展。',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onOpenWeb,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('打开 BR_Web 容器'),
          ),
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
      appBar: AppBar(title: const Text('生命周期 / API 日志')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: logs.length,
        separatorBuilder: (_, _) => const Divider(height: 16),
        itemBuilder: (context, index) => Text(logs[index]),
      ),
    );
  }
}
