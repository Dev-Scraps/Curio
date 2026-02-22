import 'dart:ui';
import 'package:curio/core/services/content/downloader.dart';
import 'package:curio/core/services/content/sync.dart';
import 'package:curio/domain/entities/video.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/utils/error_handler.dart';
import '../../common/shimmer_loading.dart';
import '../../common/video_card.dart';
import '../../common/skeleton_loader.dart';
import '../../common/bottom_sheet_helper.dart';
import '../../common/rounded_search_bar.dart';
import '../download/widgets/download_configure_modal.dart';
import '../player/player_screen.dart';
import '../../common/empty_state.dart';
import '../../providers/videos_provider.dart';

class LikedScreen extends ConsumerStatefulWidget {
  const LikedScreen({super.key});

  @override
  ConsumerState<LikedScreen> createState() => _LikedScreenState();
}

class _LikedScreenState extends ConsumerState<LikedScreen> {
  String _searchQuery = '';
  int _selectedType = 0;
  final Set<String> _loadingVideoIds = {};

  int _parseDurationToSeconds(String duration) {
    final direct = int.tryParse(duration);
    if (direct != null) {
      return direct;
    }

    final parts = duration.split(':');
    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]) ?? 0;
      final seconds = int.tryParse(parts[1]) ?? 0;
      return minutes * 60 + seconds;
    } else if (parts.length == 3) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1]) ?? 0;
      final seconds = int.tryParse(parts[2]) ?? 0;
      return hours * 3600 + minutes * 60 + seconds;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncServiceProvider);

    return Scaffold(
      body: RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surface,
        onRefresh: _syncLikedVideos,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: false,
              snap: false,
              elevation: 0,
              centerTitle: true,
              title: Text(
                'Liked',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    // Search Bar
                    RoundedSearchBar(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      hintText: 'Search liked videos...',
                    ),
                    const Gap(16),
                    _buildPremiumSegmentControl(),
                  ],
                ),
              ),
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

  Widget _buildPremiumSegmentControl() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          _buildSegmentOption(0, 'Videos'),
          _buildSegmentOption(1, 'Shorts'),
        ],
      ),
    );
  }

  Widget _buildSegmentOption(int index, String label) {
    final isSelected = _selectedType == index;
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.secondaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(32),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isSelected
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.hintColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final videosAsync = ref.watch(likedVideosProvider);

    // Optimized for incremental updates: Show data if available, even if currently refreshing
    if (videosAsync.hasValue) {
      final videos = videosAsync.value!;
      final filteredVideos = videos.where((v) {
        // Filter by type (Shorts/Videos)
        final durationSeconds = _parseDurationToSeconds(v.duration);
        final isTypeMatch = _selectedType == 0
            ? durationSeconds >= 120
            : durationSeconds < 120;

        if (!isTypeMatch) return false;

        // Filter by search query
        if (_searchQuery.isEmpty) return true;
        return v.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            v.channelName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();

      if (filteredVideos.isEmpty) {
        // Only show empty state if we really have 0 relevant videos and aren't loading initial
        if (videos.isEmpty && !videosAsync.isLoading) {
          return SliverToBoxAdapter(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    200, // Approximate available space
              ),
              child: NoLikedVideosEmptyState(onSync: _syncLikedVideos),
            ),
          );
        }
        if (videos.isEmpty && videosAsync.isLoading) {
          // Initial load empty but loading
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => const VideoCardSkeleton(),
              childCount: 5,
            ),
          );
        }

        // "No Shorts found" / "No Videos found" case (when some exist but filtered out)
        return SliverToBoxAdapter(
          child: RefreshIndicator(
            onRefresh: _syncLikedVideos,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Text(
                      'No ${_selectedType == 0 ? 'Videos' : 'Shorts'} found',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final video = filteredVideos[index];
          return VideoCard(
            video: video,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PlayerScreen(video: video)),
              );
            },
            onDownload: () => _handleDownload(video),
            isDownloadLoading: _loadingVideoIds.contains(video.id),
            onMenuTap: () {},
          );
        }, childCount: filteredVideos.length),
      );
    } else if (videosAsync.isLoading) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const VideoCardSkeleton(),
          childCount: 5,
        ),
      );
    } else {
      // Error State
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const Gap(16),
                Text(
                  'Failed to load liked videos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Gap(8),
                if (videosAsync.error != null)
                  Text(
                    ErrorHandler.getUserFriendlyMessage(videosAsync.error),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                const Gap(16),
                ElevatedButton.icon(
                  onPressed: _syncLikedVideos,
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Future<void> _syncLikedVideos() async {
    try {
      await ref.read(syncServiceProvider.notifier).syncLikedVideos();
      ref.invalidate(likedVideosProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getUserFriendlyMessage(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleDownload(Video video) async {
    final url = video.url ?? 'https://www.youtube.com/watch?v=${video.id}';

    setState(() {
      _loadingVideoIds.add(video.id);
    });

    try {
      if (!mounted) return;
      final result = await BottomSheetHelper.show<Map<String, dynamic>>(
        context: context,
        builder: (context, scrollController) => DownloadConfigureModal(
          videoUrl: url,
          preFetchedMetadata: null,
          scrollController: scrollController,
        ),
      );

      if (result != null) {
        final downloadService = ref.read(downloadServiceProvider.notifier);
        downloadService.downloadVideo(
          url,
          formatId: result['formatId'],
          expectedSize: result['expectedSize'],
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download started...'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error preparing download: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingVideoIds.remove(video.id);
        });
      }
    }
  }
}
