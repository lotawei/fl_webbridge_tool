import 'package:flutter/material.dart';

import 'br_web_container_page.dart';
import 'br_web_global_log.dart';
import 'br_web_initial_data.dart';

/// 一个 WebView 页面的路由配置
class BRWebRouteConfig {
  const BRWebRouteConfig({
    this.url,
    this.initialFile,
    this.title,
    this.showAppBar = true,
    this.initialData,
  }) : assert(url != null || initialFile != null, 'url or initialFile is required');

  /// H5 页面远程 URL（如 https://domain.com/h1 或 http://localhost:5173）
  final String? url;

  /// 本地 asset 文件路径（如 assets/h5/demo.html），与 [url] 二选一
  final String? initialFile;

  /// 默认标题（H5 可通过 bridge 覆盖）
  final String? title;

  /// 是否显示 AppBar
  final bool showAppBar;

  /// 注入的通用数据
  final BRWebInitialData? initialData;
}

/// 原生 Flutter 页面的路由构造器
typedef BRWebNativeRouteBuilder = Widget Function(
  BuildContext context,
  Map<String, dynamic>? params,
);

/// 路由注册表 + 页面跳转管理
class BRWebNavigator {
  BRWebNavigator._();

  static final Map<String, BRWebRouteConfig> _routes = {};
  static final Map<String, BRWebNativeRouteBuilder> _nativeRoutes = {};

  static void register(String name, BRWebRouteConfig config) {
    _routes[name] = config;
  }

  static void registerNative(String name, BRWebNativeRouteBuilder builder) {
    _nativeRoutes[name] = builder;
  }

  static BRWebRouteConfig? lookup(String name) => _routes[name];

  static Future<T?> push<T extends Object?>(
    BuildContext context,
    String routeName, {
    Map<String, dynamic>? params,
    BRWebInitialData? initialDataOverride,
    String? titleOverride,
    bool? showAppBarOverride,
  }) {
    final webConfig = _routes[routeName];
    if (webConfig != null) {
      return Navigator.of(context).push(
        MaterialPageRoute<T>(
          settings: RouteSettings(name: routeName),
          builder: (_) => BRWebContainerPage(
            url: webConfig.url,
            initialFile: webConfig.initialFile,
            title: titleOverride ?? webConfig.title,
            showAppBar: showAppBarOverride ?? webConfig.showAppBar,
            initialData: initialDataOverride ?? webConfig.initialData,
            logger: BRWebGlobalLog.adapter,
          ),
        ),
      );
    }

    final nativeBuilder = _nativeRoutes[routeName];
    if (nativeBuilder != null) {
      return Navigator.of(context).push(
        MaterialPageRoute<T>(
          settings: RouteSettings(name: routeName),
          builder: (_) => nativeBuilder(context, params),
        ),
      );
    }

    throw ArgumentError('Route "$routeName" is not registered.');
  }

  static void pop<T extends Object?>(BuildContext context, [T? result]) {
    Navigator.of(context).maybePop<T>(result);
  }
}
