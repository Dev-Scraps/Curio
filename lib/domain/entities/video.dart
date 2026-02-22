class Video {
  final String id;
  final String title;
  final String channelName;
  final String channelId;
  final String viewCount;
  final String uploadDate;
  final String duration;
  final String thumbnailUrl;
  final bool isShort;
  final double? downloadProgress;
  final String? playlistId;
  final int? position;
  final DateTime? addedDate;
  final bool isLiked;
  final bool isWatchLater;
  final String? description;
  final String? url;
  final bool isDownloaded;
  final String? filePath;
  // Non-persisted rich metadata (kept in-memory only)
  final List<SubtitleTrack> subtitles;
  final List<Chapter> chapters;
  final List<SponsorSegment> sponsorSegments;
  final List<String> tags;
  final List<String> categories;
  final String? channelUrl;

  const Video({
    required this.id,
    required this.title,
    required this.channelName,
    required this.channelId,
    required this.viewCount,
    required this.uploadDate,
    required this.duration,
    required this.thumbnailUrl,
    this.isShort = false,
    this.downloadProgress,
    this.playlistId,
    this.position,
    this.addedDate,
    this.isLiked = false,
    this.isWatchLater = false,
    this.description,
    this.url,
    this.isDownloaded = false,
    this.filePath,
    this.subtitles = const [],
    this.chapters = const [],
    this.sponsorSegments = const [],
    this.tags = const [],
    this.categories = const [],
    this.channelUrl,
  });

  Video copyWith({
    String? id,
    String? title,
    String? channelName,
    String? channelId,
    String? viewCount,
    String? uploadDate,
    String? duration,
    String? thumbnailUrl,
    bool? isShort,
    double? downloadProgress,
    String? playlistId,
    int? position,
    DateTime? addedDate,
    bool? isLiked,
    bool? isWatchLater,
    String? description,
    String? url,
    bool? isDownloaded,
    String? filePath,
    List<SubtitleTrack>? subtitles,
    List<Chapter>? chapters,
    List<SponsorSegment>? sponsorSegments,
    List<String>? tags,
    List<String>? categories,
    String? channelUrl,
  }) {
    return Video(
      id: id ?? this.id,
      title: title ?? this.title,
      channelName: channelName ?? this.channelName,
      channelId: channelId ?? this.channelId,
      viewCount: viewCount ?? this.viewCount,
      uploadDate: uploadDate ?? this.uploadDate,
      duration: duration ?? this.duration,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isShort: isShort ?? this.isShort,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      playlistId: playlistId ?? this.playlistId,
      position: position ?? this.position,
      addedDate: addedDate ?? this.addedDate,
      isLiked: isLiked ?? this.isLiked,
      isWatchLater: isWatchLater ?? this.isWatchLater,
      description: description ?? this.description,
      url: url ?? this.url,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      filePath: filePath ?? this.filePath,
      subtitles: subtitles ?? this.subtitles,
      chapters: chapters ?? this.chapters,
      sponsorSegments: sponsorSegments ?? this.sponsorSegments,
      tags: tags ?? this.tags,
      categories: categories ?? this.categories,
      channelUrl: channelUrl ?? this.channelUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'channelName': channelName,
      'channelId': channelId,
      'viewCount': viewCount,
      'uploadDate': uploadDate,
      'duration': duration,
      'thumbnailUrl': thumbnailUrl,
      'isShort': isShort,
      'playlistId': playlistId,
      'position': position,
      'addedDate': addedDate?.toIso8601String(),
      'isLiked': isLiked,
      'isWatchLater': isWatchLater,
      'description': description,
      'url': url,
      'isDownloaded': isDownloaded,
      'filePath': filePath,
      // Rich metadata (subtitles/chapters/etc.) is intentionally not persisted
      // to avoid DB schema changes; it is kept in-memory only.
    };
  }

  factory Video.fromJson(Map<String, dynamic> json) {
    // Helper to format view count
    String formatViewCount(dynamic count) {
      if (count == null) return '0';
      if (count is int) {
        if (count >= 1000000) {
          return '${(count / 1000000).toStringAsFixed(1)}M';
        } else if (count >= 1000) {
          return '${(count / 1000).toStringAsFixed(1)}K';
        }
        return count.toString();
      }
      if (count is String) {
        final numCount = int.tryParse(count);
        if (numCount != null) {
          return formatViewCount(numCount);
        }
      }
      return count?.toString() ?? '0';
    }

    return Video(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
      channelName: json['channel']?.toString() ??
          json['uploader']?.toString() ??
          json['channelName']?.toString() ??
          json['creator']?.toString() ??
          json['artist']?.toString() ??
          json['author']?.toString() ??
          'Unknown Channel',
      channelId: json['channel_id']?.toString() ?? 
          json['channelId']?.toString() ?? 
          json['uploader_id']?.toString() ??
          '',
      viewCount: formatViewCount(json['view_count'] ?? json['viewCount']),
      uploadDate: json['upload_date']?.toString() ??
          json['uploadDate']?.toString() ??
          json['timestamp']?.toString() ??
          json['release_date']?.toString() ??
          '',
      duration: _parseDuration(json),
      thumbnailUrl: _extractThumbnail(json),
      isShort: _parseBool(json['isShort']),
      playlistId: json['playlistId']?.toString(),
      position: _parseInt(json['position']),
      addedDate: json['addedDate'] != null
          ? DateTime.parse(json['addedDate'] as String)
          : null,
      isLiked: _parseBool(json['isLiked']),
      isWatchLater: _parseBool(json['isWatchLater']),
      description: json['description']?.toString(),
      url: json['url']?.toString() ?? json['webpage_url']?.toString(),
      isDownloaded: _parseBool(json['isDownloaded']),
      filePath: json['filePath']?.toString(),
      subtitles: _parseSubtitles(json),
      chapters: _parseChapters(json),
      sponsorSegments: _parseSponsorSegments(json),
      tags: _parseStringList(json['tags']),
      categories: _parseStringList(json['categories']),
      channelUrl:
          json['channel_url']?.toString() ?? json['uploader_url']?.toString(),
    );
  }

  static bool _parseBool(dynamic value) {
    if (value == true) return true;
    if (value == 1) return true;
    if (value == 'true') return true;
    return false;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Parse duration from various formats in JSON
  static String _parseDuration(Map<String, dynamic> json) {
    // Try direct duration string first
    if (json['duration_string']?.toString().isNotEmpty == true) {
      return json['duration_string']!.toString();
    }

    // Try duration in seconds
    final duration = json['duration'];
    if (duration != null) {
      if (duration is int || duration is double) {
        final seconds = duration.toInt();
        final minutes = seconds ~/ 60;
        final remainingSeconds = seconds % 60;
        return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
      } else if (duration is String) {
        // If it's already in MM:SS format
        if (duration.contains(':')) {
          return duration;
        }
        // Try to parse as seconds
        final seconds = int.tryParse(duration);
        if (seconds != null) {
          final minutes = seconds ~/ 60;
          final remainingSeconds = seconds % 60;
          return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
        }
      }
    }
    return '0:00';
  }

  /// Extract thumbnail URL from yt-dlp JSON response
  /// Handles multiple thumbnail sources and selects best quality
  static String _extractThumbnail(Map<String, dynamic> json) {
    // Try direct thumbnail URL
    if (json['thumbnail'] is String) {
      return json['thumbnail']!;
    }
    if (json['thumbnail_url'] is String) {
      return json['thumbnail_url']!;
    }
    
    // Try thumbnails array
    if (json['thumbnails'] is List && (json['thumbnails'] as List).isNotEmpty) {
      // Get the highest resolution thumbnail
      final thumbnails = List<Map<String, dynamic>>.from(json['thumbnails']);
      if (thumbnails.isNotEmpty) {
        // Sort by resolution, highest first
        thumbnails.sort((a, b) {
          final aRes = (a['width'] as int? ?? 0) * (a['height'] as int? ?? 0);
          final bRes = (b['width'] as int? ?? 0) * (b['height'] as int? ?? 0);
          return bRes.compareTo(aRes);
        });
        return thumbnails.first['url']?.toString() ?? '';
      }
    }
    
    // Fallback to YouTube thumbnail URL
    final videoId = json['id']?.toString();
    if (videoId != null) {
      return 'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg';
    }
    
    return '';
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }

  static List<SubtitleTrack> _parseSubtitles(Map<String, dynamic> json) {
    final subs = <SubtitleTrack>[];
    final raw = json['subtitles'] ?? json['automatic_captions'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          final url = item['url']?.toString();
          if (url != null && url.isNotEmpty) {
            subs.add(
              SubtitleTrack(
                lang: item['lang']?.toString() ?? '',
                name: item['name']?.toString(),
                url: url,
                ext: item['ext']?.toString(),
                autoGenerated: _parseBool(item['auto_generated']),
              ),
            );
          }
        }
      }
    }
    return subs;
  }

  static List<Chapter> _parseChapters(Map<String, dynamic> json) {
    final out = <Chapter>[];
    final raw = json['chapters'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          out.add(
            Chapter(
              title: item['title']?.toString() ?? '',
              startTime: (item['start_time'] as num?)?.toDouble() ?? 0,
              endTime: (item['end_time'] as num?)?.toDouble() ?? 0,
            ),
          );
        }
      }
    }
    return out;
  }

  static List<SponsorSegment> _parseSponsorSegments(
    Map<String, dynamic> json,
  ) {
    final out = <SponsorSegment>[];
    final raw = json['sponsorblock_chapters'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          out.add(
            SponsorSegment(
              category: item['category']?.toString() ?? '',
              startTime: (item['start_time'] as num?)?.toDouble() ?? 0,
              endTime: (item['end_time'] as num?)?.toDouble() ?? 0,
              title: item['title']?.toString() ?? '',
            ),
          );
        }
      }
    }
    return out;
  }
}

class SubtitleTrack {
  final String lang;
  final String? name;
  final String url;
  final String? ext;
  final bool autoGenerated;

  const SubtitleTrack({
    required this.lang,
    required this.url,
    this.name,
    this.ext,
    this.autoGenerated = false,
  });
}

class Chapter {
  final String title;
  final double startTime;
  final double endTime;

  const Chapter({
    required this.title,
    required this.startTime,
    required this.endTime,
  });
}

class SponsorSegment {
  final String category;
  final double startTime;
  final double endTime;
  final String title;

  const SponsorSegment({
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.title,
  });
}
