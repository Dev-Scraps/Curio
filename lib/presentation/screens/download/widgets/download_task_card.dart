import 'package:curio/core/services/content/downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gap/gap.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../domain/entities/download_task.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../common/bottom_sheet_helper.dart';

class DownloadTaskCard extends ConsumerWidget {
  final DownloadTask task;
  final VoidCallback onPlay;
  final VoidCallback onExternalPlay;
  final VoidCallback onRetry;
  final VoidCallback onDelete;
  final VoidCallback onCancel;
  final VoidCallback? onPauseResume;

  const DownloadTaskCard({
    super.key,
    required this.task,
    required this.onPlay,
    required this.onExternalPlay,
    required this.onRetry,
    required this.onDelete,
    required this.onCancel,
    this.onPauseResume,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasks = ref.watch(downloadServiceProvider);
    final latestTask = allTasks.firstWhere(
      (t) => t.id == task.id,
      orElse: () => task,
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompleted = latestTask.status == DownloadStatus.completed;
    final isError = latestTask.status == DownloadStatus.error;
    final isCancelled = latestTask.status == DownloadStatus.cancelled;
    final isDownloading = latestTask.status == DownloadStatus.downloading;
    final isProcessing = latestTask.status == DownloadStatus.processing;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isCompleted ? onPlay : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail (Bigger)
                      Hero(
                        tag: 'thumb_${latestTask.id}',
                        child: Container(
                          width: 120,
                          height: 68,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.black,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: latestTask.thumbnailUrl.isNotEmpty
                                ? Image.network(
                                    latestTask.thumbnailUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _buildPlaceholder(),
                                  )
                                : _buildPlaceholder(),
                          ),
                        ),
                      ),
                      const Gap(16),

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              latestTask.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                            const Gap(6),
                            // Duration, Quality and status row
                            Row(
                              children: [
                                if (latestTask.duration != null) ...[
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedClock01,
                                    size: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const Gap(4),
                                  Text(
                                    latestTask.duration!,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const Gap(8),
                                ],
                                // Quality Tag
                                if (latestTask.formatId != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _getQualityText(latestTask.formatId!),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                    ),
                                  ),
                                  const Gap(8),
                                ],
                                if (isCompleted)
                                  Expanded(
                                    child: Text(
                                      _getCompletedSizeText(latestTask),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  )
                                else if (isError)
                                  Expanded(
                                    child: Text(
                                      'Failed: ${latestTask.error ?? "Unknown error"}',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: colorScheme.error),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )
                                else if (isCancelled)
                                  Expanded(
                                    child: Text(
                                      'Cancelled',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  )
                                else if (latestTask.status ==
                                    DownloadStatus.queued)
                                  Expanded(
                                    child: Text(
                                      'Queued...',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: theme.hintColor),
                                    ),
                                  )
                                else if (isProcessing)
                                  Expanded(
                                    child: Text(
                                      'Processing...',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Action buttons
                      _buildActionButtons(context, theme, latestTask),
                    ],
                  ),

                  // Metadata section for completed downloads
                  if (isCompleted &&
                      (latestTask.artist != null ||
                          latestTask.album != null)) ...[
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(
                          0.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedInformationCircle,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                              const Gap(4),
                              Text(
                                'Metadata',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (latestTask.artist != null) ...[
                            const Gap(4),
                            Row(
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedHome02,
                                  size: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const Gap(4),
                                Expanded(
                                  child: Text(
                                    latestTask.artist!,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (latestTask.album != null) ...[
                            const Gap(2),
                            Row(
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedHome02,
                                  size: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const Gap(4),
                                Expanded(
                                  child: Text(
                                    latestTask.album!,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (latestTask.genre != null) ...[
                            const Gap(2),
                            Row(
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedHome02,
                                  size: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const Gap(4),
                                Expanded(
                                  child: Text(
                                    latestTask.genre!,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  // Progress section for active downloads
                  if (!isCompleted && !isError && !isCancelled) ...[
                    const Gap(12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: latestTask.progress / 100,
                        minHeight: 6,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                      ),
                    ),
                    const Gap(8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _getActiveDownloadSizeText(latestTask),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (isDownloading)
                          Row(
                            children: [
                              Text(
                                '${latestTask.speed} • ',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                latestTask.eta,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            latestTask.status.name.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.bold,
                              color: theme.hintColor,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCompletedMenu(BuildContext context) {
    BottomSheetHelper.show(
      context: context,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: HugeIcon(
                icon: HugeIcons.strokeRoundedPlay,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 24,
              ),
              title: const Text('Play Internally'),
              onTap: () {
                Navigator.pop(context);
                onPlay();
              },
            ),
            ListTile(
              leading: HugeIcon(
                icon: HugeIcons.strokeRoundedLinkCircle,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 24,
              ),
              title: const Text('Play with External Player'),
              onTap: () {
                Navigator.pop(context);
                onExternalPlay();
              },
            ),
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedDelete01,
                color: Colors.red,
                size: 24,
              ),
              title: const Text('Delete Download'),
              textColor: Theme.of(context).colorScheme.error,
              iconColor: Theme.of(context).colorScheme.error,
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    ThemeData theme,
    DownloadTask latestTask,
  ) {
    final colorScheme = theme.colorScheme;

    switch (latestTask.status) {
      case DownloadStatus.downloading:
      case DownloadStatus.paused:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (onPauseResume != null)
              _ActionButton(
                icon: latestTask.status == DownloadStatus.paused
                    ? HugeIcons.strokeRoundedPlay
                    : HugeIcons.strokeRoundedPause,
                onPressed: onPauseResume!,
              ),
            const Gap(8),
            _ActionButton(
              icon: HugeIcons.strokeRoundedCancel01,
              onPressed: onCancel,
              color: colorScheme.error,
            ),
          ],
        );
      case DownloadStatus.error:
      case DownloadStatus.cancelled:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ActionButton(
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
              color: colorScheme.primary,
            ),
            const Gap(8),
            _ActionButton(
              icon: HugeIcons.strokeRoundedDelete01,
              onPressed: onDelete,
              color: colorScheme.error,
            ),
          ],
        );
      case DownloadStatus.completed:
        return _ActionButton(
          icon: HugeIcons.strokeRoundedMoreVertical,
          onPressed: () => _showCompletedMenu(context),
        );
      case DownloadStatus.queued:
      case DownloadStatus.processing:
        return _ActionButton(
          icon: HugeIcons.strokeRoundedCancel01,
          onPressed: onCancel,
          color: colorScheme.error,
        );
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedPlay,
          size: 24,
          color: Colors.white24,
        ),
      ),
    );
  }

  String _getCompletedSizeText(DownloadTask task) {
    final actualSize = task.totalBytes;
    final expectedSize = task.expectedSize;

    if (actualSize > 0) {
      if (expectedSize != null && expectedSize > 0) {
        final diff = (actualSize - expectedSize).abs();
        final diffPercent = (diff / expectedSize * 100).round();

        if (diffPercent > 10) {
          // If actual size differs by more than 10%, show both
          return '${formatFileSize(actualSize)} (was ${formatFileSize(expectedSize)}) • Downloaded';
        }
      }
      return '${formatFileSize(actualSize)} • Downloaded';
    }

    return '${formatFileSize(expectedSize ?? 0)} • Downloaded';
  }

  String _getActiveDownloadSizeText(DownloadTask task) {
    final downloaded = task.downloadedBytes;
    final total = task.totalBytes;
    final expected = task.expectedSize;

    String totalText;
    if (total > 0) {
      totalText = formatFileSize(total);
      if (expected != null && expected > 0) {
        final diff = (total - expected).abs();
        final diffPercent = (diff / expected * 100).round();

        if (diffPercent > 10) {
          // If total differs significantly from expected, show both
          totalText = '$totalText (est: ${formatFileSize(expected)})';
        }
      }
    } else if (expected != null && expected > 0) {
      totalText = '~${formatFileSize(expected)}'; // Use ~ to indicate estimate
    } else {
      totalText = 'Unknown size';
    }

    return '${formatFileSize(downloaded)} / $totalText';
  }

  String _getQualityText(String formatId) {
    if (formatId.contains('bestvideo') && formatId.contains('height<=1080'))
      return '1080p';
    if (formatId.contains('bestvideo') && formatId.contains('height<=720'))
      return '720p';
    if (formatId.contains('bestvideo') && formatId.contains('height<=480'))
      return '480p';
    if (formatId.contains('bestaudio')) return 'Audio Only';

    // Common YT-DLP format codes (approximate)
    if (formatId.contains('137')) return '1080p';
    if (formatId.contains('22')) return '720p';
    if (formatId.contains('18')) return '360p';
    if (formatId.contains('140')) return 'AAC Audio';
    if (formatId == 'best') return 'Best Quality';

    return formatId; // Fallback
  }
}

class _ActionButton extends StatelessWidget {
  final dynamic icon;
  final VoidCallback onPressed;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color?.withOpacity(0.1) ?? Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: HugeIcon(icon: icon, color: color ?? Colors.white, size: 18),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
