import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'br_web_bridge_message.dart';
import 'br_web_permission_helper.dart';
import 'br_web_preview_page.dart'
    show BRWebFileType, BRWebPreviewPage, inferFileType;

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

  @override
  Future<Object?> handle(BuildContext context, BRWebBridgeMessage message) {
    return switch (message.action) {
      'device.camera.takePhoto' => _takePhoto(context, message),
      'device.camera.takeVideo' => _takeVideo(context, message),
      'device.camera.pickVideo' => _pickVideo(context, message),
      'device.file.pick' => _pickFile(message),
      'device.file.preview' => _previewFile(context, message),
      'device.audio.startRecord' => _startRecord(context, message),
      'device.audio.stopRecord' => _stopRecord(),
      'container.close' => _close(context, message),
      _ => Future<Object?>.value(BRWebCapabilityHandlerResult.notHandled),
    };
  }

  /// 拍照
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
      return <String, dynamic>{'cancelled': true, 'reason': 'permission_denied'};
    }

    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: (message.params['quality'] as num?)?.toInt() ?? 85,
      maxWidth: (message.params['maxWidth'] as num?)?.toDouble(),
      maxHeight: (message.params['maxHeight'] as num?)?.toDouble(),
    );
    if (image == null) {
      return <String, dynamic>{'cancelled': true};
    }
    return <String, dynamic>{
      'cancelled': false,
      'path': image.path,
      'name': image.name,
      'mimeType': image.mimeType,
    };
  }

  /// 录像（调用系统相机录制视频）
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
      return <String, dynamic>{'cancelled': true, 'reason': 'camera_permission_denied'};
    }

    if (!context.mounted) {
      return <String, dynamic>{'cancelled': true, 'reason': 'context_unmounted'};
    }

    final micGranted = await BRWebPermissionHelper.ensurePermission(
      permission: Permission.microphone,
      context: context,
      permissionName: '麦克风',
      purpose: '录像录音',
    );
    if (!micGranted) {
      return <String, dynamic>{'cancelled': true, 'reason': 'microphone_permission_denied'};
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
    return <String, dynamic>{
      'cancelled': false,
      'path': video.path,
      'name': video.name,
      'mimeType': video.mimeType,
    };
  }

  /// 从相册选择视频
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
      return <String, dynamic>{'cancelled': true, 'reason': 'permission_denied'};
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

  /// 文件选择
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

  /// 本地预览文件（图片/视频/音频）
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

  /// 开始录音
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
      return <String, dynamic>{'cancelled': true, 'reason': 'permission_denied'};
    }

    final directory = await getTemporaryDirectory();
    final fileName =
        'br_web_record_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _recordingPath = '${directory.path}${Platform.pathSeparator}$fileName';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordingPath!,
    );
    return <String, dynamic>{'recording': true, 'path': _recordingPath};
  }

  /// 停止录音
  Future<Object?> _stopRecord() async {
    final path = await _recorder.stop();
    return <String, dynamic>{
      'recording': false,
      'path': path ?? _recordingPath,
    };
  }

  /// 关闭容器
  Future<Object?> _close(
    BuildContext context,
    BRWebBridgeMessage message,
  ) async {
    Navigator.of(context).maybePop(message.params);
    return <String, dynamic>{'closing': true};
  }
}
