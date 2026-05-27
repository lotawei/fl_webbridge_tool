import 'package:flutter/material.dart';

import 'br_web_global_log.dart';
import 'br_web_logger.dart';

// ═══════════════════════════════════════════════════════════════
// 通用日志组件 —— 零侵入接入项目
// ═══════════════════════════════════════════════════════════════

/// Tab 自动日志导航栏 —— 替代 NavigationBar，切换时自动写全局日志
///
/// 用法：
/// ```dart
/// BRWebLoggableBottomBar(
///   selectedIndex: _index,
///   onTabChanged: (from, to, label) {
///     setState(() => _index = to);
///     // 你的业务逻辑...
///   },
///   tabs: const [
///     ('home', '首页', Icons.home_outlined),
///     ('web', '业务', Icons.web_asset),
///     ('logs', '日志', Icons.receipt_long),
///   ],
/// )
/// ```
class BRWebLoggableBottomBar extends StatelessWidget {
  const BRWebLoggableBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
    required this.tabs,
    this.indicatorShape,
    this.height,
    this.labelBehavior,
  });

  final int selectedIndex;

  /// 当 tab 切换时回调 (fromIndex, toIndex, tabLabel)
  final void Function(int from, int to, String label) onTabChanged;

  /// 每个 tab = (id, label, icon)
  final List<(String id, String label, IconData icon)> tabs;

  final ShapeBorder? indicatorShape;
  final double? height;
  final NavigationDestinationLabelBehavior? labelBehavior;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      indicatorShape: indicatorShape,
      height: height,
      labelBehavior: labelBehavior,
      onDestinationSelected: (to) {
        if (to == selectedIndex) return;
        final from = selectedIndex;
        final label = tabs[to].$2;
        BRWebGlobalLog.instance.tabSwitch(from, to,
            labels: tabs.map((t) => t.$2).join('/'));
        onTabChanged(from, to, label);
      },
      destinations: tabs
          .map((t) => NavigationDestination(icon: Icon(t.$3), label: t.$2))
          .toList(),
    );
  }
}

/// 全局日志查看页 —— 工业级终端风格，每条可复制，颜色编码
///
/// 用法：
/// ```dart
/// BRWebGlobalLogPage(),  // 一行搞定
/// ```
class BRWebGlobalLogPage extends StatefulWidget {
  const BRWebGlobalLogPage({
    super.key,
    this.filter,
    this.maxEntries = 500,
  });

  /// 类型筛选（null = 全部）
  final Set<BRWebLogType>? filter;

  /// 最大保留条目数
  final int maxEntries;

  @override
  State<BRWebGlobalLogPage> createState() => _BRWebGlobalLogPageState();
}

class _BRWebGlobalLogPageState extends State<BRWebGlobalLogPage> {
  BRWebLogType? _activeFilter;
  String _search = '';

  List<BRWebLogEntry> get _filtered {
    var entries = BRWebGlobalLog.instance.entries;
    if (_activeFilter != null) {
      entries = entries.where((e) => e.type == _activeFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      entries = entries.where((e) => e.toString().toLowerCase().contains(q)).toList();
    }
    return entries.reversed.take(widget.maxEntries).toList();
  }

  @override
  void initState() {
    super.initState();
    BRWebGlobalLog.instance.addListener(_onLog);
  }

  @override
  void dispose() {
    BRWebGlobalLog.instance.removeListener(_onLog);
    super.dispose();
  }

  void _onLog(BRWebLogEntry entry) {
    if (!mounted) return;
    setState(() {});
  }

  // ─── 颜色映射 ───
  static Color _colorFor(BRWebLogType type) {
    return switch (type) {
      BRWebLogType.native => const Color(0xFF6366F1), // indigo
      BRWebLogType.lifecycle => const Color(0xFF0EA5E9), // sky
      BRWebLogType.request => const Color(0xFF22C55E), // green
      BRWebLogType.response => const Color(0xFF10B981), // emerald
      BRWebLogType.console => const Color(0xFFF59E0B), // amber
      BRWebLogType.error => const Color(0xFFEF4444), // red
      BRWebLogType.bridgeError => const Color(0xFFF97316), // orange
      BRWebLogType.ui => const Color(0xFF8B5CF6), // violet
    };
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filtered;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('全链路日志 (${entries.length})'),
        actions: [
          if (_activeFilter != null)
            TextButton(
              onPressed: () => setState(() => _activeFilter = null),
              child: const Text('全部'),
            ),
          PopupMenuButton<BRWebLogType>(
            icon: const Icon(Icons.filter_list),
            onSelected: (type) => setState(() => _activeFilter = type),
            itemBuilder: (_) => BRWebLogType.values.map((type) {
              final label = switch (type) {
                BRWebLogType.lifecycle => '📡 生命周期',
                BRWebLogType.request => '⬆️ Bridge 请求',
                BRWebLogType.response => '⬇️ Bridge 响应',
                BRWebLogType.console => '📜 Console',
                BRWebLogType.error => '💥 JS 错误',
                BRWebLogType.bridgeError => '🔌 Bridge 异常',
                BRWebLogType.ui => '🎨 UI 控制',
                BRWebLogType.native => '🦴 原生事件',
              };
              return PopupMenuItem(value: type, child: Text(label));
            }).toList(),
          ),
          IconButton(
            tooltip: '清空',
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              BRWebGlobalLog.instance.clear();
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索日志...',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _search = ''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          // 日志列表
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('暂无日志', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: entries.length,
                    itemBuilder: (ctx, i) => _buildEntry(ctx, entries[i], isDark),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntry(BuildContext context, BRWebLogEntry entry, bool isDark) {
    final color = _colorFor(entry.type);
    final time = '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
        '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
        '${entry.timestamp.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isDark
            ? color.withValues(alpha: 0.06)
            : color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () {
            // 双击可选择复制 —— 通过 Scaffold 的 snackbar 提示
          },
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 左侧颜色条
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 缩进箭头
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Icon(Icons.chevron_right, size: 12, color: color),
                ),
                const SizedBox(width: 4),
                // 内容
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: SelectableText.rich(
                      _buildLine(entry, time, color),
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Menlo',
                        height: 1.4,
                        color: isDark ? Colors.white70 : Colors.grey.shade800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextSpan _buildLine(BRWebLogEntry entry, String time, Color color) {
    final typeStr = switch (entry.type) {
      BRWebLogType.native => 'NAT',
      BRWebLogType.lifecycle => 'LIF',
      BRWebLogType.request => 'REQ',
      BRWebLogType.response => 'RES',
      BRWebLogType.console => 'LOG',
      BRWebLogType.error => 'ERR',
      BRWebLogType.bridgeError => 'BRK',
      BRWebLogType.ui => 'UIR',
    };

    final parts = <InlineSpan>[];
    parts.add(TextSpan(
      text: '$time  ',
      style: TextStyle(color: Colors.grey, fontSize: 10),
    ));
    parts.add(TextSpan(
      text: typeStr,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 10,
      ),
    ));
    parts.add(const TextSpan(text: '  ', style: TextStyle(fontSize: 10)));

    if (entry.action != null) {
      parts.add(TextSpan(
        text: '[${entry.action}]  ',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ));
    }

    parts.add(TextSpan(
      text: entry.message ?? '',
      style: TextStyle(
        fontWeight: entry.action == null ? FontWeight.w400 : FontWeight.w300,
      ),
    ));

    if (entry.detail != null && entry.detail!.isNotEmpty) {
      parts.add(TextSpan(
        text: '  ${entry.detail}',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 10,
        ),
      ));
    }

    return TextSpan(children: parts);
  }
}
