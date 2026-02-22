import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'permissions.g.dart';

@riverpod
PermissionService permissionService(Ref ref) {
  return PermissionService();
}

class PermissionService {
  Future<bool> requestStoragePermission() async {
    final status = await Permission.storage.request();

    if (await Permission.videos.isDenied) {
      await Permission.videos.request();
    }
    if (await Permission.audio.isDenied) {
      await Permission.audio.request();
    }

    return status.isGranted ||
        await Permission.storage.isGranted ||
        await Permission.videos.isGranted;
  }

  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> hasStoragePermission() async {
    if (await Permission.storage.isGranted) return true;
    if (await Permission.videos.isGranted) return true;
    if (await Permission.audio.isGranted) return true;
    return false;
  }

  Future<bool> hasNotificationPermission() async {
    return await Permission.notification.isGranted;
  }

  Future<bool> requestPipPermission() async {
    // PiP permission is automatically granted on Android 8.0+
    // No special runtime permission needed
    return true;
  }

  Future<bool> hasPipPermission() async {
    // PiP is available on Android 8.0+ without special permissions
    return true;
  }
}
