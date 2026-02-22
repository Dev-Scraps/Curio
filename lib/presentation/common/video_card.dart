import 'package:curio/presentation/common/progress_indicators.dart';
import 'package:curio/presentation/screens/ai/analysis_screen.dart';
import 'package:curio/presentation/screens/ai/notes_screen.dart';
import 'package:curio/presentation/screens/ai/questions_screen.dart';
import 'package:curio/presentation/screens/ai/quiz_screen.dart';
import 'package:curio/presentation/screens/ai/summary_screen.dart';
import 'package:curio/presentation/screens/player/player_screen.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../domain/entities/video.dart';
import '../../../core/utils/format_utils.dart';
import '../providers/video_progress_provider.dart';
import 'bottom_sheet_helper.dart';

class VideoCard extends ConsumerWidget {
  final Video video;
  final VoidCallback onTap;
  final VoidCallback? onDownload;
  final VoidCallback onMenuTap;
  final VoidCallback? onDelete;
  final bool isDownloadLoading;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelect;
  final bool aiEnabled;

  const VideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.onDownload,
    this.isDownloadLoading = false,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelect,
    this.aiEnabled = false,
    required this.onMenuTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(videoProgressStreamProvider(video.id));

    return GestureDetector(
      onTap: isSelectionMode ? () => onSelect?.call(!isSelected) : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
            width: isSelected ? 2 : 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              // Vertically centers the Thumbnail, Metadata Column, and Menu Button
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildThumbnail(context, progressAsync),
                const Gap(12),
                Expanded(child: _buildMetadata(context, progressAsync)),
                const Gap(8),
                if (!isSelectionMode) _buildMenuButton(context),
                if (isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: onSelect,
                    shape: const CircleBorder(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(
    BuildContext context,
    AsyncValue<dynamic> progressAsync,
  ) {
    return SizedBox(
      width: 140,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: video.thumbnailUrl.isNotEmpty
                  ? video.thumbnailUrl.startsWith('http')
                        ? Image.network(
                            video.thumbnailUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                              );
                            },
                            errorBuilder: (context, error, stack) =>
                                _buildPlaceholder(context),
                          )
                        : Image.file(
                            File(video.thumbnailUrl),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stack) =>
                                _buildPlaceholder(context),
                          )
                  : _buildPlaceholder(context),
            ),
            if (video.duration.isNotEmpty)
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    formatDuration(video.duration),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: progressAsync.when(
                data: (progress) {
                  if (progress != null && progress.completionPercentage > 0) {
                    return ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: LinearProgressIndicator(
                        value: progress.completionPercentage / 100,
                        minHeight: 3,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surface.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress.isCompleted
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadata(
    BuildContext context,
    AsyncValue<dynamic> progressAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // Keeps the column height strictly to its content so Row can center it
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          video.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        progressAsync.when(
          data: (progress) {
            final percentage = progress?.completionPercentage ?? 0;
            if (percentage <= 0) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '$percentage% complete',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    return IconButton(
      icon: Text(
        String.fromCharCode(Symbols.more_vert_rounded.codePoint),
        style: TextStyle(
          inherit: false,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 20,
          fontFamily: Symbols.more_vert_rounded.fontFamily,
          package: Symbols.more_vert_rounded.fontPackage,
          fontVariations: const [
            FontVariation('FILL', 0),
            FontVariation('wght', 400),
          ],
        ),
      ),
      onPressed: () => _onMenuTap(context),
    );
  }

  void _onMenuTap(BuildContext context) {
    BottomSheetHelper.show(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMenuItem(
              context,
              symbol: Symbols.motion_play_rounded,
              title: 'Play',
              subtitle: 'Start watching now',
              onTap: () {
                Navigator.pop(context);
                onTap();
              },
            ),
            _buildMenuItem(
              context,
              symbol: Symbols.music_note_rounded,
              title: 'Play as Audio',
              subtitle: 'Stream audio only',
              onTap: () {
                Navigator.pop(context);
                _playAsAudio(context);
              },
            ),

            // if (aiEnabled) ...[
            _buildMenuItem(
              context,
              symbol: Symbols.download_rounded,
              title: 'Download',
              subtitle: 'Save for offline',
              onTap: () {
                Navigator.pop(context);
                if (onDownload != null) onDownload!();
              },
              isLoading: isDownloadLoading,
            ),
            _buildMenuItem(
              context,
              symbol: Symbols.share_rounded,
              title: 'Share',
              subtitle: 'Send video link',
              onTap: () {
                Navigator.pop(context);
                _shareVideo(context);
              },
            ),
            if (video.isDownloaded)
              _buildMenuItem(
                context,
                symbol: Symbols.delete_rounded,
                title: 'Delete from device',
                subtitle: 'Remove the downloaded file',
                color: Theme.of(context).colorScheme.error,
                onTap: () {
                  Navigator.pop(context);
                  onDelete?.call();
                },
              ),
            _buildMenuItem(
              context,
              symbol: Symbols.favorite_rounded,
              title: 'Like',
              subtitle: 'Add to liked videos',
              onTap: () {
                Navigator.pop(context);
                _likeVideo(context);
              },
            ),
            _buildMenuItem(
              context,
              symbol: Symbols.bookmark_rounded,
              title: 'Watch Later',
              subtitle: 'Save to watch later',
              onTap: () {
                Navigator.pop(context);
                _addToWatchLater(context);
              },
            ),
            _buildMenuItem(
              context,
              symbol: Symbols.playlist_add_rounded,
              title: 'Add to Playlist',
              subtitle: 'Organize your library',
              onTap: () {
                Navigator.pop(context);
                _addToPlaylist(context);
              },
            ),
            _buildMenuItem(
              context,
              symbol: Symbols.info_rounded,
              title: 'Video Info',
              subtitle: 'Details and metadata',
              onTap: () {
                Navigator.pop(context);
                _showVideoInfo(context);
              },
            ),
            // _buildMenuItem(
            //   context,
            //   icon: HugeIcons.strokeRoundedBookOpen02,
            //   title: 'Create Notes',
            //   subtitle: 'Full detailed notes saved to storage',
            //   onTap: () {
            //     Navigator.pop(context);
            //     _navigateToNotes(context);
            //   },
            // ),
            _buildMenuItem(
              context,
              symbol: Symbols.edit_rounded,
              title: 'Summary',
              subtitle: 'Generate video summary',
              onTap: () {
                Navigator.pop(context);
                _navigateToSummary(context);
              },
            ),
            // _buildMenuItem(
            //   context,
            //   icon: HugeIcons.strokeRoundedHelpCircle,
            //   title: 'Questions',
            //   subtitle: 'Generate related questions with answers',
            //   onTap: () {
            //     Navigator.pop(context);
            //     _navigateToQuestions(context);
            //   },
            // ),
            // _buildMenuItem(
            //   context,
            //   icon: HugeIcons.strokeRoundedEdit02,
            //   title: 'Quiz',
            //   subtitle: 'Generate test with 30-60 questions',
            //   onTap: () {
            //     Navigator.pop(context);
            //     _navigateToQuiz(context);
            //   },
            // ),
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

  void _navigateToSummary(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SummaryScreen(video: video, autoGenerate: false),
      ),
    );
  }

  void _navigateToNotes(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotesScreen(video: video, autoGenerate: false),
      ),
    );
  }

  void _navigateToQuestions(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionsScreen(video: video, autoGenerate: false),
      ),
    );
  }

  void _navigateToQuiz(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuizScreen(video: video)),
    );
  }

  void _showVideoInfo(BuildContext context) {
    BottomSheetHelper.show(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Video Info',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            _buildInfoRow(context, 'Title', video.title),
            _buildInfoRow(context, 'Channel', video.channelName),
            _buildInfoRow(context, 'Duration', formatDuration(video.duration)),
            _buildInfoRow(context, 'Views', formatViewCount(video.viewCount)),
            if (video.uploadDate.isNotEmpty)
              _buildInfoRow(context, 'Uploaded', video.uploadDate),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          String.fromCharCode(Symbols.video_file_rounded.codePoint),
          style: TextStyle(
            inherit: false,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withOpacity(0.3),
            fontSize: 48,
            fontFamily: Symbols.video_file_rounded.fontFamily,
            package: Symbols.video_file_rounded.fontPackage,
            fontVariations: const [
              FontVariation('FILL', 0),
              FontVariation('wght', 400),
            ],
          ),
        ),
      ),
    );
  }

  void _shareVideo(BuildContext context) {
    String shareContent;

    if (video.url?.isNotEmpty == true) {
      // For online videos, share title and URL
      shareContent = '${video.title}\n\n${video.url}';
    } else if (video.isDownloaded && video.filePath != null) {
      // For downloaded videos without URL, try to extract YouTube video ID from file path
      final fileName = video.filePath!.split('/').last;

      // Look for YouTube video ID pattern (11 characters)
      final videoIdMatch = RegExp(r'[a-zA-Z0-9_-]{11}').firstMatch(fileName);
      if (videoIdMatch != null) {
        final videoId = videoIdMatch.group(0)!;
        shareContent =
            '${video.title}\n\nhttps://www.youtube.com/watch?v=$videoId';
      } else {
        shareContent = '${video.title}\n\n(Downloaded video)';
      }
    } else {
      // Fallback for other cases
      shareContent = video.title;
    }

    Share.share(shareContent, subject: video.title);
  }

  void _likeVideo(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Liked: ${video.title}')));
  }

  void _playAsAudio(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(video: video, audioOnly: true),
      ),
    );
  }

  void _addToWatchLater(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added to Watch Later: ${video.title}')),
    );
  }

  void _addToPlaylist(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added to Playlist: ${video.title}')),
    );
  }
}
