// playlist.dart - Enhanced entity with complete metadata
class Playlist {
  final String id;
  final String title;
  final String? description;
  final int videoCount;
  final String? thumbnailUrl;
  final String uploader;
  final String? uploaderUrl;
  final DateTime? lastUpdated;
  final bool isLiked;
  final bool isWatchLater;

  // New fields for complete metadata
  final String? channel;
  final String? channelId;
  final String? channelUrl;
  final String? availability; // public, private, unlisted
  final String? modifiedDate; // Raw date string from yt-dlp
  final int? viewCount;

  const Playlist({
    required this.id,
    required this.title,
    this.description,
    required this.videoCount,
    this.thumbnailUrl,
    required this.uploader,
    this.uploaderUrl,
    this.lastUpdated,
    this.isLiked = false,
    this.isWatchLater = false,
    this.channel,
    this.channelId,
    this.channelUrl,
    this.availability,
    this.modifiedDate,
    this.viewCount,
  });

  Playlist copyWith({
    String? id,
    String? title,
    String? description,
    int? videoCount,
    String? thumbnailUrl,
    String? uploader,
    String? uploaderUrl,
    DateTime? lastUpdated,
    bool? isLiked,
    bool? isWatchLater,
    String? channel,
    String? channelId,
    String? channelUrl,
    String? availability,
    String? modifiedDate,
    int? viewCount,
  }) {
    return Playlist(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      videoCount: videoCount ?? this.videoCount,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      uploader: uploader ?? this.uploader,
      uploaderUrl: uploaderUrl ?? this.uploaderUrl,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isLiked: isLiked ?? this.isLiked,
      isWatchLater: isWatchLater ?? this.isWatchLater,
      channel: channel ?? this.channel,
      channelId: channelId ?? this.channelId,
      channelUrl: channelUrl ?? this.channelUrl,
      availability: availability ?? this.availability,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      viewCount: viewCount ?? this.viewCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'videoCount': videoCount,
      'thumbnailUrl': thumbnailUrl,
      'uploader': uploader,
      'uploaderUrl': uploaderUrl,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'isLiked': isLiked,
      'isWatchLater': isWatchLater,
      'channel': channel,
      'channelId': channelId,
      'channelUrl': channelUrl,
      'availability': availability,
      'modifiedDate': modifiedDate,
      'viewCount': viewCount,
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    // Parse modified date to DateTime if available
    DateTime? lastUpdated;
    final modifiedDateStr =
        json['modified_date'] as String? ?? json['upload_date'] as String?;
    if (modifiedDateStr != null && modifiedDateStr.length == 8) {
      // yt-dlp format: YYYYMMDD
      try {
        final year = modifiedDateStr.substring(0, 4);
        final month = modifiedDateStr.substring(4, 6);
        final day = modifiedDateStr.substring(6, 8);
        lastUpdated = DateTime.parse('$year-$month-$day');
      } catch (e) {
        // Invalid date format, ignore
      }
    } else if (json['lastUpdated'] != null) {
      try {
        lastUpdated = DateTime.parse(json['lastUpdated'] as String);
      } catch (e) {
        // Invalid date format, ignore
      }
    }

    return Playlist(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      videoCount:
          json['videoCount'] as int? ??
          json['playlist_count'] as int? ??
          json['video_count'] as int? ??
          json['n_entries'] as int? ??
          0,
      thumbnailUrl:
          json['thumbnailUrl'] as String? ?? json['thumbnail'] as String?,
      uploader:
          json['uploader'] as String? ??
          json['channel'] as String? ??
          'Unknown',
      uploaderUrl:
          json['uploaderUrl'] as String? ??
          json['channel_url'] as String? ??
          json['uploader_url'] as String?,
      lastUpdated: lastUpdated,
      isLiked: json['id'] == 'LL' || _parseBool(json['isLiked']),
      isWatchLater: json['id'] == 'WL' || _parseBool(json['isWatchLater']),

      // New fields
      channel: json['channel'] as String? ?? json['uploader'] as String?,
      channelId:
          json['channel_id'] as String? ?? json['uploader_id'] as String?,
      channelUrl:
          json['channel_url'] as String? ?? json['uploader_url'] as String?,
      availability: json['availability'] as String?,
      modifiedDate: modifiedDateStr,
      viewCount: json['view_count'] as int?,
    );
  }

  static bool _parseBool(dynamic value) {
    if (value == true) return true;
    if (value == 1) return true;
    if (value == 'true') return true;
    return false;
  }

  // Helper getters
  bool get isPrivate => availability == 'private';
  bool get isPublic => availability == 'public';
  bool get isUnlisted => availability == 'unlisted';

  String get displayUploader => channel ?? uploader;

  String get statusBadge {
    if (isPrivate) return '🔒 Private';
    if (isUnlisted) return '🔗 Unlisted';
    if (isPublic) return '🌐 Public';
    return '';
  }
}
