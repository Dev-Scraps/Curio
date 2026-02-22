import 'package:curio/core/services/storage/database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/video.dart';

part 'videos_provider.g.dart';

/// Provider for liked videos
@riverpod
Future<List<Video>> likedVideos(Ref ref) async {
  final databaseService = ref.watch(databaseServiceProvider);

  final videosData = await databaseService.getVideos(isLiked: true);
  return videosData.map((json) => Video.fromJson(json)).toList();
}

/// Provider for watch later videos
@riverpod
Future<List<Video>> watchLaterVideos(Ref ref) async {
  final databaseService = ref.watch(databaseServiceProvider);

  final videosData = await databaseService.getVideos(isWatchLater: true);
  return videosData.map((json) => Video.fromJson(json)).toList();
}

/// Provider for playlist videos
@riverpod
Future<List<Video>> playlistVideos(Ref ref, String playlistId) async {
  final databaseService = ref.watch(databaseServiceProvider);

  final videosData = await databaseService.getVideos(playlistId: playlistId);
  return videosData.map((json) => Video.fromJson(json)).toList();
}

/// Provider for downloaded videos
@riverpod
Future<List<Video>> downloadedVideos(Ref ref) async {
  final databaseService = ref.watch(databaseServiceProvider);

  final videosData = await databaseService.getVideos(isDownloaded: true);
  return videosData.map((json) => Video.fromJson(json)).toList();
}
