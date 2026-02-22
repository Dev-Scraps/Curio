import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/curio');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/curio'),
      ),
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    try {
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to request permission - $e');
    }
  }

  Future<void> showDownloadProgress({
    required String taskId,
    required String title,
    required num progress, // accepts int or double
    String? speed,
    String? eta,
  }) async {
    final int percent = progress.round().clamp(0, 100);

    final String detail = (speed != null && eta != null)
        ? '$percent% • $speed • ETA: $eta'
        : '$percent%';

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'download_channel',
          'Downloads',
          channelDescription: 'Notifications for download progress',
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: 100,
          progress: percent,
          indeterminate: false,
          ongoing: true,
          autoCancel: false,
          styleInformation: BigTextStyleInformation(
            detail,
            summaryText: 'Downloading...',
          ),
        );

    await _notificationsPlugin.show(
      id: taskId.hashCode.toSigned(31),
      title: 'Downloading: $title',
      body: detail,
      notificationDetails: NotificationDetails(
        android: androidPlatformChannelSpecifics,
      ),
    );
  }

  Future<void> showSyncProgress({
    required int progress,
    required int total,
    required String status,
  }) async {
    // Ensure notifyId fits in 32-bit signed integer
    final int syncNotifyId = 'sync'.hashCode.toSigned(31);
    final int percent = total > 0 ? (progress * 100 ~/ total).clamp(0, 100) : 0;

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'sync_channel',
          'Library Sync',
          channelDescription: 'Notifications for library synchronization',
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: 100,
          progress: percent,
          indeterminate: total == 0,
          ongoing: true,
          autoCancel: false,
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id: syncNotifyId,
      title: 'Syncing Library',
      body: '$status ($percent%)',
      notificationDetails: platformChannelSpecifics,
    );
  }

  Future<void> showInfoNotification({
    required int id,
    required String title,
    required String message,
    bool ongoing = false,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'info_channel',
          'General Info',
          channelDescription: 'General background activity notifications',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: ongoing,
          autoCancel: !ongoing,
        );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: message,
      notificationDetails: platformChannelSpecifics,
    );
  }

  Future<void> showFetchingNotification({
    required String videoTitle,
    bool ongoing = true,
  }) async {
    await showInfoNotification(
      id: 'fetching'.hashCode.toSigned(31),
      title: 'Fetching Metadata',
      message: videoTitle,
      ongoing: ongoing,
    );
  }

  Future<void> showDownloadComplete({
    required String taskId,
    required String title,
  }) async {
    final int notifyId = taskId.hashCode.toSigned(31);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'download_channel',
          'Downloads',
          channelDescription: 'Notifications for completed downloads',
          importance: Importance.high,
          priority: Priority.high,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id: notifyId,
      title: 'Download Complete',
      body: title,
      notificationDetails: platformChannelSpecifics,
    );
  }

  Future<void> showDownloadError({
    required String taskId,
    required String title,
    required String error,
  }) async {
    final int notifyId = taskId.hashCode.toSigned(31);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'download_channel',
          'Downloads',
          channelDescription: 'Notifications for download errors',
          importance: Importance.high,
          priority: Priority.high,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id: notifyId,
      title: 'Download Failed',
      body: '$title: $error',
      notificationDetails: platformChannelSpecifics,
    );
  }

  Future<void> cancel(String taskId) async {
    await _notificationsPlugin.cancel(id: taskId.hashCode.toSigned(31));
  }
}
