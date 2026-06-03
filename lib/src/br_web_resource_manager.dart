import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'br_web_logger.dart';

/// 资源包版本信息
class ResourceVersion {
  const ResourceVersion({
    required this.version,
    required this.path,
    this.sizeBytes = 0,
    this.installedAt,
    this.releaseNotes,
  });

  final String version;
  final String path;
  final int sizeBytes;
  final DateTime? installedAt;
  final String? releaseNotes;

  Map<String, dynamic> toJson() => {
        'version': version,
        'path': path,
        'sizeBytes': sizeBytes,
        'installedAt': installedAt?.toIso8601String(),
        if (releaseNotes != null) 'releaseNotes': releaseNotes,
      };
}

/// 服务端返回的版本信息
class RemoteVersion {
  const RemoteVersion({
    required this.version,
    required this.url,
    this.sizeBytes = 0,
    this.forceUpdate = false,
    this.releaseNotes,
  });

  final String version;
  final String url;
  final int sizeBytes;
  final bool forceUpdate;
  final String? releaseNotes;
}

/// 资源包管理器
class BRWebResourceManager {
  BRWebResourceManager({this.logger});

  final BRWebLogger? logger;

  static const _manifestFile = 'resource_manifest.json';
  static const _resourceDir = 'flutter_resources';

  final Map<String, ResourceVersion> _versions = {};
  String? _activeVersion;

  bool _isDownloading = false;
  String? _downloadingVersion;
  double _downloadProgress = 0;
  String? _latestRemoteVersion;

  bool _initialized = false;

  String? get activeVersion => _activeVersion;
  String? get activePath => _activeVersion != null && _activeVersion != 'builtin'
      ? _versions[_activeVersion]?.path : null;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  List<String> get installedVersions => _versions.keys.toList();

  /// 初始化：扫描已安装版本 + 如果没有任何版本，把 bundled dist 拷贝一份作为 v1.0.0
  Future<void> init() async {
    if (_initialized) return;
    await _loadManifest();

    if (_versions.isEmpty) {
      await _installBundledVersion('1.0.0');
      if (_activeVersion == null || _activeVersion == 'builtin') {
        _activeVersion = '1.0.0';
        await _saveManifest();
      }
    }

    _initialized = true;
    logger?.native('ResourceManager init', detail: '${_versions.length} versions, active=$_activeVersion');
  }

  Map<String, dynamic> getStatus() => {
        'currentVersion': _activeVersion ?? 'builtin',
        'downloading': _isDownloading,
        'downloadProgress': _downloadProgress,
        'downloadingVersion': _downloadingVersion,
        'installedVersions': installedVersions,
        'latestRemoteVersion': _latestRemoteVersion,
        'needUpdate': _latestRemoteVersion != null && _activeVersion != _latestRemoteVersion,
      };

  Future<Map<String, dynamic>> checkUpdate() async {
    final mock = _activeVersion == '2.0.1' ? null : RemoteVersion(
      version: '2.0.1',
      url: 'https://example.com/resources/flutter-h5-v2.0.1.zip',
      sizeBytes: 3 * 1024 * 1024,
      forceUpdate: false,
      releaseNotes: '新增离线资源管理页、性能优化',
    );

    if (mock != null) {
      _latestRemoteVersion = mock.version;
      return {'hasUpdate': true, 'latestVersion': mock.version, 'forceUpdate': mock.forceUpdate, 'sizeBytes': mock.sizeBytes, 'releaseNotes': mock.releaseNotes};
    }
    return {'hasUpdate': false, 'latestVersion': _activeVersion};
  }

  Future<Map<String, dynamic>> startUpdate() async {
    if (_isDownloading) return {'error': 'already downloading'};
    if (_latestRemoteVersion == null) return {'error': 'call checkUpdate first'};

    _isDownloading = true;
    _downloadingVersion = _latestRemoteVersion;
    _downloadProgress = 0;
    logger?.native('Update start', detail: 'v$_latestRemoteVersion');

    try {
      // Mock download with progress
      for (var p = 0; p <= 100; p += 10) {
        await Future.delayed(const Duration(milliseconds: 80));
        _downloadProgress = p.toDouble();
      }

      // "Download complete" — for demo, copy bundled dist again as new version
      await _installBundledVersion(_latestRemoteVersion!);

      // Write a marker to show it's the "updated" version
      final dir = await _resourceDirPath;
      final resourceDir = Directory('$dir/$_latestRemoteVersion');
      final html = await File('${resourceDir.path}/index.html').readAsString();
      await File('${resourceDir.path}/index.html').writeAsString(
        html.replaceFirst('</head>', '<script>document.title="✅ v$_latestRemoteVersion 已更新"</script></head>'),
      );

      _activeVersion = _latestRemoteVersion;
      await _saveManifest();
      _isDownloading = false;
      _downloadProgress = 100;

      logger?.native('Update complete', detail: 'v$_activeVersion');
      return {'ok': true, 'version': _activeVersion};
    } catch (e) {
      _isDownloading = false;
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> cancelUpdate() async {
    _isDownloading = false;
    _downloadingVersion = null;
    _downloadProgress = 0;
    return {'ok': true};
  }

  Future<Map<String, dynamic>> switchTo(String version) async {
    if (!_versions.containsKey(version)) return {'error': 'version $version not installed'};
    _activeVersion = version;
    await _saveManifest();
    return {'ok': true, 'version': version};
  }

  // ========== 内部 ==========
  Future<String> get _resourceDirPath async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/$_resourceDir';
  }

  Future<void> _installBundledVersion(String version) async {
    final base = await _resourceDirPath;
    final targetDir = Directory('$base/$version');
    if (targetDir.existsSync()) return;

    // Copy from Flutter assets (bundled dist)
    final manifestJson = await rootBundle.loadString('AssetManifest.json');
    final assets = (jsonDecode(manifestJson) as Map<String, dynamic>).keys
        .where((k) => k.startsWith('assets/vuedemo/'));

    for (final assetPath in assets) {
      final relativePath = assetPath.replaceFirst('assets/vuedemo/', '');
      final targetFile = File('${targetDir.path}/$relativePath');
      await targetFile.parent.create(recursive: true);
      final bytes = await rootBundle.load(assetPath);
      await targetFile.writeAsBytes(bytes.buffer.asUint8List());
    }

    _versions[version] = ResourceVersion(
      version: version,
      path: targetDir.path,
      sizeBytes: 0,
      installedAt: DateTime.now(),
    );

    logger?.native('Bundled version installed', detail: 'v$version → $targetDir');
  }

  Future<String> get _manifestPath async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/$_manifestFile';
  }

  Future<void> _loadManifest() async {
    try {
      final file = File(await _manifestPath);
      if (!file.existsSync()) { _activeVersion = 'builtin'; return; }
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _activeVersion = json['active'] as String?;
      for (final v in (json['versions'] as List<dynamic>? ?? [])) {
        final rv = ResourceVersion(
          version: v['version'] as String, path: v['path'] as String,
          installedAt: v['installedAt'] != null ? DateTime.parse(v['installedAt'] as String) : null,
        );
        _versions[rv.version] = rv;
      }
    } catch (_) { _activeVersion = 'builtin'; }
  }

  Future<void> _saveManifest() async {
    final json = {'active': _activeVersion, 'versions': _versions.values.map((v) => v.toJson()).toList()};
    final file = File(await _manifestPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(json));
  }
}
