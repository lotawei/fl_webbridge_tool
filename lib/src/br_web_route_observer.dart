import 'package:flutter/material.dart';

import 'br_web_global_log.dart';

/// 自动追踪所有路由 push/pop/replace —— 零侵入，只需注册到 MaterialApp.navigatorObservers
///
/// 用法：
/// ```dart
/// MaterialApp(
///   navigatorObservers: [BRWebRouteObserver()],
///   ...
/// )
/// ```
///
/// 同时支持 RouteAware —— 任何 mixin RouteAware 的页面订阅后，
/// 当页面 show/hide 时自动记录：
///
/// ```dart
/// class MyPageState extends State<MyPage> with RouteAware {
///   @override
///   void didChangeDependencies() {
///     super.didChangeDependencies();
///     BRWebRouteObserver.of(context).subscribe(this, ModalRoute.of(context)!);
///   }
///   @override void didPush() => BRWebGlobalLog.instance.native('页面进入', detail: 'MyPage');
///   @override void didPopNext() => BRWebGlobalLog.instance.native('页面返回', detail: 'MyPage');
/// }
/// ```
class BRWebRouteObserver extends RouteObserver<ModalRoute<dynamic>> {
  BRWebRouteObserver();

  static BRWebRouteObserver of(BuildContext context) {
    final observer = context
        .dependOnInheritedWidgetOfExactType<_BRWebRouteObserverScope>();
    assert(observer != null, 'BRWebRouteObserver not found in widget tree');
    return observer!.observer;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final name = _routeName(route);
    BRWebGlobalLog.instance.routePush(name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    final name = _routeName(route);
    BRWebGlobalLog.instance.routePop(name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      final name = _routeName(newRoute);
      BRWebGlobalLog.instance.native('路由 replace', detail: name);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    final name = _routeName(route);
    BRWebGlobalLog.instance.native('路由 remove', detail: name);
  }

  @override
  void didStartUserGesture(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didStartUserGesture(route, previousRoute);
    final name = _routeName(route);
    BRWebGlobalLog.instance.native('手势返回开始', detail: name);
  }

  /// 生成一个 InheritedWidget 用于 RouteAware 订阅
  Widget scope(Widget child) => _BRWebRouteObserverScope(observer: this, child: child);

  String _routeName(Route<dynamic> route) {
    final settings = route.settings;
    if (settings.name != null && settings.name!.isNotEmpty) {
      return settings.name!;
    }
    final type = route.runtimeType.toString();
    final className = type.replaceAll(RegExp(r'_+'), '').replaceAll('Route', '');
    return className.isNotEmpty ? className : type;
  }
}

class _BRWebRouteObserverScope extends InheritedWidget {
  const _BRWebRouteObserverScope({required this.observer, required super.child});
  final BRWebRouteObserver observer;

  @override
  bool updateShouldNotify(_BRWebRouteObserverScope oldWidget) => false;
}
