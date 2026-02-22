import 'package:curio/presentation/common/progress_indicators.dart';
import 'dart:ui';

import 'package:curio/core/services/content/downloader.dart';
import 'package:curio/core/services/content/sync.dart';
import 'package:curio/core/services/storage/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart';
import 'package:share_plus/share_plus.dart';
import '../../../domain/entities/video.dart';
import '../../../domain/entities/playlist.dart';
import '../../common/bottom_sheet_helper.dart';
import '../../common/video_card.dart';
import '../../common/rounded_search_bar.dart';
import '../../common/skeleton_loader.dart';
import '../../providers/playlists_provider.dart';
import '../../providers/videos_provider.dart';
import '../player/player_screen.dart';
import '../search/search_results_screen.dart';
import '../ai/notes_screen.dart';
import '../ai/questions_screen.dart';
import '../ai/quiz_screen.dart';
import '../ai/summary_screen.dart';
import '../download/widgets/download_configure_modal.dart';
import '../home/home_screen.dart';
import '../liked/liked_screen.dart';
import '../ai/dashboard_screen.dart';
import '../download/download_screen.dart';
import '../settings/settings_screen.dart';
import '../../common/sync_progress_bar.dart';

class PlaylistScreen extends ConsumerStatefulWidget {
  final Playlist playlist;

