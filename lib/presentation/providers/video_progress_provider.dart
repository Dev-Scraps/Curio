import 'package:curio/core/services/content/progress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/video_progress.dart';

// Get progress for a specific video
final videoProgressStreamProvider =
    StreamProvider.family<VideoProgress?, String>((ref, videoId) async* {
      final service = ref.watch(videoProgressServiceProvider);

      // Yield initial value
      yield await service.getProgress(videoId);

      // Listen for updates
      await for (final updatedId in service.updates) {
        if (updatedId == videoId || updatedId == 'ALL') {
          yield await service.getProgress(videoId);
        }
      }
    });

// Get all progress
final allVideoProgressStreamProvider = StreamProvider<List<VideoProgress>>((
  ref,
) async* {
  final service = ref.watch(videoProgressServiceProvider);

  // Yield initial value
  yield await service.getAllProgress();

  // Listen for updates
  await for (final updatedId in service.updates) {
    // Refresh for any update
    yield await service.getAllProgress();
  }
});

// Get videos in progress
final inProgressVideosProvider = FutureProvider<List<VideoProgress>>((
  ref,
) async {
  final service = ref.watch(videoProgressServiceProvider);
  final all = await service.getAllProgress();
  return all.where((p) => !p.isCompleted && p.watchedDuration > 0).toList();
});

// Get completed videos
final completedVideosProvider = FutureProvider<List<VideoProgress>>((
  ref,
) async {
  final service = ref.watch(videoProgressServiceProvider);
  final all = await service.getAllProgress();
  return all.where((p) => p.isCompleted).toList();
});
