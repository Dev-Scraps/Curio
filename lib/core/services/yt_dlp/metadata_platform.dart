import 'dart:convert';

import 'package:curio/core/services/yt_dlp/base.dart';

class YtDlpMetadataPlatformService extends YtDlpBasePlatformService {
  Future<void> setPoToken(String? token) async {
    await invokeMethod<String>('setPoToken', {'token': token ?? ''});
  }

  Future<Map<String, dynamic>> getInfo(
    String url, {
    String? cookies,
    bool flat = false,
    List<String>? fields,
  }) async {
    final jsonString = await invokeMethod<String>('getInfo', {
      'url': url,
      if (cookies != null && cookies.isNotEmpty) 'cookies': cookies,
      'flat': flat,
      if (fields != null && fields.isNotEmpty) 'fields': fields,
    });

    if (jsonString == null || jsonString.isEmpty) {
      throw Exception('No response from Python bridge');
    }

    try {
      final result = json.decode(jsonString) as Map<String, dynamic>;
      if (result['error'] == true) {
        throw Exception(
          result['message'] as String? ?? 'yt-dlp extraction failed',
        );
      }
      return result;
    } on FormatException catch (e) {
      // Provide better error message for JSON parsing issues
      final preview = jsonString.length > 200
          ? '${jsonString.substring(0, 200)}...'
          : jsonString;
      throw Exception(
        'Invalid JSON response from yt-dlp: ${e.message}\nResponse preview: $preview',
      );
    }
  }

  Future<Map<String, dynamic>> getEnhancedVideoInfo(String url) async {
    final jsonString = await invokeMethod<String>('getEnhancedVideoInfo', {
      'url': url,
    });

    if (jsonString == null || jsonString.isEmpty) {
      throw Exception('No response from enhanced video info service');
    }

    try {
      final result = json.decode(jsonString) as Map<String, dynamic>;
      if (result['error'] == true) {
        throw Exception(
          result['message'] as String? ?? 'Failed to fetch enhanced video info',
        );
      }
      return result;
    } on FormatException catch (e) {
      // Provide better error message for JSON parsing issues
      final preview = jsonString.length > 200
          ? '${jsonString.substring(0, 200)}...'
          : jsonString;
      throw Exception(
        'Invalid JSON response from enhanced video info: ${e.message}\nResponse preview: $preview',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getUserPlaylists({String? cookies}) async {
    final jsonString = await invokeMethod<String>('getUserPlaylists', {
      if (cookies != null && cookies.isNotEmpty) 'cookies': cookies,
    });

    if (jsonString == null || jsonString.isEmpty) {
      throw Exception('No response from native yt-dlp');
    }

    try {
      // Native yt-dlp returns a JSON array directly
      final decoded = json.decode(jsonString);

      // Handle both array and object formats for backward compatibility
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      } else if (decoded is Map<String, dynamic>) {
        // Old format with error checking
        if (decoded['error'] == true) {
          throw Exception(
            decoded['message'] as String? ?? 'Failed to fetch playlists',
          );
        }
        final playlists = decoded['playlists'] as List? ?? [];
        return playlists.cast<Map<String, dynamic>>();
      }

      return [];
    } on FormatException catch (e) {
      // Provide better error message for JSON parsing issues
      final preview = jsonString.length > 200
          ? '${jsonString.substring(0, 200)}...'
          : jsonString;
      throw Exception(
        'Invalid JSON response from playlists service: ${e.message}\nResponse preview: $preview',
      );
    }
  }
}
