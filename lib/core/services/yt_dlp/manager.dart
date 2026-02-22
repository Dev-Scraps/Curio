import 'package:curio/core/services/yt_dlp/platform.dart';

class YtDlpManager {
  final YtDlpPlatformService _platform;

  YtDlpManager(this._platform);

  /// Entry point used by SyncService / UI
  Future<List<Map<String, dynamic>>> extract(String url) async {
    final cookies = await _platform.getCookies('https://www.youtube.com');

    final Map<String, dynamic> data = await _platform.getInfo(
      url,
      cookies: cookies,
    );

    // 🔥 PLAYLIST / FEED (LL, WL, normal playlist)
    if (_isPlaylist(data)) {
      final List entries = data['entries'] as List;

      final List<Map<String, dynamic>> videos = [];

      for (final entry in entries) {
        if (entry is! Map) continue;

        final videoUrl = entry['url'] ?? entry['webpage_url'];

        if (videoUrl == null) continue;

        try {
          final video = await _platform.getInfo(videoUrl, cookies: cookies);

          if (_isValidVideo(video)) {
            videos.add(video);
          }
        } catch (_) {
          // skip broken/private videos
        }
      }

      return videos;
    }

    // 🎥 SINGLE VIDEO
    if (_isValidVideo(data)) {
      return [data];
    }

    throw Exception('Unknown yt-dlp response');
  }

  bool _isPlaylist(Map<String, dynamic> json) {
    return json.containsKey('entries') && json['entries'] is List;
  }

  bool _isValidVideo(Map<String, dynamic> json) {
    return json['id'] != null && json['title'] != null;
  }
}
