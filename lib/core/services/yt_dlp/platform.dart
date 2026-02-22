import 'dart:convert';
import 'package:flutter/services.dart';

class YtDlpPlatformService {
  static const MethodChannel _channel = MethodChannel('com.curio.app.yt_dlp');
  static const EventChannel _progressChannel = EventChannel(
    'com.curio.app.yt_dlp/progress',
  );

  Function(String message, double progress)? onProgress;

  YtDlpPlatformService() {
    _setupProgressListener();
  }

  void _setupProgressListener() {
    _progressChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map && onProgress != null) {
          final message = event['message'] as String? ?? '';
          final progress = (event['progress'] as num?)?.toDouble() ?? 0.0;
          onProgress?.call(message, progress);
        }
      },
      onError: (error) {
        print('YtDlpPlatformService: Progress stream error: $error');
      },
    );
  }

  Future<void> initialize({String channel = 'Stable'}) async {
    try {
      await _channel.invokeMethod('initialize', {'channel': channel});
      print(
        'YtDlpPlatformService: Python runtime initialized via Chaquopy ($channel channel)',
      );
    } catch (e) {
      print('YtDlpPlatformService: Error initializing: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> getYtDlpInfo({String channel = 'Stable'}) async {
    try {
      // Get yt-dlp version via Python
      await initialize(channel: channel);
      final jsonString = await _channel.invokeMethod<String>('getYtDlpVersion');

      if (jsonString != null && jsonString.isNotEmpty) {
        final result = json.decode(jsonString) as Map<String, dynamic>;
        return {
          'version': result['version'] as String? ?? 'unknown',
          'python_version': result['python_version'] as String? ?? 'unknown',
          'platform': 'Chaquopy (Android)',
        };
      }

      return {
        'version': 'unknown',
        'python_version': 'unknown',
        'platform': 'Chaquopy (Android)',
      };
    } catch (e) {
      print('YtDlpPlatformService: Error getting yt-dlp info: $e');
      return {
        'version': 'error',
        'python_version': 'error',
        'platform': 'Chaquopy (Android)',
        'error': e.toString(),
      };
    }
  }

  Future<String> getVersion() async {
    try {
      final info = await getYtDlpInfo();
      return info['version'] ?? 'unknown';
    } catch (e) {
      print('YtDlpPlatformService: Error getting version: $e');
      return 'error';
    }
  }

  /// [flat] = true: Fast extraction with basic info only (no m3u8, no detailed API calls)
  /// [flat] = false: Full extraction with complete metadata (slower but thorough)
  /// [fields] = List of fields to include in the response (e.g., ['title', 'thumbnail', 'upload_date'])
  ///
  /// For videos: Returns {id, title, duration, uploader, channel_id, thumbnails, formats}
  /// For playlists: Returns {_type, id, title, entries[], uploader, playlist_count}
  Future<Map<String, dynamic>> getInfo(
    String url, {
    String? cookies,
    bool flat = false,
    List<String>? fields,
  }) async {
    try {
      final jsonString = await _channel.invokeMethod<String>('getInfo', {
        'url': url,
        if (cookies != null && cookies.isNotEmpty) 'cookies': cookies,
        'flat': flat,
        if (fields != null && fields.isNotEmpty) 'fields': fields,
      });

      if (jsonString == null || jsonString.isEmpty) {
        throw Exception('No response from Python bridge');
      }

      final result = json.decode(jsonString) as Map<String, dynamic>;

      if (result['error'] == true) {
        throw Exception(
          result['message'] as String? ?? 'yt-dlp extraction failed',
        );
      }

      return result;
    } catch (e) {
      print('YtDlpPlatformService: Error getting info for $url: $e');
      throw Exception(e.toString());
    }
  }

  Future<List<Map<String, dynamic>>> getUserPlaylists({String? cookies}) async {
    try {
      final jsonString = await _channel.invokeMethod<String>(
        'getUserPlaylists',
        {if (cookies != null && cookies.isNotEmpty) 'cookies': cookies},
      );

      if (jsonString == null || jsonString.isEmpty) {
        throw Exception('No response from Python bridge');
      }

      final result = json.decode(jsonString) as Map<String, dynamic>;

      if (result['error'] == true) {
        throw Exception(
          result['message'] as String? ?? 'Failed to fetch playlists',
        );
      }

      final playlists = result['playlists'] as List? ?? [];
      return playlists.cast<Map<String, dynamic>>();
    } catch (e) {
      print('YtDlpPlatformService: Error fetching user playlists: $e');
      return [];
    }
  }

  /// Start a download task via Python bridge
  Future<String> startDownload(String url, Map<String, dynamic> config) async {
    try {
      final configJson = json.encode(config);
      final taskId = await _channel.invokeMethod<String>('startDownload', {
        'url': url,
        'config': configJson,
      });

      if (taskId == null || taskId.isEmpty) {
        throw Exception('Failed to start download: No task ID returned. Check native logs for errors.');
      }

      return taskId;
    } catch (e) {
      print('YtDlpPlatformService: Error starting download: $e');
      throw Exception(e.toString());
    }
  }

  /// Get status of a download task
  Future<Map<String, dynamic>?> getDownloadStatus(String taskId) async {
    try {
      final jsonString = await _channel.invokeMethod<String>(
        'getDownloadStatus',
        {'taskId': taskId},
      );

      if (jsonString == null || jsonString.isEmpty || jsonString == '{}') {
        return null;
      }

      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('YtDlpPlatformService: Error getting download status: $e');
      return null;
    }
  }

  /// Cancel a download task
  Future<bool> cancelDownload(String taskId) async {
    try {
      final result = await _channel.invokeMethod<bool>('cancelDownload', {
        'taskId': taskId,
      });
      return result ?? false;
    } catch (e) {
      print('YtDlpPlatformService: Error cancelling download: $e');
      return false;
    }
  }

  /// Get cookies from Android WebView for authentication
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
      print('YtDlpPlatformService: Error getting cookies: $e');
      rethrow;
    }
  }
}
