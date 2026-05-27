import 'dart:convert';

/// 注入到所有 H5 页面的通用初始数据
///
/// Native 通过 [BRWebContainerPage.initialData] 传入，
/// 插件在页面加载前注入为 `window.__BR_Data__`，
/// H5 无需调用 bridge 即可读取。
class BRWebInitialData {
  const BRWebInitialData({
    this.accessToken,
    this.userData,
    this.lang,
    this.extra,
  });

  /// 用户 Access Token
  final String? accessToken;

  /// 用户信息（JSON 可序列化）
  final Map<String, dynamic>? userData;

  /// 当前语言，如 zh-CN
  final String? lang;

  /// 扩展字段：系统版本、App 版本、渠道等
  final Map<String, dynamic>? extra;

  Map<String, dynamic> toJson() => {
        if (accessToken != null) 'accessToken': accessToken,
        if (userData != null) 'user': userData,
        if (lang != null) 'lang': lang,
        ...?extra,
      };

  /// 生成可直接注入到 HTML 的 JS 脚本
  String toJsScript() {
    const jsJson = JsonEncoder.withIndent(null);
    return 'window.__BR_Data__ = ${jsJson.convert(toJson())};';
  }

  @override
  String toString() => 'BRWebInitialData(token=${accessToken != null ? '***' : 'null'}, user=$userData, lang=$lang)';
}
