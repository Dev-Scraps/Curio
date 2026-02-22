import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

/// Enhanced empty state widget with icon, title, message, and optional action
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon - minimal monochrome
            Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
                .animate()
                .fadeIn(duration: 800.ms, curve: Curves.easeOutBack)
                .scale(
                  begin: const Offset(0.5, 0.5),
                  curve: Curves.easeOutBack,
                ),

            const Gap(32),

            // Title
            Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                )
                .animate()
                .fadeIn(duration: 400.ms, delay: 100.ms)
                .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),

            const Gap(8),

            // Message
            Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                )
                .animate()
                .fadeIn(duration: 400.ms, delay: 200.ms)
                .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),

            // Action button (if provided)
            if (actionLabel != null && onAction != null) ...[
              const Gap(24),
              FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: Text(actionLabel!),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 300.ms)
                  .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
            ],
          ],
        ),
      ),
    );
  }
}

/// Specialized empty state for "No Liked Videos"
class NoLikedVideosEmptyState extends StatelessWidget {
  final VoidCallback? onSync;

  const NoLikedVideosEmptyState({super.key, this.onSync});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.thumb_up_rounded,
      title: 'No Liked Videos',
      message:
          'Videos you like will appear here.\nTap sync to refresh and load your favorites.',
      actionLabel: 'Sync Now',
      onAction: onSync,
    );
  }
}

/// Specialized empty state for "No Watch Later Videos"
class NoWatchLaterEmptyState extends StatelessWidget {
  final VoidCallback? onSync;

  const NoWatchLaterEmptyState({super.key, this.onSync});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.watch_later_rounded,
      title: 'Watch Later is Empty',
      message:
          'Save videos to watch later and they\'ll show up here.\nTap sync to refresh your list.',
      actionLabel: 'Sync Now',
      onAction: onSync,
    );
  }
}

/// Specialized empty state for "No Playlists"
class NoPlaylistsEmptyState extends StatelessWidget {
  final VoidCallback? onSync;

  const NoPlaylistsEmptyState({super.key, this.onSync});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.playlist_play_rounded,
      title: 'No Playlists Found',
      message:
          'Your YouTube playlists will appear here.\nTap sync to load your personal collections.',
      actionLabel: 'Sync Now',
      onAction: onSync,
    );
  }
}
