/// Model representing video metadata from yt-dlp
class VideoInfo {
  final String id;
  final String title;
  final int? duration;
  final String? uploader;
  final String? channelId;
  final List<Thumbnail> thumbnails;
  final List<Format> formats;

  VideoInfo({
    required this.id,
    required this.title,
    this.duration,
    this.uploader,
    this.channelId,
    this.thumbnails = const [],
    this.formats = const [],
  });

  factory VideoInfo.fromJson(Map<String, dynamic> json) {
    return VideoInfo(
      id: json['id'] as String,
      title: json['title'] as String,
      duration: json['duration'] as int?,
      uploader: json['uploader'] as String?,
      channelId: json['channel_id'] as String?,
      thumbnails: (json['thumbnails'] as List<dynamic>?)
              ?.map((t) => Thumbnail.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      formats: (json['formats'] as List<dynamic>?)
              ?.map((f) => Format.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'duration': duration,
      'uploader': uploader,
      'channel_id': channelId,
      'thumbnails': thumbnails.map((t) => t.toJson()).toList(),
      'formats': formats.map((f) => f.toJson()).toList(),
    };
  }

  /// Get best thumbnail URL
  String? get bestThumbnailUrl {
    if (thumbnails.isEmpty) return null;
    // Sort by resolution (width * height) and return highest
    final sorted = [...thumbnails]
      ..sort((a, b) {
        final aRes = (a.width ?? 0) * (a.height ?? 0);
        final bRes = (b.width ?? 0) * (b.height ?? 0);
        return bRes.compareTo(aRes);
      });
    return sorted.first.url;
  }

  /// Format duration as human-readable string (e.g., "1:23:45")
  String? get formattedDuration {
    if (duration == null) return null;
    final hours = duration! ~/ 3600;
    final minutes = (duration! % 3600) ~/ 60;
    final seconds = duration! % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }
}

/// Thumbnail metadata
class Thumbnail {
  final String? url;
  final int? width;
  final int? height;

  Thumbnail({
    this.url,
    this.width,
    this.height,
  });

  factory Thumbnail.fromJson(Map<String, dynamic> json) {
    return Thumbnail(
      url: json['url'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'width': width,
      'height': height,
    };
  }
}

/// Video format/quality option
class Format {
  final String? formatId;
  final String? ext;
  final int? width;
  final int? height;
  final String? formatNote;
  final double? fps;
  final int? filesize;
  final String? vcodec;
  final String? acodec;
  final int? abr;
  final int? tbr;

  Format({
    this.formatId,
    this.ext,
    this.width,
    this.height,
    this.formatNote,
    this.fps,
    this.filesize,
    this.vcodec,
    this.acodec,
    this.abr,
    this.tbr,
  });

  factory Format.fromJson(Map<String, dynamic> json) {
    return Format(
      formatId: json['format_id'] as String?,
      ext: json['ext'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      formatNote: json['format_note'] as String?,
      fps: (json['fps'] as num?)?.toDouble(),
      filesize: json['filesize'] as int?,
      vcodec: json['vcodec'] as String?,
      acodec: json['acodec'] as String?,
      abr: json['abr'] as int?,
      tbr: json['tbr'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'format_id': formatId,
      'ext': ext,
      'width': width,
      'height': height,
      'format_note': formatNote,
      'fps': fps,
      'filesize': filesize,
      'vcodec': vcodec,
      'acodec': acodec,
      'abr': abr,
      'tbr': tbr,
    };
  }

  /// Get resolution string (e.g., "1920x1080")
  String? get resolution {
    if (width != null && height != null) {
      return '${width}x$height';
    }
    return null;
  }

  /// Check if format has video
  bool get hasVideo => vcodec != null && vcodec != 'none';

  /// Check if format has audio
  bool get hasAudio => acodec != null && acodec != 'none';
}
