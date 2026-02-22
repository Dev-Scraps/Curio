import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/services/storage/database.dart';
import '../../core/services/storage/storage.dart';
import '../../domain/entities/playlist.dart';

part 'playlists_provider.g.dart';

/// Provider for user's playlists
@riverpod
Future<List<Playlist>> playlists(Ref ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final storageService = ref.watch(storageServiceProvider);

  // Return cached playlists from DB
  final playlistsData = await databaseService.getPlaylists();
  final playlists = playlistsData
      .map((json) => Playlist.fromJson(json))
      .toList();

  // Update video counts from database
  final updatedPlaylists = <Playlist>[];
  for (final playlist in playlists) {
    try {
      final videos = await databaseService.getVideos(playlistId: playlist.id);
      final realCount = videos.length;
      updatedPlaylists.add(playlist.copyWith(videoCount: realCount));
    } catch (_) {
      updatedPlaylists.add(playlist);
    }
  }

  // Apply custom order if available
  final order = storageService.playlistOrder;
  if (order.isNotEmpty) {
    debugPrint('[playlistsProvider] Applying custom order: $order');
    // Robust sorting: prioritize items in the saved order,
    // fall back to default order for new items.
    final orderMap = {for (var i = 0; i < order.length; i++) order[i]: i};

    updatedPlaylists.sort((a, b) {
      final posA = orderMap[a.id];
      final posB = orderMap[b.id];

      if (posA != null && posB != null) {
        return posA.compareTo(posB);
      }

      // If one is missing, keep the missing one at the end
      if (posA != null) return -1;
      if (posB != null) return 1;

      // If both missing, keep original order
      return 0;
    });

    debugPrint(
      '[playlistsProvider] Sorted order: ${updatedPlaylists.map((p) => p.id).toList()}',
    );
  } else {
    debugPrint('[playlistsProvider] No custom order found in storage');
  }

  return updatedPlaylists;
}
