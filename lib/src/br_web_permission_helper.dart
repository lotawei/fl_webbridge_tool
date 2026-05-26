import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// 统一权限申请工具
///
/// 自动处理三种情况：
/// 1. 权限已授予 → 直接返回 true
/// 2. 权限被拒绝（可再次询问）→ 弹出说明弹窗，用户确认后重试
/// 3. 权限被永久拒绝 → 弹出引导弹窗，用户点击后跳转系统设置
class BRWebPermissionHelper {
  BRWebPermissionHelper._();

  /// 申请某个权限，返回是否授予
  ///
  /// [permission] 要申请的权限
  /// [context] 用于弹窗的 BuildContext
  /// [permissionName] 权限名称（用于弹窗提示），如"相机"、"麦克风"
  /// [purpose] 权限用途说明，如"拍照"、"录音"
  static Future<bool> ensurePermission({
    required Permission permission,
    required BuildContext context,
    required String permissionName,
    required String purpose,
  }) async {
    // 1. 先检查当前状态
    var status = await permission.status;

    // 2. 如果还没授予，发起请求
    if (!status.isGranted && !status.isLimited) {
      status = await permission.request();
    }

    // 3. 已授予 → 直接过
    if (status.isGranted || status.isLimited) {
      return true;
    }

    // 4. 如果永久拒绝了 → 跳设置页
    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      final shouldOpen = await _showSettingsDialog(
        context: context,
        permissionName: permissionName,
        purpose: purpose,
      );
      if (shouldOpen == true && context.mounted) {
        await openAppSettings();
        // 从设置返回后再检查一次
        status = await permission.status;
        return status.isGranted || status.isLimited;
      }
      return false;
    }

    // 5. 普通拒绝（可再次询问）
    if (!context.mounted) return false;
    final shouldRetry = await _showRationaleDialog(
      context: context,
      permissionName: permissionName,
      purpose: purpose,
    );

    if (shouldRetry == true && context.mounted) {
      status = await permission.request();
      if (status.isGranted || status.isLimited) {
        return true;
      }
      // 再次拒绝后如果是永久拒绝，跳设置
      if (status.isPermanentlyDenied && context.mounted) {
        final shouldOpen = await _showSettingsDialog(
          context: context,
          permissionName: permissionName,
          purpose: purpose,
        );
        if (shouldOpen == true && context.mounted) {
          await openAppSettings();
          status = await permission.status;
          return status.isGranted || status.isLimited;
        }
      }
      return false;
    }

    return false;
  }

  /// 普通拒绝 → 说明弹窗
  static Future<bool> _showRationaleDialog({
    required BuildContext context,
    required String permissionName,
    required String purpose,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('需要$permissionName权限'),
        content: Text('$purpose需要使用$permissionName权限。\n请在弹窗中选择"允许"。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('拒绝'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('去授权'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 永久拒绝 → 跳转设置弹窗
  static Future<bool> _showSettingsDialog({
    required BuildContext context,
    required String permissionName,
    required String purpose,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('需要$permissionName权限'),
        content: Text(
          '$purpose需要使用$permissionName权限。\n'
          '你之前拒绝了该权限，请前往系统设置中手动开启。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('去设置'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
