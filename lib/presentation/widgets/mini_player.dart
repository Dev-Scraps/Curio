import 'package:curio/presentation/screens/player/player_screen.dart';
import 'package:curio/presentation/screens/player/viewmodels/viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../common/bottom_sheet_helper.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerViewModelProvider);
    final viewModel = ref.read(playerViewModelProvider.notifier);

    // Only show if we have a video and metadata (or just title)
    if (state.metadata == null && !state.isLoadingMetadata)
      return const SizedBox.shrink();

    final metadata = state.metadata;
    final title = metadata?.title ?? 'Loading...';
    final artist = metadata?.uploader ?? 'YouTube';

    return Container(
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Progress Bar
            if (state.duration > Duration.zero)
              LinearProgressIndicator(
                value:
                    state.position.inMilliseconds /
                    state.duration.inMilliseconds,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
                minHeight: 2,
              ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(0),
                child: Row(
                  children: [
                    // GestureDetector only for the left side (Thumbnail + Title)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          // Open full player screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PlayerScreen(),
                            ),
                          );
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      artist,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontSize: 11,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Controls (Outside the GestureDetector)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Previous button (only show if playlist has more than 1 video)
                          if (state.playlistTotal != null &&
                              state.playlistTotal! > 1)
                            IconButton(
                              icon: HugeIcon(
                                icon: HugeIcons.strokeRoundedPrevious,
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 20,
                              ),
                              onPressed: state.playlistIndex > 0
                                  ? viewModel.playPreviousVideo
                                  : null,
                            ),
                          IconButton(
                            icon: HugeIcon(
                              icon: state.isPlaying
                                  ? HugeIcons.strokeRoundedPause
                                  : HugeIcons.strokeRoundedPlay,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 24,
                            ),
                            onPressed: viewModel.togglePlayPause,
                          ),
                          // Next button (only show if playlist has more than 1 video)
                          if (state.playlistTotal != null &&
                              state.playlistTotal! > 1)
                            IconButton(
                              icon: HugeIcon(
                                icon: HugeIcons.strokeRoundedNext,
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 20,
                              ),
                              onPressed:
                                  state.playlistIndex < state.playlistTotal! - 1
                                  ? viewModel.playNextVideo
                                  : null,
                            ),
                          IconButton(
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedCancel01,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            onPressed: () {
                              viewModel.stop();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().slideY(
      begin: 1.0,
      end: 0.0,
      duration: 300.ms,
      curve: Curves.easeOut,
    );
  }
}
