import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'br_web_logger.dart';

/// 通用设备 / 系统信息
class BRWebSystemInfo {
  const BRWebSystemInfo({
    required this.deviceModel,
    required this.os,
    required this.osVersion,
    required this.appVersion,
    required this.buildNumber,
    this.deviceId,
    this.isEmulator,
    this.locale,
  });

  final String deviceModel;
  final String os;
  final String osVersion;
  final String appVersion;
  final String buildNumber;
  final String? deviceId;
  final bool? isEmulator;
  final String? locale;

  Map<String, dynamic> toJson() => {
        'deviceModel': deviceModel,
        'os': os,
        'osVersion': osVersion,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        if (deviceId != null) 'deviceId': deviceId,
        if (isEmulator != null) 'isEmulator': isEmulator,
        if (locale != null) 'locale': locale,
      };

  @override
  String toString() =>
      '$deviceModel / $os $osVersion / app v$appVersion($buildNumber)';

  /// 自动收集当前设备信息
  static Future<BRWebSystemInfo> collect({BRWebLogger? logger}) async {
    final devicePlugin = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    String deviceModel;
    String os;
    String osVersion;
    String? deviceId;
    bool? isEmulator;

    if (Platform.isIOS) {
      final info = await devicePlugin.iosInfo;
      deviceModel = info.model;
      os = 'iOS';
      osVersion = info.systemVersion;
      deviceId = info.identifierForVendor;
      isEmulator = !info.isPhysicalDevice;
    } else if (Platform.isAndroid) {
      final info = await devicePlugin.androidInfo;
      deviceModel = info.model;
      os = 'Android';
      osVersion = info.version.release;
      deviceId = info.id;
      isEmulator = info.isPhysicalDevice ? false : true;
    } else if (kIsWeb) {
      deviceModel = 'Web';
      os = 'Browser';
      osVersion = '';
    } else {
      deviceModel = Platform.operatingSystem;
      os = Platform.operatingSystem;
      osVersion = Platform.operatingSystemVersion;
    }

    final info = BRWebSystemInfo(
      deviceModel: deviceModel,
      os: os,
      osVersion: osVersion,
      appVersion: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      deviceId: deviceId,
      isEmulator: isEmulator,
    );

    logger?.native('System info collected', detail: info.toString());
    return info;
  }
}
