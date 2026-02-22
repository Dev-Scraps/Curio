import 'dart:convert';
import 'package:flutter/services.dart';

abstract class YtDlpBasePlatformService {
  static const MethodChannel _channel = MethodChannel('com.curio.app.yt_dlp');
  static const EventChannel _progressChannel = EventChannel(
    'com.curio.app.yt_dlp/progress',
  );

  MethodChannel get channel => _channel;
  EventChannel get progressChannel => _progressChannel;

  Future<void> initialize({String channelName = 'Stable'}) async {
    // Initialization is handled natively in MainActivity.onCreate
    print('YtDlpBasePlatformService: initialize called (no-op)');
  }

  Future<String> getVersion() async {
    try {
      final result = await _channel.invokeMethod<String>('getYtDlpVersion');
      if (result != null) {
        final decoded = json.decode(result) as Map<String, dynamic>;
        return decoded['version'] as String? ?? 'unknown';
      }
      return 'unknown';
    } catch (e) {
      print('Error getting version: $e');
      return 'error';
    }
  }

  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      print('Platform exception in $method: ${e.message}');
      rethrow;
    }
  }

  Future<String> callMethod(
    String method,
    Map<String, dynamic> arguments,
  ) async {
    try {
      final result = await _channel.invokeMethod<String>(method, arguments);
      return result ?? '{"error": true, "message": "No response from bridge"}';
    } catch (e) {
      print('Error calling method $method: $e');
      return '{"error": true, "message": "${e.toString()}"}';
    }
  }

  Future<String> getCookies(String url) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getCookies',
        {'url': url},
      );

      if (result is Map) {
        final map = Map<String, dynamic>.from(result);
        return map['cookies'] as String? ?? '';
      }
      return '';
    } catch (e) {
      print('Error getting cookies: $e');
      rethrow;
    }
  }
}