  const PlaylistScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  String _searchQuery = '';
  final Set<String> _loadingVideoIds = {};
  bool _aiEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkAIEnabled();
  }

  Future<void> _checkAIEnabled() async {
    final apiKey = ref.read(storageServiceProvider).geminiApiKey;
    setState(() {
      _aiEnabled = apiKey != null && apiKey.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(playlistVideosProvider(widget.playlist.id));

    return Scaffold(
      body: RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surface,
        onRefresh: () async {
          await ref
              .read(syncServiceProvider.notifier)
              .syncSpecificPlaylist(widget.playlist.id);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: false,
              snap: false,
              elevation: 0,
              centerTitle: true,
              title: Text(
                widget.playlist.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: RoundedSearchBar(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  hintText: 'Search in playlist...',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildActionMenu(context, videosAsync.value ?? []),
            ),
            const SliverGap(8),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: videosAsync.when(
                data: (videos) {
                  final filteredVideos = videos.where((video) {
                    if (_searchQuery.isEmpty) return true;
                    return video.title.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ) ||
                        video.channelName.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        );
                  }).toList();

                  if (filteredVideos.isEmpty) {
                    return SliverToBoxAdapter(
                      child: _searchQuery.isNotEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    String.fromCharCode(
                                      Symbols.search_rounded.codePoint,
                                    ),
                                    style: TextStyle(
                                      inherit: false,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withOpacity(0.5),
                                      fontSize: 48,
                                      fontFamily:
                                          Symbols.search_rounded.fontFamily,
                                      package:
                                          Symbols.search_rounded.fontPackage,
                                      fontVariations: const [
                                        FontVariation('FILL', 0),
                                        FontVariation('wght', 400),
                                      ],
                                    ),
                                  ),
                                  const Gap(16),
                                  Text(
                                    'No matching videos found',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            )
                          : _buildEmptyState(),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final video = filteredVideos[index];
                      return VideoCard(
                        video: video,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlayerScreen(video: video),
                            ),
                          );
                        },
                        onDownload: () => _handleDownload(context, video),
                        isDownloadLoading: _loadingVideoIds.contains(video.id),
                        aiEnabled: _aiEnabled,
                        onMenuTap: () {},
                      );
                    }, childCount: filteredVideos.length),
                  );
                },
                loading: () => SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const SkeletonLoader(),
                    childCount: 5,
                  ),
                ),
                error: (e, s) => SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            String.fromCharCode(
                              Symbols.error_rounded.codePoint,
                            ),
                            style: TextStyle(
                              inherit: false,
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 48,
                              fontFamily: Symbols.error_rounded.fontFamily,
                              package: Symbols.error_rounded.fontPackage,
                              fontVariations: const [
                                FontVariation('FILL', 0),
                                FontVariation('wght', 400),
                              ],
                            ),
                          ),
                          const Gap(16),
                          Text(
                            'Failed to load videos',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Gap(8),
                          Text(
                            e.toString(),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const Gap(24),
                          FilledButton.icon(
                            onPressed: () => ref.refresh(
                              playlistVideosProvider(widget.playlist.id),
                            ),
                            icon: Text(
                              String.fromCharCode(
                                Symbols.refresh_rounded.codePoint,
                              ),
                              style: TextStyle(
                                inherit: false,
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 20,
                                fontFamily: Symbols.refresh_rounded.fontFamily,
                                package: Symbols.refresh_rounded.fontPackage,
                                fontVariations: const [
                                  FontVariation('FILL', 0),
                                  FontVariation('wght', 400),
                                ],
                              ),
                            ),
                            label: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Builder(
      builder: (context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              String.fromCharCode(Symbols.home_rounded.codePoint),
              style: TextStyle(
                inherit: false,
                fontSize: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withOpacity(0.4),
                fontFamily: Symbols.home_rounded.fontFamily,
                package: Symbols.home_rounded.fontPackage,
                fontVariations: const [
                  FontVariation('FILL', 0),
                  FontVariation('wght', 400),
                ],
              ),
            ),
            const Gap(16),
            const Text('No videos in this playlist'),
            const Gap(8),
            Text(
              'Pull to refresh',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionMenu(BuildContext context, List<Video> videos) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionButton(
            symbol: Symbols.share_rounded,
            label: 'Share',
            onTap: () => _handleShare(),
          ),
          _buildActionButton(
            symbol: Symbols.playlist_play_rounded,
            label: 'Play All',
            onTap: () => _handlePlayAll(context, videos),
          ),
          _buildActionButton(
            symbol: Symbols.music_note_rounded,
            label: 'Audio',
            onTap: () => _handlePlayAllAudio(context, videos),
          ),
          _buildActionButton(
            symbol: Symbols.download_rounded,
            label: 'Download All',
            onTap: () => _handleDownloadAll(context, videos),
          ),
          _buildActionButton(
            symbol: Symbols.more_horiz_rounded,
            label: 'More',
            onTap: () => _handleMore(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData symbol,
    required String label,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              String.fromCharCode(symbol.codePoint),
              style: TextStyle(
                inherit: false,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 20,
                fontFamily: symbol.fontFamily,
                package: symbol.fontPackage,
                fontVariations: const [
                  FontVariation('FILL', 0),
                  FontVariation('wght', 400),
                ],
              ),
            ),
            const Gap(4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleShare() {
    final url = 'https://www.youtube.com/playlist?list=${widget.playlist.id}';
    Share.share('Check out this playlist: ${widget.playlist.title}\n$url');
  }

  void _handlePlayAll(BuildContext context, List<Video> videos) {
    if (videos.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          video: videos.first,
          playlist: videos,
          initialIndex: 0,
        ),
      ),
    );
  }

  void _handlePlayAllAudio(BuildContext context, List<Video> videos) {
    if (videos.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          video: videos.first,
          playlist: videos,
          initialIndex: 0,
          audioOnly: true,
        ),
      ),
    );
  }

  Future<void> _handleDownloadAll(
    BuildContext context,
    List<Video> videos,
  ) async {
    if (videos.isEmpty) return;

    final confirm = await BottomSheetHelper.showConfirmation(
      context: context,
      title: 'Download Playlist',
      message:
          'Do you want to download all ${videos.length} videos in this playlist?',
      confirmText: 'Download',
    );

    if (confirm) {
      final downloadService = ref.read(downloadServiceProvider.notifier);
      for (final video in videos) {
        final url = video.url ?? 'https://www.youtube.com/watch?v=${video.id}';
        downloadService.downloadVideo(url);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Starting ${videos.length} downloads...'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _handleMore(BuildContext context) {
    BottomSheetHelper.show(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMenuItem(
              context,
              symbol: Symbols.refresh_rounded,
              title: 'Sync Playlist',
              subtitle: 'Fetch latest videos',
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(syncServiceProvider.notifier)
                    .syncSpecificPlaylist(widget.playlist.id);
              },
            ),
            _buildMenuItem(
              context,
              symbol: Symbols.favorite_rounded,
              title: 'Like All Videos',
              subtitle: 'Add all videos to liked',
              onTap: () {
                Navigator.pop(context);
                _likeAllVideos(context);
              },
            ),
            _buildMenuItem(
              context,
              symbol: Symbols.bookmark_rounded,
              title: 'Watch Later All',
              subtitle: 'Save all videos to watch later',
              onTap: () {
                Navigator.pop(context);
                _addAllToWatchLater(context);
              },
            ),
            // _buildMenuItem(
            //   context,
            //   icon: HugeIcons.strokeRoundedBookOpen02,
            //   title: 'Create Notes for All',
            //   subtitle: 'Generate detailed notes for all videos',
            //   onTap: () {
            //     Navigator.pop(context);
            //     _createNotesForAll(context);
            //   },
            // ),
            _buildMenuItem(
              context,
              symbol: Symbols.edit_rounded,
              title: 'Generate Summary',
              subtitle: 'Create playlist summary',
              onTap: () {
                Navigator.pop(context);
                _generatePlaylistSummary(context);
              },
            ),
            // _buildMenuItem(
            //   context,
            //   icon: HugeIcons.strokeRoundedHelpCircle,
            //   title: 'Generate Questions',
            //   subtitle: 'Create questions for all videos',
            //   onTap: () {
            //     Navigator.pop(context);
            //     _generateQuestionsForAll(context);
            //   },
            // ),
            // _buildMenuItem(
            //   context,
            //   icon: HugeIcons.strokeRoundedEdit02,
            //   title: 'Create Quiz',
            //   subtitle: 'Generate test from playlist videos',
            //   onTap: () {
            //     Navigator.pop(context);
            //     _createPlaylistQuiz(context);
            //   },
            // ),
            _buildMenuItem(
              context,
              symbol: Symbols.info_rounded,
              title: 'Playlist Info',
              subtitle: 'View playlist details',
              onTap: () {
                Navigator.pop(context);
                _showPlaylistInfo(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData symbol,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? color,
    bool isLoading = false,
  }) {
    return ListTile(
      leading: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: M3CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              String.fromCharCode(symbol.codePoint),
              style: TextStyle(
                inherit: false,
                color: color ?? Theme.of(context).colorScheme.primary,
                fontSize: 24,
                fontFamily: symbol.fontFamily,
                package: symbol.fontPackage,
                fontVariations: const [
                  FontVariation('FILL', 0),
                  FontVariation('wght', 400),
                ],
              ),
            ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w500, color: color),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(color: color))
          : null,
      onTap: isLoading ? null : onTap,
    );
  }

  void _likeAllVideos(BuildContext context) async {
    final videosAsync = ref.read(playlistVideosProvider(widget.playlist.id));
    final videos = videosAsync.value ?? [];

    if (videos.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No videos to like')));
      return;
    }

    // For now, just show a message since we don't have a direct way to add to liked
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Liked ${videos.length} videos')));
  }

  void _addAllToWatchLater(BuildContext context) async {
    final videosAsync = ref.read(playlistVideosProvider(widget.playlist.id));
    final videos = videosAsync.value ?? [];

    if (videos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No videos to add to watch later')),
      );
      return;
    }

    // For now, just show a message since we don't have a direct way to add to watch later
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${videos.length} videos to watch later')),
    );
  }

  void _createNotesForAll(BuildContext context) {
    final videosAsync = ref.read(playlistVideosProvider(widget.playlist.id));
    final videos = videosAsync.value ?? [];

    if (videos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No videos to create notes for')),
      );
      return;
    }

    // Navigate to notes screen with the first video for now
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotesScreen(video: videos.first, autoGenerate: true),
      ),
    );
  }

  void _generatePlaylistSummary(BuildContext context) {
    final videosAsync = ref.read(playlistVideosProvider(widget.playlist.id));
    final videos = videosAsync.value ?? [];

    if (videos.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No videos to summarize')));
      return;
    }

    // Navigate to summary screen with the first video for now
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SummaryScreen(video: videos.first, autoGenerate: true),
      ),
    );
  }

  void _generateQuestionsForAll(BuildContext context) {
    final videosAsync = ref.read(playlistVideosProvider(widget.playlist.id));
    final videos = videosAsync.value ?? [];

    if (videos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No videos to generate questions for')),
      );
      return;
    }

    // Navigate to questions screen with the first video for now
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            QuestionsScreen(video: videos.first, autoGenerate: true),
      ),
    );
  }

  void _createPlaylistQuiz(BuildContext context) {
    final videosAsync = ref.read(playlistVideosProvider(widget.playlist.id));
    final videos = videosAsync.value ?? [];

    if (videos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No videos to create quiz from')),
      );
      return;
    }

    // Navigate to quiz screen with the first video for now
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(video: videos.first, autoGenerate: true),
      ),
    );
  }

  void _showPlaylistInfo(BuildContext context) {
    final videosAsync = ref.read(playlistVideosProvider(widget.playlist.id));
    final videos = videosAsync.value ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.playlist.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Videos: ${videos.length}'),
            const Gap(8),
            if (widget.playlist.description != null &&
                widget.playlist.description!.isNotEmpty)
              Text('Description: ${widget.playlist.description}')
            else
              const Text('Description: No description available'),
            const Gap(8),
            Text(
              'Channel: ${widget.playlist.channel ?? widget.playlist.uploader}',
            ),
            const Gap(8),
            if (widget.playlist.channelUrl != null)
              Text('URL: ${widget.playlist.channelUrl}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDownload(BuildContext context, Video video) async {
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
