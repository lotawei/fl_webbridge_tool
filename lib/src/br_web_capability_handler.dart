import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'br_web_bridge_message.dart';
import 'br_web_database_manager.dart';
import 'br_web_navigator.dart';
import 'br_web_network_monitor.dart';
import 'br_web_permission_helper.dart';
import 'br_web_preview_page.dart' show BRWebFileType, BRWebPreviewPage, inferFileType;
import 'br_web_resource_manager.dart';
import 'br_web_system_info.dart';

abstract interface class BRWebCapabilityHandler { Future<Object?> handle(BuildContext context, BRWebBridgeMessage message); }

class CompositeBRWebCapabilityHandler implements BRWebCapabilityHandler {
  CompositeBRWebCapabilityHandler(this.handlers);
  final List<BRWebCapabilityHandler> handlers;
  @override Future<Object?> handle(BuildContext context, BRWebBridgeMessage message) async {
    for (final h in handlers) { final r = await h.handle(context, message); if (r != BRWebCapabilityHandlerResult.notHandled) return r; }
    throw UnsupportedError('Unsupported action: ${message.action}');
  }
}

enum BRWebCapabilityHandlerResult { notHandled }

class DefaultBRWebCapabilityHandler implements BRWebCapabilityHandler {
  DefaultBRWebCapabilityHandler({ImagePicker? imagePicker, AudioRecorder? recorder})
    : _imagePicker = imagePicker ?? ImagePicker(), _recorder = recorder ?? AudioRecorder();

  final ImagePicker _imagePicker; 
  final AudioRecorder _recorder;
  String? _recordingPath;
  BRWebNetworkMonitor? _networkMonitor;
  BRWebResourceManager? _resourceManager;
  WorkOrderManager? _workOrderManager;

  void Function(String title)? onSetTitle;
  void Function(String action, Map<String, dynamic>? params)? onUiRequest;

  set networkMonitor(BRWebNetworkMonitor? m) => _networkMonitor = m;
  set resourceManager(BRWebResourceManager? m) => _resourceManager = m;
  set workOrderManager(WorkOrderManager? m) => _workOrderManager = m;

  static set systemInfo(BRWebSystemInfo info) => _systemInfo = info;
  static BRWebSystemInfo? get systemInfo => _systemInfo;
  static BRWebSystemInfo? _systemInfo;

  @override
  Future<Object?> handle(BuildContext context, BRWebBridgeMessage message) {
    return switch (message.action) {
      'device.camera.takePhoto' => _takePhoto(context, message),
      'device.camera.pickPhoto' => _pickPhoto(context, message),
      'device.camera.pickMultiPhoto' => _pickMultiPhoto(context, message),
      'device.camera.takeVideo' => _takeVideo(context, message),
      'device.camera.pickVideo' => _pickVideo(context, message),
      'device.file.pick' => _pickFile(message),
      'device.file.preview' => _previewFile(context, message),
      'device.file.delete' => _deleteFile(message),
      'device.file.readAsDataUrl' => _readAsDataUrl(message),
      'device.network.status' => _getNetworkStatus(),
      'device.system.info' => _getSystemInfo(),
      'device.audio.startRecord' => _startRecord(context, message),
      'device.audio.stopRecord' => _stopRecord(),
      'navigation.navigateTo' => _navigateTo(context, message),
      'navigation.goBack' => _navigateBack(context, message),
      'navigation.setTitle' => _setTitleFromH5(message),
      'ui.hideTabBar' => _uiRequest('hideTabBar', message),
      'ui.showTabBar' => _uiRequest('showTabBar', message),
      'resource.getStatus' => _resourceGetStatus(),
      'resource.checkUpdate' => _resourceCheckUpdate(),
      'resource.startUpdate' => _resourceStartUpdate(),
      'resource.cancelUpdate' => _resourceCancelUpdate(),
      'resource.switchTo' => _resourceSwitchTo(message),
      'database.workOrder.query' => _dbQuery(message),
      'database.workOrder.getById' => _dbGetById(message),
      'database.workOrder.insert' => _dbInsert(message),
      'database.workOrder.update' => _dbUpdate(message),
      'database.workOrder.delete' => _dbDelete(message),
      'container.close' => _close(context, message),
      _ => Future<Object?>.value(BRWebCapabilityHandlerResult.notHandled),
    };
  }

