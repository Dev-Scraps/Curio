import 'package:curio/core/services/content/sync.dart';
import 'package:curio/core/services/storage/storage.dart';
import 'package:curio/presentation/common/progress_indicators.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../presentation/screens/player/viewmodels/viewmodel.dart';
import '../../../core/utils/error_handler.dart';
import '../../../domain/entities/video.dart';

import '../../common/empty_state.dart';
import '../../common/playlist_card.dart';
import '../../common/playlist_card_skeleton.dart';
import '../../common/shimmer_loading.dart';
import '../../providers/playlists_provider.dart';
import '../../providers/videos_provider.dart';
import '../../../domain/entities/playlist.dart';

import '../player/player_screen.dart';
import '../playlist/playlist_screen.dart';
import '../search/search_results_screen.dart';
import '../settings/settings_screen.dart';
import '../setup/setup_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _startSync() async {
    try {
      await ref.read(syncServiceProvider.notifier).syncFullLibrary();
      ref.invalidate(playlistsProvider);
      ref.invalidate(likedVideosProvider);
      ref.invalidate(watchLaterVideosProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedFavourite,
                    color: Theme.of(context).colorScheme.primary,
                    size: 16,
                  ),
                ),
                const Gap(12),
                Text(
                  'Library synced successfully',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).cardColor,
            behavior: SnackBarBehavior.floating,
            elevation: 4,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
              ),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorHandler.getUserFriendlyMessage(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _isRearranging = false;
  bool _isSaving = false;
  List<Playlist>? _rearrangingList;

  Widget _buildContent() {
    final playlistsAsync = ref.watch(playlistsProvider);

    return playlistsAsync.when(
      data: (playlists) {
        if (playlists.isEmpty) {
          return SliverToBoxAdapter(
            child: NoPlaylistsEmptyState(onSync: _startSync),
          );
        }

        if (_isRearranging && _rearrangingList != null) {
          return SliverToBoxAdapter(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _rearrangingList!.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = _rearrangingList!.removeAt(oldIndex);
                  _rearrangingList!.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final playlist = _rearrangingList![index];
                return PlaylistCard(
                  key: ValueKey(playlist.id),
                  playlist: playlist,
                  isRearranging: true,
                  index: index,
                );
              },
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final playlist = playlists[index];
            return PlaylistCard(
              key: ValueKey(playlist.id),
              playlist: playlist,
              onLongPress: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  _isRearranging = true;
                  _rearrangingList = List<Playlist>.from(playlists);
                });
              },
            );
          }, childCount: playlists.length),
        );
      },
      loading: () => SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const PlaylistCardSkeleton(),
          childCount: 6,
        ),
      ),
      error: (e, s) => SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedInformationCircle,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const Gap(16),
                Text(
                  'Failed to load playlists',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Gap(8),
                Text(
                  ErrorHandler.getUserFriendlyMessage(e),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Gap(24),
                FilledButton.icon(
                  onPressed: () => ref.refresh(playlistsProvider),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedHome02,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncServiceProvider);

    return Scaffold(
      body: RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surface,
        onRefresh: () async {
          await _startSync();
          ref.invalidate(playlistsProvider);
          await ref.read(playlistsProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: false,
              snap: false,
              elevation: 0,
              centerTitle: true,
              title: Text(
                _isRearranging ? 'Rearrange Library' : 'My Library',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                if (_isRearranging)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Center(
                      child: TextButton(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                if (_rearrangingList != null) {
                                  setState(() => _isSaving = true);
                                  try {
                                    final order = _rearrangingList!
                                        .map((p) => p.id)
                                        .toList();
                                    debugPrint('Saving playlist order: $order');

                                    // Save to storage
                                    await ref
                                        .read(storageServiceProvider)
                                        .setPlaylistOrder(order);

                                    // Force refresh the provider
                                    ref.invalidate(playlistsProvider);
                                    await ref.read(playlistsProvider.future);
                                    debugPrint(
                                      'Provider refreshed with new order',
                                    );
                                  } catch (e) {
                                    debugPrint('Error saving reorder: $e');
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _isSaving = false;
                                        _isRearranging = false;
                                        _rearrangingList = null;
                                      });
                                    }
                                  }
                                } else {
                                  setState(() => _isRearranging = false);
                                }
                              },
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: M3CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Save',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }
}
