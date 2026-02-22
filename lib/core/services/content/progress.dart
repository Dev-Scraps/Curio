import 'dart:async';
import 'package:curio/core/services/storage/database.dart';
import 'package:curio/core/services/system/logger.dart';
import 'package:curio/domain/entities/video_progress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'progress.g.dart';

@Riverpod(keepAlive: true)
VideoProgressService videoProgressService(Ref ref) {
  return VideoProgressService(ref);
}

class VideoProgressService {
  final Ref _ref;
  static const _tag = 'VideoProgressService';

  // Stream for tracking updates
  final _updatesController = StreamController<String>.broadcast();
  Stream<String> get updates => _updatesController.stream;

  // In-memory cache for fast access
  final Map<String, VideoProgress> _progressCache = {};

  VideoProgressService(this._ref);

  DatabaseService get _db => _ref.read(databaseServiceProvider);

  /// Save or update video progress
  Future<void> saveProgress({
    required String videoId,
    required int watchedSeconds,
    required int totalSeconds,
    int? quality,
  }) async {
    try {
      final now = DateTime.now();
      final isCompleted =
          watchedSeconds >= totalSeconds - 10; // Within 10s of end

      final progressData = {
        'videoId': videoId,
        'watchedDuration': watchedSeconds,
        'totalDuration': totalSeconds,
        'lastWatched': now.millisecondsSinceEpoch,
        'isCompleted': isCompleted ? 1 : 0,
        'quality': quality ?? 0,
      };

      await _db.saveVideoProgress(progressData);

      // Update cache
      _progressCache[videoId] = VideoProgress(
        videoId: videoId,
        watchedDuration: watchedSeconds,
        totalDuration: totalSeconds,
        lastWatched: now,
        isCompleted: isCompleted,
        quality: quality ?? 0,
      );

      LogService.d(
        'Progress saved for $videoId: ${watchedSeconds}s/${totalSeconds}s',
        _tag,
      );
      _updatesController.add(videoId);
    } catch (e) {
      LogService.e('Error saving progress for $videoId: $e', _tag);
    }
  }

  /// Get video progress
  Future<VideoProgress?> getProgress(String videoId) async {
    try {
      // Check cache first
      if (_progressCache.containsKey(videoId)) {
        return _progressCache[videoId];
      }

      // Fetch from database
      final data = await _db.getVideoProgress(videoId);
      if (data == null) return null;

      final progress = VideoProgress(
        videoId: data['videoId'] as String,
        watchedDuration: data['watchedDuration'] as int,
        totalDuration: data['totalDuration'] as int,
        lastWatched: DateTime.fromMillisecondsSinceEpoch(
          data['lastWatched'] as int,
        ),
        isCompleted: (data['isCompleted'] as int) == 1,
        quality: data['quality'] as int? ?? 0,
      );

      // Update cache
      _progressCache[videoId] = progress;

      return progress;
    } catch (e) {
      LogService.e('Error getting progress for $videoId: $e', _tag);
      return null;
    }
  }

  /// Mark video as completed
  Future<void> markCompleted(String videoId, int totalSeconds) async {
    await saveProgress(
      videoId: videoId,
      watchedSeconds: totalSeconds,
      totalSeconds: totalSeconds,
    );
  }

  /// Clear progress for a specific video
  Future<void> clearProgress(String videoId) async {
    try {
      await _db.deleteVideoProgress(videoId);
      _progressCache.remove(videoId);
      LogService.d('Progress cleared for $videoId', _tag);
      _updatesController.add(videoId);
    } catch (e) {
      LogService.e('Error clearing progress for $videoId: $e', _tag);
    }
  }

  /// Get all video progress (for continue watching list)
  Future<List<VideoProgress>> getAllProgress() async {
    try {
      final dataList = await _db.getAllVideoProgress();
      return dataList.map((data) {
        return VideoProgress(
          videoId: data['videoId'] as String,
          watchedDuration: data['watchedDuration'] as int,
          totalDuration: data['totalDuration'] as int,
          lastWatched: DateTime.fromMillisecondsSinceEpoch(
            data['lastWatched'] as int,
          ),
          isCompleted: (data['isCompleted'] as int) == 1,
          quality: data['quality'] as int? ?? 0,
        );
      }).toList();
    } catch (e) {
      LogService.e('Error getting all progress: $e', _tag);
      return [];
    }
  }

  /// Clean up old progress entries (older than 30 days)
  Future<void> cleanupOldProgress({int daysOld = 30}) async {
    try {
      await _db.clearOldVideoProgress(daysOld: daysOld);
      _progressCache.clear(); // Clear cache after cleanup
      LogService.d('Cleared progress older than $daysOld days', _tag);
      _updatesController.add('ALL'); // Signal full refresh
    } catch (e) {
      LogService.e('Error cleaning up old progress: $e', _tag);
    }
  }

  /// Check if video should show resume prompt
  Future<bool> shouldShowResume(String videoId) async {
    final progress = await getProgress(videoId);
    if (progress == null) return false;

    // Show resume if:
    // - Not completed
    // - Watched more than 30 seconds
    // - More than 30 seconds remaining
    return !progress.isCompleted &&
        progress.watchedDuration > 30 &&
        progress.remainingDuration > 30;
  }

  /// Get resume position in seconds
  Future<int?> getResumePosition(String videoId) async {
    final progress = await getProgress(videoId);
    if (progress == null) return null;

    final shouldResume =
        !progress.isCompleted &&
        progress.watchedDuration > 30 &&
        progress.remainingDuration > 30;

    return shouldResume ? progress.watchedDuration : null;
  }
}