  Future<Object?> _takePhoto(BuildContext ctx, BRWebBridgeMessage msg) async {
    if (!await BRWebPermissionHelper.ensurePermission(permission: Permission.camera, context: ctx, permissionName: '相机', purpose: '拍照'))
      return {'cancelled': true, 'reason': 'permission_denied'};
    final img = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: (msg.params['quality'] as num?)?.toInt() ?? 85,
      maxWidth: (msg.params['maxWidth'] as num?)?.toDouble() ?? 1600,
      maxHeight: (msg.params['maxHeight'] as num?)?.toDouble(),
    );
    if (img == null) return {'cancelled': true};
    final bytes = await File(img.path).length();
    final save = msg.params['saveToGallery'] as bool? ?? true;
    final gp = save ? await _saveToSystemGallery(img.path) : null;
    return {'cancelled': false, 'path': img.path, 'name': img.name, 'mimeType': img.mimeType, 'size': bytes, 'sizeKB': bytes ~/ 1024, 'savedToGallery': save, 'galleryPath': gp};
  }

  Future<Object?> _pickPhoto(BuildContext ctx, BRWebBridgeMessage msg) async {
    if (!await BRWebPermissionHelper.ensurePermission(permission: Permission.photos, context: ctx, permissionName: '相册', purpose: '选择照片'))
      return {'cancelled': true, 'reason': 'permission_denied'};
    final img = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: (msg.params['quality'] as num?)?.toInt() ?? 85,
      maxWidth: (msg.params['maxWidth'] as num?)?.toDouble(),
      maxHeight: (msg.params['maxHeight'] as num?)?.toDouble(),
    );
    if (img == null) return {'cancelled': true};
    final bytes = await File(img.path).length();
    return {'cancelled': false, 'path': img.path, 'name': img.name, 'mimeType': img.mimeType, 'size': bytes, 'sizeKB': bytes ~/ 1024};
  }

  Future<Object?> _pickMultiPhoto(BuildContext ctx, BRWebBridgeMessage msg) async {
    if (!await BRWebPermissionHelper.ensurePermission(permission: Permission.photos, context: ctx, permissionName: '相册', purpose: '选择多张照片'))
      return {'cancelled': true, 'reason': 'permission_denied'};
    final images = await _imagePicker.pickMultiImage(
      imageQuality: (msg.params['quality'] as num?)?.toInt() ?? 85,
      maxWidth: (msg.params['maxWidth'] as num?)?.toDouble(),
      maxHeight: (msg.params['maxHeight'] as num?)?.toDouble(),
    );
    if (images.isEmpty) return {'cancelled': true, 'files': <Object>[]};
    final files = <Map<String, dynamic>>[];
    for (final img in images) {
      final bytes = await File(img.path).length();
      files.add({'path': img.path, 'name': img.name, 'mimeType': img.mimeType, 'size': bytes, 'sizeKB': bytes ~/ 1024});
    }
    return {'cancelled': false, 'files': files};
  }

  Future<Object?> _takeVideo(BuildContext ctx, BRWebBridgeMessage msg) async {
    if (!await BRWebPermissionHelper.ensurePermission(permission: Permission.camera, context: ctx, permissionName: '相机', purpose: '录像'))
      return {'cancelled': true, 'reason': 'camera_permission_denied'};
    if (!ctx.mounted) return {'cancelled': true, 'reason': 'context_unmounted'};
    if (!await BRWebPermissionHelper.ensurePermission(permission: Permission.microphone, context: ctx, permissionName: '麦克风', purpose: '录像录音'))
      return {'cancelled': true, 'reason': 'microphone_permission_denied'};
    final v = await _imagePicker.pickVideo(source: ImageSource.camera, maxDuration: Duration(seconds: (msg.params['maxDuration'] as num?)?.toInt() ?? 30), preferredCameraDevice: msg.params['camera'] == 'front' ? CameraDevice.front : CameraDevice.rear);
    if (v == null) return {'cancelled': true};
    final save = msg.params['saveToGallery'] as bool? ?? true;
    final gp = save ? await _saveToSystemGallery(v.path) : null;
    return {'cancelled': false, 'path': v.path, 'name': v.name, 'mimeType': v.mimeType, 'savedToGallery': save, 'galleryPath': gp};
  }

  Future<Object?> _pickVideo(BuildContext ctx, BRWebBridgeMessage msg) async {
    if (!await BRWebPermissionHelper.ensurePermission(permission: Permission.photos, context: ctx, permissionName: '相册', purpose: '选择视频'))
      return {'cancelled': true, 'reason': 'permission_denied'};
    final v = await _imagePicker.pickVideo(source: ImageSource.gallery, maxDuration: Duration(seconds: (msg.params['maxDuration'] as num?)?.toInt() ?? 600));
    if (v == null) return {'cancelled': true};
    return {'cancelled': false, 'path': v.path, 'name': v.name, 'mimeType': v.mimeType};
  }

  Future<Object?> _pickFile(BRWebBridgeMessage msg) async {
    final r = await FilePicker.pickFiles(allowMultiple: msg.params['multiple'] == true, withData: false);
    if (r == null) return {'cancelled': true, 'files': <Object>[]};
    return {'cancelled': false, 'files': r.files.map((f) => {'name': f.name, 'path': f.path, 'size': f.size, 'extension': f.extension}).toList()};
  }

  Future<Object?> _previewFile(BuildContext ctx, BRWebBridgeMessage msg) async {
    final path = msg.params['path'] as String?; if (path == null || path.isEmpty) throw ArgumentError('preview path required');
    if (!File(path).existsSync()) throw StateError('File not found: $path');
    final typeRaw = msg.params['type'] as String?;
    final fileType = typeRaw != null ? switch (typeRaw) { 'image' => BRWebFileType.image, 'video' => BRWebFileType.video, 'audio' => BRWebFileType.audio, _ => inferFileType(path, msg.params['mimeType'] as String?) } : inferFileType(path, msg.params['mimeType'] as String?);
    if (!ctx.mounted) return {'cancelled': true};
    await Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => BRWebPreviewPage(filePath: path, fileType: fileType, title: msg.params['title'] as String?, mimeType: msg.params['mimeType'] as String?, fileSize: msg.params['size'] as int?)));
    return {'closed': true};
  }

  Future<Object?> _deleteFile(BRWebBridgeMessage msg) async {
    final path = msg.params['path'] as String?; if (path == null) throw ArgumentError('path required');
    final f = File(path); if (!f.existsSync()) return {'deleted': false, 'reason': 'not_found'};
    try { await f.delete(); return {'deleted': true}; } catch (e) { return {'deleted': false, 'reason': e.toString()}; }
  }

  Future<Object?> _readAsDataUrl(BRWebBridgeMessage msg) async {
    final path = msg.params['path'] as String?;
    if (path == null) throw ArgumentError('path required');
    final f = File(path);
    if (!f.existsSync()) throw StateError('File not found: $path');
    final bytes = await f.readAsBytes();
    
    // 从扩展名推断 MIME
    final ext = path.split('.').last.toLowerCase();
    String mime = 'application/octet-stream';
    if (['jpg', 'jpeg'].contains(ext)) mime = 'image/jpeg';
    else if (ext == 'png') mime = 'image/png';
    else if (ext == 'gif') mime = 'image/gif';
    else if (ext == 'webp') mime = 'image/webp';
    else if (ext == 'bmp') mime = 'image/bmp';
    else if (ext == 'svg') mime = 'image/svg+xml';
    else if (ext == 'mp4') mime = 'video/mp4';
    else if (ext == 'mov') mime = 'video/quicktime';
    else if (ext == 'mp3') mime = 'audio/mpeg';
    else if (ext == 'm4a') mime = 'audio/mp4';
    else if (ext == 'wav') mime = 'audio/wav';

    // 限制图片类最大 5MB，超过不转
    if (mime.startsWith('image/') && bytes.length > 5 * 1024 * 1024) {
      return {'dataUrl': null, 'mimeType': mime, 'size': bytes.length, 'error': 'image too large (>5MB)'};
    }

    final b64 = base64Encode(bytes);
    return {
      'dataUrl': 'data:$mime;base64,$b64',
      'mimeType': mime,
      'size': bytes.length,
      'name': path.split('/').last,
    };
  }

  Future<Object?> _startRecord(BuildContext ctx, BRWebBridgeMessage msg) async {
    if (!await BRWebPermissionHelper.ensurePermission(permission: Permission.microphone, context: ctx, permissionName: '麦克风', purpose: '录音'))
      return {'cancelled': true, 'reason': 'permission_denied'};
    final dir = await getApplicationDocumentsDirectory();
    _recordingPath = '${dir.path}/br_web_record_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _recordingPath!);
    return {'recording': true, 'path': _recordingPath};
  }
  Future<Object?> _stopRecord() async {
    final p = await _recorder.stop();
    final path = p ?? _recordingPath;
    final bytes = path != null ? await File(path).length() : 0;
    final name = path?.split('/').last ?? 'recording.m4a';
    return {'recording': false, 'path': path, 'name': name, 'mimeType': 'audio/mp4', 'size': bytes, 'sizeKB': bytes ~/ 1024};
  }

  Future<Object?> _getNetworkStatus() async {
    if (_networkMonitor == null) return {'status': 'unknown'};
    return {'status': await _networkMonitor!.checkNow()};
  }
  Future<Object?> _getSystemInfo() async => _systemInfo?.toJson() ?? {};

  Future<Object?> _navigateTo(BuildContext ctx, BRWebBridgeMessage msg) async {
    final route = msg.params['route'] as String?; if (route == null) throw ArgumentError('route required');
    if (!ctx.mounted) return {'success': false};
    try { await BRWebNavigator.push(ctx, route, params: msg.params['params'] as Map<String, dynamic>?); return {'success': true, 'route': route}; }
    catch (e) { return {'success': false, 'reason': e.toString(), 'route': route}; }
  }
  Future<Object?> _navigateBack(BuildContext ctx, BRWebBridgeMessage msg) async { BRWebNavigator.pop(ctx); return {'success': true}; }
  Future<Object?> _setTitleFromH5(BRWebBridgeMessage msg) async { final t = msg.params['title'] as String? ?? ''; onSetTitle?.call(t); return {'success': true, 'title': t}; }
  Future<Object?> _uiRequest(String action, BRWebBridgeMessage msg) async { onUiRequest?.call(action, msg.params.isNotEmpty ? Map.from(msg.params) : null); return {'success': true, 'action': action}; }

  Future<Map<String, dynamic>> _resourceGetStatus() async {
    final mgr = _resourceManager;
    if (mgr == null) return {'error': 'no resourceManager'};
    return mgr.getStatus();
  }
  Future<Map<String, dynamic>> _resourceCheckUpdate() async {
    final mgr = _resourceManager;
    if (mgr == null) return {'error': 'no resourceManager'};
    return await mgr.checkUpdate();
  }
  Future<Map<String, dynamic>> _resourceStartUpdate() async {
    final mgr = _resourceManager;
    if (mgr == null) return {'error': 'no resourceManager'};
    return await mgr.startUpdate();
  }
  Future<Map<String, dynamic>> _resourceCancelUpdate() async {
    final mgr = _resourceManager;
    if (mgr == null) return {'error': 'no resourceManager'};
    return await mgr.cancelUpdate();
  }
  Future<Map<String, dynamic>> _resourceSwitchTo(BRWebBridgeMessage msg) async {
    final v = msg.params['version'] as String?;
    if (v == null) return {'error': 'version required'};
    final mgr = _resourceManager;
    if (mgr == null) return {'error': 'no resourceManager'};
    return await mgr.switchTo(v);
  }

  Future<Map<String, dynamic>> _dbQuery(BRWebBridgeMessage msg) async {
    final m = _workOrderManager ?? (throw StateError('db not configured'));
    final rows = await m.db.query(where: msg.params['where'] as String?, whereArgs: msg.params['whereArgs'] as List<dynamic>?, limit: msg.params['limit'] as int?);
    return {'ok': true, 'rows': rows.map((r) => r.toJson()).toList()};
  }
  Future<Map<String, dynamic>> _dbGetById(BRWebBridgeMessage msg) async {
    final m = _workOrderManager ?? (throw StateError('db not configured'));
    final id = msg.params['id'] as int?; if (id == null) throw ArgumentError('id required');
    final row = await m.db.getById(id); return {'ok': true, 'row': row?.toJson()};
  }
  Future<Map<String, dynamic>> _dbInsert(BRWebBridgeMessage msg) async {
    final m = _workOrderManager ?? (throw StateError('db not configured'));
    final order = WorkOrder(title: msg.params['title'] as String? ?? '', description: msg.params['description'] as String? ?? '', status: msg.params['status'] as String? ?? 'pending', priority: msg.params['priority'] as String? ?? 'medium', assignee: msg.params['assignee'] as String?, address: msg.params['address'] as String?);
    final newId = await m.db.insert(order); return {'ok': true, 'id': newId};
  }
  Future<Map<String, dynamic>> _dbUpdate(BRWebBridgeMessage msg) async {
    final m = _workOrderManager ?? (throw StateError('db not configured'));
    final id = msg.params['id'] as int?; if (id == null) throw ArgumentError('id required');
    final existing = await m.db.getById(id); if (existing == null) throw StateError('row not found');
    final up = existing.copyWith(title: msg.params['title'] as String?, description: msg.params['description'] as String?, status: msg.params['status'] as String?, priority: msg.params['priority'] as String?, assignee: msg.params['assignee'] as String?, address: msg.params['address'] as String?);
    await m.db.update(id, up); return {'ok': true, 'id': id};
  }
  Future<Map<String, dynamic>> _dbDelete(BRWebBridgeMessage msg) async {
    final m = _workOrderManager ?? (throw StateError('db not configured'));
    final id = msg.params['id'] as int?; if (id == null) throw ArgumentError('id required');
    await m.db.delete(id); return {'ok': true, 'id': id};
  }

  Future<Object?> _close(BuildContext ctx, BRWebBridgeMessage msg) async { Navigator.of(ctx).maybePop(msg.params); return {'closing': true}; }
  Future<String?> _saveToSystemGallery(String path) async {
    try { final r = await ImageGallerySaver.saveFile(path, isReturnPathOfIOS: true); if (r is Map && r['isSuccess'] == true) return r['filePath'] as String?; } catch (_) {}
    return null;
  }
}
