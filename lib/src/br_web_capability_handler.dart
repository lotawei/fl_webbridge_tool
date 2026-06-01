import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'br_web_bridge_message.dart';
import 'br_web_navigator.dart';
import 'br_web_network_monitor.dart';
import 'br_web_permission_helper.dart';
import 'br_web_preview_page.dart'
    show BRWebFileType, BRWebPreviewPage, inferFileType;
import 'br_web_system_info.dart';

abstract interface class BRWebCapabilityHandler {
  Future<Object?> handle(BuildContext context, BRWebBridgeMessage message);
}

class CompositeBRWebCapabilityHandler implements BRWebCapabilityHandler {
  CompositeBRWebCapabilityHandler(this.handlers);

  final List<BRWebCapabilityHandler> handlers;

  @override
  Future<Object?> handle(
    BuildContext context,
    BRWebBridgeMessage message,
  ) async {
    for (final handler in handlers) {
      final result = await handler.handle(context, message);
      if (result != BRWebCapabilityHandlerResult.notHandled) {
        return result;
      }
    }
    throw UnsupportedError(
      'Unsupported BR_Web bridge action: ${message.action}',
    );
  }
}

enum BRWebCapabilityHandlerResult { notHandled }

class DefaultBRWebCapabilityHandler implements BRWebCapabilityHandler {
  DefaultBRWebCapabilityHandler({
    ImagePicker? imagePicker,
    AudioRecorder? recorder,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _recorder = recorder ?? AudioRecorder();

  final ImagePicker _imagePicker;
  final AudioRecorder _recorder;
  String? _recordingPath;
  BRWebNetworkMonitor? _networkMonitor;

  /// H5 通过 bridge 修改页面标题时触发
  void Function(String title)? onSetTitle;

  /// H5 通过 bridge 请求控制原生 UI 时触发
  void Function(String action, Map<String, dynamic>? params)? onUiRequest;

  /// 设置网络监听器（由容器页传入）
  set networkMonitor(BRWebNetworkMonitor? monitor) => _networkMonitor = monitor;

  /// 设置系统信息（App 启动时收集一次）
  static set systemInfo(BRWebSystemInfo info) => _systemInfo = info;

  /// 读取当前系统信息
  static BRWebSystemInfo? get systemInfo => _systemInfo;

  @override
  Future<Object?> handle(BuildContext context, BRWebBridgeMessage message) {
    return switch (message.action) {
      'device.camera.takePhoto' => _takePhoto(context, message),
      'device.camera.pickPhoto' => _pickPhoto(context, message),
      'device.camera.takeVideo' => _takeVideo(context, message),
      'device.camera.pickVideo' => _pickVideo(context, message),
      'device.file.pick' => _pickFile(message),
      'device.file.preview' => _previewFile(context, message),
      'device.file.delete' => _deleteFile(message),
      'device.network.status' => _getNetworkStatus(),
      'device.system.info' => _getSystemInfo(),
      'device.audio.startRecord' => _startRecord(context, message),
      'device.audio.stopRecord' => _stopRecord(),
      'navigation.navigateTo' => _navigateTo(context, message),
      'navigation.goBack' => _navigateBack(context, message),
      'navigation.setTitle' => _setTitleFromH5(message),
      'ui.hideTabBar' => _uiRequest('hideTabBar', message),
      'ui.showTabBar' => _uiRequest('showTabBar', message),
      'container.close' => _close(context, message),
      _ => Future<Object?>.value(BRWebCapabilityHandlerResult.notHandled),
    };
  }

  // ============================================================
  //  拍照（支持 maxSizeKB 文件大小上限，默认 1MB）
  // ============================================================
  Future<Object?> _takePhoto(
    BuildContext context,
    BRWebBridgeMessage message,
  ) async {
    final granted = await BRWebPermissionHelper.ensurePermission(
      permission: Permission.camera,
      context: context,
      permissionName: '相机',
      purpose: '拍照',
    );
    if (!granted) {
      return <String, dynamic>{
        'cancelled': true,
        'reason': 'permission_denied',
      };
    }

    final maxWidth = (message.params['maxWidth'] as num?)?.toDouble();
    final maxHeight = (message.params['maxHeight'] as num?)?.toDouble();
    final maxSizeKB =
        (message.params['maxSizeKB'] as num?)?.toInt() ?? 1024; // 默认 1MB

    final image = await _pickWithMaxSize(
      source: ImageSource.camera,
      maxSizeKB: maxSizeKB,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    if (image == null) {
      return <String, dynamic>{'cancelled': true};
    }

    final file = File(image.path);
    final bytes = await file.length();

    final saveToGallery = message.params['saveToGallery'] as bool? ?? true;
    String? galleryPath;

    if (saveToGallery) {
      galleryPath = await _saveToSystemGallery(image.path);
    }

    return <String, dynamic>{
      'cancelled': false,
      'path': image.path,
      'name': image.name,
      'mimeType': image.mimeType,
      'size': bytes,
      'sizeKB': bytes ~/ 1024,
      'savedToGallery': saveToGallery,
      'galleryPath': galleryPath,
    };
  }

  // ============================================================
  //  从相册选照片（支持 maxSizeKB，默认 1MB）
  // ============================================================
  Future<Object?> _pickPhoto(
    BuildContext context,
    BRWebBridgeMessage message,
  ) async {
    final granted = await BRWebPermissionHelper.ensurePermission(
      permission: Permission.photos,
      context: context,
      permissionName: '相册',
      purpose: '选择照片',
    );
    if (!granted) {
      return <String, dynamic>{
        'cancelled': true,
        'reason': 'permission_denied',
      };
    }

    final maxWidth = (message.params['maxWidth'] as num?)?.toDouble();
    final maxHeight = (message.params['maxHeight'] as num?)?.toDouble();
    final maxSizeKB = (message.params['maxSizeKB'] as num?)?.toInt() ?? 1024;

    final image = await _pickWithMaxSize(
      source: ImageSource.gallery,
      maxSizeKB: maxSizeKB,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    if (image == null) {
      return <String, dynamic>{'cancelled': true};
    }

    final file = File(image.path);
    final bytes = await file.length();

    return <String, dynamic>{
      'cancelled': false,
      'path': image.path,
      'name': image.name,
      'mimeType': image.mimeType,
      'size': bytes,
      'sizeKB': bytes ~/ 1024,
    };
  }

  /// 渐进压降策略：从高质量开始，逐级降低直到满足 maxSizeKB
  Future<XFile?> _pickWithMaxSize({
    required ImageSource source,
    required int maxSizeKB,
    double? maxWidth,
    double? maxHeight,
  }) async {
    for (final quality in <int>[85, 60, 40, 20, 10]) {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: quality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
      if (image == null) return null;

      final sizeKB = await File(image.path).length() ~/ 1024;
      if (sizeKB <= maxSizeKB || quality == 10) {
        return image; // 已满足大小上限 或 已到极限质量
      }
    }
    return null;
  }

  // ============================================================
  //  录像
  // ============================================================
  Future<Object?> _takeVideo(
    BuildContext context,
    BRWebBridgeMessage message,
  ) async {
    final cameraGranted = await BRWebPermissionHelper.ensurePermission(
      permission: Permission.camera,
      context: context,
      permissionName: '相机',
      purpose: '录像',
    );
    if (!cameraGranted) {
      return <String, dynamic>{
        'cancelled': true,
        'reason': 'camera_permission_denied',
      };
    }

    if (!context.mounted) {
      return <String, dynamic>{
        'cancelled': true,
        'reason': 'context_unmounted',
      };
    }

    final micGranted = await BRWebPermissionHelper.ensurePermission(
      permission: Permission.microphone,
      context: context,
      permissionName: '麦克风',
      purpose: '录像录音',
    );
    if (!micGranted) {
      return <String, dynamic>{
        'cancelled': true,
        'reason': 'microphone_permission_denied',
      };
    }

    final video = await _imagePicker.pickVideo(
      source: ImageSource.camera,
      maxDuration: Duration(
        seconds: (message.params['maxDuration'] as num?)?.toInt() ?? 30,
      ),
      preferredCameraDevice: message.params['camera'] == 'front'
          ? CameraDevice.front
          : CameraDevice.rear,
    );
    if (video == null) {
      return <String, dynamic>{'cancelled': true};
    }

    final saveToGallery = message.params['saveToGallery'] as bool? ?? true;
    String? galleryPath;

    if (saveToGallery) {
      galleryPath = await _saveToSystemGallery(video.path);
    }

    return <String, dynamic>{
      'cancelled': false,
      'path': video.path,
      'name': video.name,
      'mimeType': video.mimeType,
      'savedToGallery': saveToGallery,
      'galleryPath': galleryPath,
    };
  }

  // ============================================================
  //  从相册选视频
  // ============================================================
  Future<Object?> _pickVideo(
    BuildContext context,
    BRWebBridgeMessage message,
  ) async {
    final granted = await BRWebPermissionHelper.ensurePermission(
      permission: Permission.photos,
      context: context,
      permissionName: '相册',
      purpose: '选择视频',
    );
    if (!granted) {
      return <String, dynamic>{
        'cancelled': true,
        'reason': 'permission_denied',
      };
    }

    final video = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: Duration(
        seconds: (message.params['maxDuration'] as num?)?.toInt() ?? 600,
      ),
    );
    if (video == null) {
      return <String, dynamic>{'cancelled': true};
    }
    return <String, dynamic>{
      'cancelled': false,
      'path': video.path,
      'name': video.name,
      'mimeType': video.mimeType,
    };
  }

  // ============================================================
  //  文件选择
  // ============================================================
  Future<Object?> _pickFile(BRWebBridgeMessage message) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: message.params['multiple'] == true,
      withData: false,
    );
    if (result == null) {
      return <String, dynamic>{'cancelled': true, 'files': <Object>[]};
    }
    return <String, dynamic>{
      'cancelled': false,
      'files': result.files
          .map(
            (file) => <String, dynamic>{
              'name': file.name,
              'path': file.path,
              'size': file.size,
              'extension': file.extension,
            },
          )
          .toList(),
    };
  }

  // ============================================================
  //  预览文件
  // ============================================================
  Future<Object?> _previewFile(
    BuildContext context,
    BRWebBridgeMessage message,
  ) async {
    final path = message.params['path'] as String?;
    if (path == null || path.isEmpty) {
      throw ArgumentError('preview path is required');
    }

    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('File not found: $path');
    }

    final fileTypeRaw = message.params['type'] as String?;
    final BRWebFileType fileType;
    if (fileTypeRaw != null) {
      fileType = switch (fileTypeRaw.toLowerCase()) {
        'image' => BRWebFileType.image,
        'video' => BRWebFileType.video,
        'audio' => BRWebFileType.audio,
        _ => inferFileType(path, message.params['mimeType'] as String?),
      };
    } else {
      fileType = inferFileType(path, message.params['mimeType'] as String?);
    }

    final title = message.params['title'] as String?;
    final fileSize = message.params['size'] as int?;

    if (!context.mounted) {
      return <String, dynamic>{'cancelled': true};
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BRWebPreviewPage(
          filePath: path,
          fileType: fileType,
          title: title,
          mimeType: message.params['mimeType'] as String?,
          fileSize: fileSize,
        ),
      ),
    );

