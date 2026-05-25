import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'br_web_bridge_message.dart';

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
      'device.camera.takePhoto' => _takePhoto(message),
      'device.file.pick' => _pickFile(message),
      'device.audio.startRecord' => _startRecord(message),
      'device.audio.stopRecord' => _stopRecord(),
      'container.close' => _close(context, message),
      _ => Future<Object?>.value(BRWebCapabilityHandlerResult.notHandled),
    };
  }

  Future<Object?> _takePhoto(BRWebBridgeMessage message) async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      throw StateError('Camera permission denied.');
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

  Future<Object?> _startRecord(BRWebBridgeMessage message) async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw StateError('Microphone permission denied.');
    }
    if (!await _recorder.hasPermission()) {
      throw StateError('Audio recording permission denied.');
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

  Future<Object?> _stopRecord() async {
    final path = await _recorder.stop();
    return <String, dynamic>{
      'recording': false,
      'path': path ?? _recordingPath,
    };
  }

  Future<Object?> _close(
    BuildContext context,
    BRWebBridgeMessage message,
  ) async {
    Navigator.of(context).maybePop(message.params);
    return <String, dynamic>{'closing': true};
  }
}
