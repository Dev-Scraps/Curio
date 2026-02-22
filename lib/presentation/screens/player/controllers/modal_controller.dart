import 'dart:ui';
import 'package:curio/presentation/screens/player/widgets/settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import '../../../../domain/entities/video.dart';
import '../../../common/bottom_sheet_helper.dart';
import '../widgets/description.dart';
import '../viewmodels/viewmodel.dart';

class PlayerModalController {
  static Future<T?> _showPlayerModal<T>({
    required BuildContext context,
    required Widget Function(BuildContext, ScrollController) builder,
    String? title,
  }) {
    return BottomSheetHelper.show<T>(
      context: context,
      title: title,
      builder: builder,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
    );
  }

  static void showDescriptionDialog(BuildContext context, PlayerState state) {
    BottomSheetHelper.show(
      context: context,
      builder: (context, scrollController) =>
          VideoDescriptionSheet(scrollController: scrollController),
    );
  }

  static void showPlaylistDialog(
    BuildContext context,
    PlayerState state,
    PlayerViewModel viewModel,
  ) {
    BottomSheetHelper.show(
      context: context,
      title: 'Up Next',
      builder: (context, scrollController) {
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.playlistVideos.length,
                itemBuilder: (context, index) {
                  final video = state.playlistVideos[index];
                  final isCurrent = index == state.playlistIndex;
                  final isNext = index == state.playlistIndex + 1;

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Theme.of(
                              context,
                            ).colorScheme.primaryContainer.withOpacity(0.3)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.outlineVariant.withOpacity(0.5),
                        width: isCurrent ? 2 : 0.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            viewModel.playVideoAtIndex(index);
                            Navigator.pop(context);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                // Thumbnail
                                SizedBox(
                                  width: 100,
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Image.network(
                                            video.thumbnailUrl,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                            errorBuilder: (c, o, s) =>
                                                Container(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.music_note,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant
                                                          .withOpacity(0.3),
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                          ),
                                        ),
                                        if (video.duration.isNotEmpty)
                                          Positioned(
                                            bottom: 4,
                                            right: 4,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black87,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                video.duration,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        video.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                          fontSize: 13,
                                          fontWeight: isCurrent
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          if (isCurrent)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'Now Playing',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          if (isNext && !isCurrent) ...[
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.surfaceVariant,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Next',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (isCurrent)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Icon(
                                      Icons.equalizer,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      size: 16,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
    );
  }

  static void showSettingsMenu(BuildContext context) {
    BottomSheetHelper.show(
      context: context,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: const CompactSettingsSheet(),
      ),
    );
  }
}
