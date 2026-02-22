import '../entities/video_progress.dart';

abstract class VideoProgressRepository {
  /// Get progress for a video
  Future<VideoProgress?> getProgress(String videoId);

  /// Save progress for a video
  Future<void> saveProgress(VideoProgress progress);

  /// Get all progress
  Future<List<VideoProgress>> getAllProgress();

  /// Delete progress for a video
  Future<void> deleteProgress(String videoId);

  /// Get videos in progress (>0% and <100%)
  Future<List<VideoProgress>> getInProgressVideos();

  /// Get completed videos
  Future<List<VideoProgress>> getCompletedVideos();

  /// Clear all progress (dangerous!)
  Future<void> clearAllProgress();
}
