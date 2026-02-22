import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:curio/core/services/system/logger.dart';
import 'package:curio/core/services/yt_dlp/metadata_platform.dart';

class YtDlpMetadataService {
  final YtDlpMetadataPlatformService _platform = YtDlpMetadataPlatformService();
  static const _tag = 'YtDlpMetadataService';

  // Metadata caching
  final Map<String, Map<String, dynamic>> _metadataCache = {};
  final Duration _cacheTTL = const Duration(hours: 24);
  final Map<String, DateTime> _cacheTime = {};

  /// Fetch metadata for any URL (video, playlist, account feed, etc.)
  Future<Map<String, dynamic>> fetchMetadata(
    String url, {
    String? cookiePath,
    String? cookies,
    bool useCache = true,
    bool flat = false,
    List<String>? fields,
  }) async {
    try {
      // Check cache
      if (useCache && _metadataCache.containsKey(url)) {
        final cacheTime = _cacheTime[url];
        if (cacheTime != null &&
            DateTime.now().difference(cacheTime) < _cacheTTL) {
          LogService.d('Cache hit for $url', _tag);
          return _metadataCache[url]!;
        }
      }

      LogService.d(
        'Fetching metadata (flat=$flat) via Native yt-dlp for $url',
        _tag,
      );

      String? cookieString = cookies;
      if (cookieString == null && cookiePath != null) {
        try {
          cookieString = await File(cookiePath).readAsString();
        } catch (e) {
          LogService.w('Could not read cookies from $cookiePath: $e', _tag);
        }
      }

      final metadata = await _platform.getInfo(
        url,
        cookies: cookieString,
        flat: flat,
        fields: fields,
      );

      // Cache the result
      _metadataCache[url] = metadata;
      _cacheTime[url] = DateTime.now();

      LogService.d('Metadata fetched successfully for $url', _tag);
      return metadata;
    } catch (e) {
      LogService.e('Error fetching metadata for $url: $e', _tag);

      return {
        'id': 'unknown',
        'title': 'Unavailable',
        'error': true,
        'message': e.toString(),
      };
    }
  }

  /// Fetches only the essential metadata fields for a video/playlist
  Future<Map<String, dynamic>> fetchBasicMetadata(String url) async {
    return fetchMetadata(
      url,
      flat: true,
      fields: const [
        'id',
        'title',
        'thumbnail',
        'upload_date',
        'view_count',
        'uploader',
        'channel',
        'duration',
        'webpage_url',
      ],
    );
  }

  /// Get video info using enhanced method (direct yt-dlp)
  Future<Map<String, dynamic>> getEnhancedVideoInfo(String url) async {
    LogService.d('Getting enhanced video info for $url', _tag);

    try {
      final result = await _platform.getEnhancedVideoInfo(url);
      LogService.d('Enhanced video info fetched successfully', _tag);
      return result;
    } catch (e) {
      LogService.e('Enhanced video info failed: $e', _tag);
      rethrow;
    }
  }

  /// Get subtitles/captions for a video
  Future<List<dynamic>> getCaptions(
    String url, {
    String? cookiePath,
    String? cookies,
  }) async {
    try {
      LogService.d('Fetching captions for $url', _tag);

      final metadata = await fetchMetadata(
        url,
        cookiePath: cookiePath,
        cookies: cookies,
      );

      final subtitles = metadata['subtitles'] as Map?;
      if (subtitles == null) return [];

      final captions = <dynamic>[];
      for (final entry in subtitles.entries) {
        captions.add({
          'lang': entry.key,
          'name': entry.key,
          'type': 'subtitle',
        });
      }

      return captions;
    } catch (e) {
      LogService.e('Error fetching captions: $e', _tag);
      return [];
    }
  }

  /// Get user playlists
  Future<List<Map<String, dynamic>>> getUserPlaylists({String? cookies}) async {
    try {
      final result = await _platform.getUserPlaylists(cookies: cookies);
      return result;
    } catch (e) {
      LogService.e('Error fetching playlists: $e', _tag);
      return [];
    }
  }

  /// Get audio tracks from yt-dlp metadata
  Future<List<dynamic>> getAudioTracks(String url) async {
    try {
      LogService.d('Fetching audio tracks for $url', _tag);

      final metadata = await fetchMetadata(url);

      final formats = metadata['formats'] as List?;
      if (formats == null) return [];

      final audioTracks = <dynamic>[];
      for (final format in formats) {
        if (format['acodec'] != 'none') {
          audioTracks.add({
            'itag': format['format_id'],
            'lang': format['language'],
            'name': format['format'],
            'type': 'audio',
          });
        }
      }

      return audioTracks;
    } catch (e) {
      LogService.e('Error fetching audio tracks: $e', _tag);
      return [];
    }
  }

  void clearCache() {
    _metadataCache.clear();
    _cacheTime.clear();
    LogService.d('Metadata cache cleared', _tag);
  }
}
