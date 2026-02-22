import 'package:curio/presentation/common/progress_indicators.dart';
import 'dart:ui';

import 'package:curio/core/services/content/downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:open_filex/open_filex.dart';
import '../../../domain/entities/download_task.dart';
import '../../../domain/entities/video.dart';
import '../player/player_screen.dart';

import '../../common/video_card.dart';
import '../../common/rounded_search_bar.dart';
import '../../providers/videos_provider.dart';
import 'widgets/download_task_card.dart';
import 'widgets/download_configure_modal.dart';
import '../../common/bottom_sheet_helper.dart';

class DownloadScreen extends ConsumerStatefulWidget {
  const DownloadScreen({super.key});

  @override
  ConsumerState<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends ConsumerState<DownloadScreen> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  int _selectedTabIndex = 0; // 0: Active, 1: Downloaded

  // Selection mode state
  bool _isSelectionMode = false;
  final Set<String> _selectedVideoIds = {};

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  Future<void> _updateMetadataForExistingVideos() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Extracting metadata from downloaded videos...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Run metadata extraction
      await ref
          .read(downloadServiceProvider.notifier)
          .updateExistingDownloadedVideosMetadata();

      // Show completion message
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Metadata extraction completed!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error extracting metadata: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final isDownloaded = await ref
        .read(downloadServiceProvider.notifier)
        .isVideoDownloaded(url);
    if (isDownloaded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video is already downloaded!')),
        );
      }
      return;
    }

    final result = await BottomSheetHelper.show<Map<String, dynamic>>(
      context: context,
      builder: (context, scrollController) => DownloadConfigureModal(
        videoUrl: url,
        preFetchedMetadata: null,
        scrollController: scrollController,
      ),
    );

    if (result != null && mounted) {
      final formatId = result['formatId'] as String?;
      final formatIds = result['formatIds'] as List<String>?;
      final expectedSize = result['expectedSize'] as int?;

      await ref
          .read(downloadServiceProvider.notifier)
          .downloadVideoEnhanced(
            url,
            formatIds: formatIds ?? [formatId ?? 'best'],
          );

      _urlController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Download queued')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadTasks = ref.watch(downloadServiceProvider);
    final historyAsync = ref.watch(downloadedVideosProvider);

    final activeTasks = downloadTasks
        .where(
          (t) =>
              t.status == DownloadStatus.downloading ||
              t.status == DownloadStatus.queued ||
              t.status == DownloadStatus.paused ||
              t.status == DownloadStatus.processing ||
              t.status == DownloadStatus.error ||
              t.status == DownloadStatus.cancelled,
        )
        .toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            elevation: 0,
            centerTitle: true,
            title: Text(
              'Downloads',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            actions: [
              if (_selectedTabIndex == 1)
                IconButton(
                  onPressed: _updateMetadataForExistingVideos,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Extract missing thumbnails & durations',
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: RoundedSearchBar(
                          controller: _urlController,
                          onChanged: (value) {
                            setState(() {
                              _urlController.text = value;
                            });
                          },
                          hintText: 'Paste link here...',
                        ),
                      ),
                      const Gap(8),
                      IconButton(
                        onPressed: _handleDownload,
                        icon: Icon(
                          Icons.download_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 22,
                        ),
                        tooltip: 'Download',
                      ),
                    ],
                  ),
                  const Gap(16),
                  _buildSegmentControl(),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            child: _selectedTabIndex == 0
                ? _buildActiveList(activeTasks)
                : _buildHistoryList(historyAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentControl() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor),
      ),
      child: Row(
        children: [
          _buildSegmentOption(0, 'Active'),
          _buildSegmentOption(1, 'Downloaded'),
        ],
      ),
    );
  }

  Widget _buildSegmentOption(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
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

  Widget _buildActiveList(List<DownloadTask> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedDownload01,
              size: 48,
              color: Theme.of(context).hintColor,
            ),
            const Gap(16),
            const Text('No active downloads'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return DownloadTaskCard(
          task: task,
          onPlay: () {}, // Not playable yet
          onExternalPlay: () {
            if (task.filePath != null) {
              OpenFilex.open(task.filePath!);
            }
          },
          onRetry: () =>
              ref.read(downloadServiceProvider.notifier).retryDownload(task.id),
          onDelete: () => ref
              .read(downloadServiceProvider.notifier)
              .deleteDownloadTask(task.id),
          onCancel: () => ref
              .read(downloadServiceProvider.notifier)
              .cancelDownload(task.id),
          onPauseResume: () {
            final notifier = ref.read(downloadServiceProvider.notifier);
            if (task.status == DownloadStatus.paused) {
              notifier.resumeDownload(task.id);
            } else if (task.status == DownloadStatus.downloading) {
              notifier.pauseDownload(task.id);
            }
          },
        );
      },
    );
  }

  Widget _buildHistoryList(AsyncValue<List<Video>> historyAsync) {
    return historyAsync.when(
      data: (history) {
        Future<void> onRefresh() async {
          // Show loading feedback
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Syncing with download directory...'),
                duration: Duration(seconds: 1),
              ),
            );
          }

          try {
            // Sync local files to detect deletions and additions
            await ref.read(downloadServiceProvider.notifier).syncLocalFiles();

            // Invalidate providers to refresh the UI
            ref.invalidate(downloadedVideosProvider);
            ref.invalidate(downloadServiceProvider);

            // Show success feedback
            if (mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Directory synced successfully'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            // Show error feedback
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error syncing directory: $e'),
                  backgroundColor: Colors.redAccent,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        }

        if (history.isEmpty) {
          return RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surface,
            onRefresh: onRefresh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    height: constraints.maxHeight, // Fill remaining space
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedTick01,
                          size: 48,
                          color: Theme.of(context).hintColor,
                        ),
                        const Gap(16),
                        const Text('No downloaded videos'),
                        const Gap(8),
                        Text(
                          'Pull to sync storage',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Theme.of(context).hintColor),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }

        return RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(context).colorScheme.surface,
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final video = history[index];
              final isSelected = _selectedVideoIds.contains(video.id);
              return VideoCard(
                video: video,
                isSelectionMode: _isSelectionMode,
                isSelected: isSelected,
                onSelect: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedVideoIds.add(video.id);
                    } else {
                      _selectedVideoIds.remove(video.id);
                    }
                    if (_selectedVideoIds.isEmpty) {
                      _isSelectionMode = false;
                    }
                  });
                },
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlayerScreen(video: video),
                    ),
                  );
                },
                onMenuTap: () {},
                onDelete: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Video'),
                      content: const Text(
                        'Delete this video from your history and device storage?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && mounted) {
                    await ref
                        .read(downloadServiceProvider.notifier)
                        .deleteDownloadTask(video.id);
                    ref.invalidate(downloadedVideosProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Deleted successfully')),
                    );
                  }
                },
              );
            },
          ),
        );
      },
      loading: () => const Center(child: M3CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}
