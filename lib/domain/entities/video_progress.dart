/// Video progress tracking model
class VideoProgress {
  final String videoId;
  final int watchedDuration; // in seconds
  final int totalDuration; // in seconds
  final DateTime lastWatched;
  final bool isCompleted;
  final int quality; // 0 = auto, 144, 240, 360, 480, 720, 1080, 2160

  const VideoProgress({
    required this.videoId,
    required this.watchedDuration,
    required this.totalDuration,
    required this.lastWatched,
    this.isCompleted = false,
    this.quality = 0,
  });

  /// Get completion percentage (0-100)
  int get completionPercentage {
    if (totalDuration == 0) return 0;
    final percentage = (watchedDuration / totalDuration * 100).toInt();
    return percentage.clamp(0, 100);
  }

  /// Check if video is mostly watched (>90%)
  bool get isMostlyWatched => completionPercentage >= 90;

  /// Check if video is partially watched (>0% and <90%)
  bool get isPartiallyWatched =>
      completionPercentage > 0 && completionPercentage < 90;

  /// Get human-readable status
  String get statusText {
    if (isCompleted) return '✓ Completed';
    if (completionPercentage == 0) return 'Not watched';
    if (isMostlyWatched) return 'Almost done';
    if (isPartiallyWatched) return 'In progress';
    return 'Not watched';
  }

  /// Get remaining duration in seconds
  int get remainingDuration =>
      (totalDuration - watchedDuration).clamp(0, totalDuration);

  /// Get human-readable remaining time
  String get remainingTimeText {
    if (isCompleted || remainingDuration == 0) return 'Finished';
    final minutes = remainingDuration ~/ 60;
    final seconds = remainingDuration % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s left';
    }
    return '${seconds}s left';
  }

  VideoProgress copyWith({
    String? videoId,
    int? watchedDuration,
    int? totalDuration,
    DateTime? lastWatched,
    bool? isCompleted,
    int? quality,
  }) {
    return VideoProgress(
      videoId: videoId ?? this.videoId,
      watchedDuration: watchedDuration ?? this.watchedDuration,
      totalDuration: totalDuration ?? this.totalDuration,
      lastWatched: lastWatched ?? this.lastWatched,
      isCompleted: isCompleted ?? this.isCompleted,
      quality: quality ?? this.quality,
    );
  }

  @override
  String toString() =>
      'VideoProgress($videoId, $completionPercentage%, $statusText)';
}
