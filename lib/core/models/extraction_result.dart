import 'video_info.dart';
import 'playlist_info.dart';

/// Unified result from yt-dlp extraction
/// Can be either a single video or a playlist
class ExtractionResult {
  final bool isError;
  final String? errorMessage;
  final VideoInfo? video;
  final PlaylistInfo? playlist;

  ExtractionResult._({
    required this.isError,
    this.errorMessage,
    this.video,
    this.playlist,
  });

  /// Create error result
  factory ExtractionResult.error(String message) {
    return ExtractionResult._(
      isError: true,
      errorMessage: message,
    );
  }

  /// Create success result with video
  factory ExtractionResult.video(VideoInfo video) {
    return ExtractionResult._(
      isError: false,
      video: video,
    );
  }

  /// Create success result with playlist
  factory ExtractionResult.playlist(PlaylistInfo playlist) {
    return ExtractionResult._(
      isError: false,
      playlist: playlist,
    );
  }

  /// Parse from JSON response
  factory ExtractionResult.fromJson(Map<String, dynamic> json) {
    final hasError = json['error'] == true;
    
    if (hasError) {
      return ExtractionResult.error(
        json['message'] as String? ?? 'Unknown error',
      );
    }

    // Check if this is a playlist response
    final type = json['_type'] as String?;
    final entries = json['entries'] as List<dynamic>?;
    
    if (type == 'playlist' || entries != null) {
      return ExtractionResult.playlist(PlaylistInfo.fromJson(json));
    } else {
      return ExtractionResult.video(VideoInfo.fromJson(json));
    }
  }

  /// Check if result is a playlist
  bool get isPlaylist => playlist != null;

  /// Check if result is a single video
  bool get isVideo => video != null;

  /// Check if extraction was successful
  bool get isSuccess => !isError;
}
