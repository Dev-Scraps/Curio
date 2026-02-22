import 'video_info.dart';

/// Model representing playlist metadata from yt-dlp
class PlaylistInfo {
  final String? id;
  final String? title;
  final String? type;
  final String? uploader;
  final int? playlistCount;
  final List<VideoInfo> entries;

  PlaylistInfo({
    this.id,
    this.title,
    this.type,
    this.uploader,
    this.playlistCount,
    this.entries = const [],
  });

  factory PlaylistInfo.fromJson(Map<String, dynamic> json) {
    return PlaylistInfo(
      id: json['id'] as String?,
      title: json['title'] as String?,
      type: json['_type'] as String?,
      uploader: json['uploader'] as String?,
      playlistCount: json['playlist_count'] as int?,
      entries: (json['entries'] as List<dynamic>?)
              ?.map((e) => VideoInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      '_type': type,
      'uploader': uploader,
      'playlist_count': playlistCount,
      'entries': entries.map((e) => e.toJson()).toList(),
    };
  }

  /// Check if this is a valid playlist with entries
  bool get hasEntries => entries.isNotEmpty;

  /// Get total video count
  int get videoCount => entries.length;
}
