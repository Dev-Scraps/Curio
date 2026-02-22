import 'package:flutter/services.dart';
import 'dart:async';

/// Platform channel for communicating with native Android yt-dlp
class PlatformChannel {
  static const MethodChannel _channel = MethodChannel('com.curio.app.yt_dlp');

  /// Extract metadata for a video or playlist
  ///
  /// [url] - YouTube video or playlist URL
  /// [cookies] - Optional Netscape-format cookie string
  ///
  /// Returns JSON string containing video/playlist metadata
  static Future<String> getInfo({required String url, String? cookies}) async {
    try {
      final String result = await _channel.invokeMethod('getInfo', {
        'url': url,
        'cookies': cookies,
      });
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to get info: ${e.message}');
    }
  }

  /// Get cookies from WebView for a specific URL
  ///
  /// [url] - The URL to get cookies for (e.g., 'https://youtube.com')
  ///
  /// Returns a map with 'cookies' key containing the cookie string
  static Future<Map<String, dynamic>> getCookies(String url) async {
    try {
      final result = await _channel.invokeMethod('getCookies', {'url': url});
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      throw Exception('Failed to get cookies: ${e.message}');
    }
  }
}