    return <String, dynamic>{'closed': true};
  }

  // ============================================================
  //  删除本地文件（H5 上传成功后主动清理）
  // ============================================================
  Future<Object?> _deleteFile(BRWebBridgeMessage message) async {
    final path = message.params['path'] as String?;
    if (path == null || path.isEmpty) {
      throw ArgumentError('delete path is required');
    }

    final file = File(path);
    if (!file.existsSync()) {
      return <String, dynamic>{
        'deleted': false,
        'reason': 'not_found',
        'path': path,
      };
    }

    try {
      await file.delete();
      return <String, dynamic>{'deleted': true, 'path': path};
    } catch (e) {
      return <String, dynamic>{
        'deleted': false,
        'reason': e.toString(),
        'path': path,
      };
    }
  }

  // ============================================================
  //  开始录音
  // ============================================================
  Future<Object?> _startRecord(
    BuildContext context,
    BRWebBridgeMessage message,
  ) async {
    final granted = await BRWebPermissionHelper.ensurePermission(
      permission: Permission.microphone,
      context: context,
      permissionName: '麦克风',
      purpose: '录音',
    );
    if (!granted) {
      return <String, dynamic>{
        'cancelled': true,
        'reason': 'permission_denied',
      };
    }

    // 录音文件用 documents 目录保活，避免被系统 temp 清理
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'br_web_record_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _recordingPath = '${directory.path}${Platform.pathSeparator}$fileName';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordingPath!,
    );
    return <String, dynamic>{'recording': true, 'path': _recordingPath};
  }

  // ============================================================
  //  停止录音
  // ============================================================
  Future<Object?> _stopRecord() async {
    final path = await _recorder.stop();
    return <String, dynamic>{
      'recording': false,
      'path': path ?? _recordingPath,
    };
  }

  // ============================================================
  //  导航：H5 跳转
  // ============================================================
  Future<Object?> _navigateTo(
    BuildContext context,
    BRWebBridgeMessage message,
  ) async {
    final route = message.params['route'] as String?;
    if (route == null || route.isEmpty) {
      throw ArgumentError('navigateTo: route is required');
    }

    final params = message.params['params'] as Map<String, dynamic>?;

    if (!context.mounted) {
      return <String, dynamic>{'success': false, 'reason': 'context_unmounted'};
    }

    try {
      await BRWebNavigator.push(context, route, params: params);
      return <String, dynamic>{'success': true, 'route': route};
    } catch (e) {
      return <String, dynamic>{
        'success': false,
        'reason': e.toString(),
        'route': route,
      };
    }
  }

  /// 导航：H5 返回上一页
  Future<Object?> _navigateBack(
    BuildContext context,
    BRWebBridgeMessage message,
  ) async {
    if (!context.mounted) {
      return <String, dynamic>{'success': false};
    }
    BRWebNavigator.pop(context);
    return <String, dynamic>{'success': true};
  }

  /// 导航：H5 设置页面标题
  Future<Object?> _setTitleFromH5(BRWebBridgeMessage message) async {
    final title = message.params['title'] as String? ?? '';
    onSetTitle?.call(title);
    return <String, dynamic>{'success': true, 'title': title};
  }

  /// H5 请求控制原生 UI（hideTabBar / showTabBar 等）
  Future<Object?> _uiRequest(String action, BRWebBridgeMessage message) async {
    final params = message.params.isNotEmpty
        ? Map<String, dynamic>.from(message.params)
        : null;
    onUiRequest?.call(action, params);
    return <String, dynamic>{'success': true, 'action': action};
  }

  // ============================================================
  //  网络状态（H5 可主动查询）
  // ============================================================
  Future<Object?> _getNetworkStatus() async {
    final monitor = _networkMonitor;
    if (monitor == null) return <String, dynamic>{'status': 'unknown'};
    return <String, dynamic>{'status': await monitor.checkNow()};
  }

  // ============================================================
  //  系统信息（H5 可主动查询）
  // ============================================================
  static BRWebSystemInfo? _systemInfo;
  Future<Object?> _getSystemInfo() async {
    if (_systemInfo == null) return <String, dynamic>{};
    return <String, dynamic>{..._systemInfo!.toJson()};
  }

  // ============================================================
  //  关闭容器
  // ============================================================
  Future<Object?> _close(
    BuildContext context,
    BRWebBridgeMessage message,
  ) async {
    Navigator.of(context).maybePop(message.params);
    return <String, dynamic>{'closing': true};
  }

  // ============================================================
  //  保存文件到系统相册
  // ============================================================
  Future<String?> _saveToSystemGallery(String filePath) async {
    try {
      final result = await ImageGallerySaver.saveFile(
        filePath,
        isReturnPathOfIOS: true,
      );
      if (result is Map && result['isSuccess'] == true) {
        return result['filePath'] as String?;
      }
      return null;
    } catch (_) {
      // 保存到系统相册失败不阻止主流程
      return null;
    }
  }
}
