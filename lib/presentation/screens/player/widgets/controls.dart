import 'package:curio/presentation/common/progress_indicators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/services/storage/storage.dart';
import '../viewmodels/viewmodel.dart';
import '../utils/theme.dart';

class PlayerControls extends ConsumerWidget {
  final PlayerState state;
  final PlayerViewModel viewModel;
  final VoidCallback onQualitySelector;
  final VoidCallback onSettingsMenu;
  final VoidCallback onAudioOnlyMode;
  final VoidCallback onDownload;
  final VoidCallback onDescription;
  final VoidCallback onPlaylist;
  final VoidCallback onFullscreen;
  final bool isFullscreen;
  final bool isAudioMode;

  const PlayerControls({
    super.key,
    required this.state,
    required this.viewModel,
    required this.onQualitySelector,
    required this.onSettingsMenu,
    required this.onAudioOnlyMode,
    required this.onDownload,
    required this.onDescription,
    required this.onPlaylist,
    required this.onFullscreen,
    required this.isFullscreen,
    required this.isAudioMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenSize = MediaQuery.sizeOf(context);
    final player = viewModel.player;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: viewModel.toggleControls,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent,
          ),
        ),
        if (state.isControlsVisible) ...[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PlayerTopBar(
              state: state,
              viewModel: viewModel,
              onQualitySelector: onQualitySelector,
              onSettingsMenu: onSettingsMenu,
            ),
          ),
          Positioned(
            top: screenSize.height * 0.44,
            left: 0,
            right: 0,
            child: PlayerCenterControls(state: state, viewModel: viewModel),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: PlayerBottomControls(
              state: state,
              viewModel: viewModel,
              isFullscreen: isFullscreen,
              isAudioMode: isAudioMode,
              onAudioOnlyMode: onAudioOnlyMode,
              onDownload: onDownload,
              onDescription: onDescription,
              onPlaylist: onPlaylist,
              onFullscreen: onFullscreen,
            ),
          ),
        ],
      ],
    );
  }
}

class PlayerTopBar extends ConsumerWidget {
  final PlayerState state;
  final PlayerViewModel viewModel;
  final VoidCallback onQualitySelector;
  final VoidCallback onSettingsMenu;

  const PlayerTopBar({
    super.key,
    required this.state,
    required this.viewModel,
    required this.onQualitySelector,
    required this.onSettingsMenu,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _buildTopBar(context, state, viewModel);
  }

  Widget _buildTopBar(
    BuildContext context,
    PlayerState state,
    PlayerViewModel viewModel,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;
    final backButtonSize = isCompact ? 20.0 : 24.0;
    final settingsButtonSize = isCompact ? 18.0 : 20.0;
    final titleFontSize = isCompact ? 12.0 : 14.0;
    final subtitleFontSize = isCompact ? 9.0 : 11.0;
    final horizontalPadding = isCompact ? 12.0 : 16.0;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        decoration: PlayerTheme.getGradientDecoration(context),
        child: Padding(
          padding: EdgeInsets.only(
            left: horizontalPadding,
            right: horizontalPadding,
            top: statusBarHeight + 12,
            bottom: 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: PlayerTheme.getControlDecoration(
                    context: context,
                    opacity: 0.5,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowLeft01,
                    color: PlayerTheme.getIconColor(context),
                    size: backButtonSize,
                  ),
                ),
              ),
              // Title (center)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        state.metadata?.title ?? 'Video',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: PlayerTheme.getTitleTextStyle(
                          context: context,
                          fontSize: titleFontSize,
                        ),
                      ),
                      if ((state.metadata?.uploader ?? '').isNotEmpty)
                        Text(
                          state.metadata?.uploader ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: PlayerTheme.getSubtitleTextStyle(
                            context: context,
                            fontSize: subtitleFontSize,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Gap(8),
              // Settings button
              GestureDetector(
                onTap: onSettingsMenu,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: PlayerTheme.getControlDecoration(
                    context: context,
                    opacity: 0.5,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedSettings02,
                    color: PlayerTheme.getIconColor(context),
                    size: settingsButtonSize,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlayerCenterControls extends ConsumerWidget {
  final PlayerState state;
  final PlayerViewModel viewModel;

  const PlayerCenterControls({
    super.key,
    required this.state,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 400;
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;

    if (!isCompact || !isPortrait) return const SizedBox.shrink();

    final smallButtonSize = 40.0;
    final buttonGap = 30.0;
    final player = viewModel.player;

    bool isLoading() =>
        player == null || player.state.buffering || !state.isFirstFrameReady;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSeekButton(HugeIcons.strokeRoundedGoBackward10Sec, () {
            final newPos = state.position - const Duration(seconds: 10);
            viewModel.seekTo(newPos.isNegative ? Duration.zero : newPos);
          }, smallButtonSize),
          Gap(buttonGap),
          isLoading()
              ? _buildLoadingIndicator(smallButtonSize)
              : _buildPlayPauseButton(smallButtonSize),
          Gap(buttonGap),
          _buildSeekButton(HugeIcons.strokeRoundedGoForward10Sec, () {
            final newPos = state.position + const Duration(seconds: 10);
            viewModel.seekTo(newPos);
          }, smallButtonSize),
        ],
      ),
    );
  }

  Widget _buildSeekButton(dynamic icon, VoidCallback onTap, double size) {
    return Builder(
      builder: (context) {
        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: PlayerTheme.getControlDecoration(
              context: context,
              opacity: 0.5,
            ),
            child: HugeIcon(
              icon: icon,
              color: PlayerTheme.getIconColor(context),
              size: size,
            ),
          ),
        ).animate().scale(
          duration: 200.ms,
          begin: const Offset(1, 1),
          end: const Offset(0.95, 0.95),
        );
      },
    );
  }

  Widget _buildLoadingIndicator(double size) {
    return Builder(
      builder: (context) {
        return SizedBox(
              width: size,
              height: size,
              child: M3CircularProgressIndicator(
                strokeWidth: 2.0,
                color: PlayerTheme.getIconColor(context),
              ),
            )
            .animate(onPlay: (controller) => controller.repeat())
            .rotate(duration: 700.ms, begin: 0, end: 1, curve: Curves.linear);
      },
    );
  }

  Widget _buildPlayPauseButton(double size) {
    return Builder(
      builder: (context) {
        return GestureDetector(
          onTap: viewModel.togglePlayPause,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: PlayerTheme.getControlDecoration(
              context: context,
              opacity: 0.5,
            ),
            child: HugeIcon(
              icon: state.isPlaying
                  ? HugeIcons.strokeRoundedPause
                  : HugeIcons.strokeRoundedPlay,
              color: PlayerTheme.getIconColor(context),
              size: size,
            ),
          ),
        ).animate().scale(
          duration: 200.ms,
          begin: const Offset(1, 1),
          end: const Offset(0.95, 0.95),
        );
      },
    );
  }
}

class PlayerBottomControls extends ConsumerWidget {
  final PlayerState state;
  final PlayerViewModel viewModel;
  final bool isFullscreen;
  final bool isAudioMode;
  final VoidCallback onAudioOnlyMode;
  final VoidCallback onDownload;
  final VoidCallback onDescription;
  final VoidCallback onPlaylist;
  final VoidCallback onFullscreen;

  const PlayerBottomControls({
    super.key,
    required this.state,
    required this.viewModel,
    required this.isFullscreen,
    required this.isAudioMode,
    required this.onAudioOnlyMode,
    required this.onDownload,
    required this.onDescription,
    required this.onPlaylist,
    required this.onFullscreen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 400;
    final timeFontSize = isCompact ? 10.0 : 12.0;
    final buttonGap = isCompact ? 2.0 : 3.0;
    final buttonIconSize = isCompact ? 22.0 : 24.0;
    final player = viewModel.player;
    final storage = ref.watch(storageServiceProvider);

    bool isLoading() =>
        player == null || player.state.buffering || !state.isFirstFrameReady;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Padding(
        padding: EdgeInsets.only(
          left: isCompact ? 12 : 16,
          right: isCompact ? 12 : 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAudioMode) _buildAudioModeIndicator(context),
            if (isAudioMode) const Gap(12),
            _buildProgressBar(context, timeFontSize),
            const Gap(12),
            _buildActionButtons(
              isLoading,
              buttonGap,
              buttonIconSize,
              storage.pipEnabled,
            ),
            if (isCompact &&
                MediaQuery.orientationOf(context) == Orientation.portrait &&
                state.playlistTotal != null &&
                state.playlistTotal! > 1) ...[
              const Gap(12),
              _buildPlaylistIndicator(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAudioModeIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedHeadphones,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 16,
          ),
          Gap(6),
          Text(
            'Audio Only Mode',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, double timeFontSize) {
    return Row(
      children: [
        Text(
          _formatDuration(state.position),
          style: PlayerTheme.getButtonTextStyle(
            context: context,
            fontSize: timeFontSize,
          ),
        ),
        const Gap(8),
        Expanded(
          child: SliderTheme(
            data: PlayerTheme.getSliderTheme(context),
            child: Slider(
              value: state.duration.inSeconds > 0
                  ? state.position.inSeconds.toDouble()
                  : 0.0,
              min: 0,
              max: state.duration.inSeconds > 0
                  ? state.duration.inSeconds.toDouble()
                  : 100.0,
              onChanged: (v) => viewModel.seekTo(Duration(seconds: v.toInt())),
            ),
          ),
        ),
        const Gap(8),
        Text(
          _formatDuration(state.duration),
          style: PlayerTheme.getButtonTextStyle(
            context: context,
            fontSize: timeFontSize,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    bool Function() isLoading,
    double buttonGap,
    double buttonIconSize,
    bool pipEnabled,
  ) {
    return Builder(
      builder: (context) {
        return Row(
          children: [
            _buildActionButton(
              context: context,
              hugeIcon: HugeIcons.strokeRoundedGoBackward10Sec,
              onTap: () {
                final newPos = state.position - const Duration(seconds: 10);
                viewModel.seekTo(newPos.isNegative ? Duration.zero : newPos);
              },
              iconSize: buttonIconSize,
            ),
            Gap(buttonGap),
            isLoading()
                ? _buildLoadingButton(context, buttonIconSize)
                : _buildActionButton(
                    context: context,
                    hugeIcon: state.isPlaying
                        ? HugeIcons.strokeRoundedPause
                        : HugeIcons.strokeRoundedPlay,
                    onTap: viewModel.togglePlayPause,
                    iconSize: buttonIconSize,
                  ),
            Gap(buttonGap),
            _buildActionButton(
              context: context,
              hugeIcon: HugeIcons.strokeRoundedGoForward10Sec,
              onTap: () {
                final newPos = state.position + const Duration(seconds: 10);
                viewModel.seekTo(newPos);
              },
              iconSize: buttonIconSize,
            ),
            const Spacer(),
            Gap(buttonGap),
            _buildActionButton(
              context: context,
              hugeIcon: HugeIcons.strokeRoundedInformationCircle,
              onTap: onDescription,
              iconSize: buttonIconSize,
            ),
            _buildActionButton(
              context: context,
              hugeIcon: HugeIcons.strokeRoundedHeadphones,
              onTap: onAudioOnlyMode,
              iconSize: buttonIconSize,
            ),
            Gap(buttonGap),
            _buildActionButton(
              context: context,
              hugeIcon: HugeIcons.strokeRoundedDownload01,
              onTap: onDownload,
              iconSize: buttonIconSize,
            ),
            Gap(buttonGap),
            _buildActionButton(
              context: context,
              hugeIcon: isFullscreen
                  ? HugeIcons.strokeRoundedArrowShrink
                  : HugeIcons.strokeRoundedArrowExpand,
              onTap: onFullscreen,
              iconSize: buttonIconSize,
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required dynamic hugeIcon,
    required VoidCallback onTap,
    required double iconSize,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: HugeIcon(
        icon: hugeIcon,
        color: PlayerTheme.getIconColor(context),
        size: iconSize,
      ),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildLoadingButton(BuildContext context, double size) {
    return SizedBox(
          width: size * 0.8,
          height: size * 0.8,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            valueColor: AlwaysStoppedAnimation<Color>(
              PlayerTheme.getIconColor(context),
            ),
            backgroundColor: Colors.transparent,
            strokeCap: StrokeCap.round,
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .rotate(duration: 700.ms, begin: 0, end: 1, curve: Curves.linear);
  }

  Widget _buildPlaylistIndicator(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onPlaylist,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.primary, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedLayers02,
              color: theme.colorScheme.primary,
              size: 18,
            ),
            Text(
              'Episode ${state.playlistPosition ?? 1}/${state.playlistTotal ?? 1}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: theme.colorScheme.primary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    return formatDurationFromSeconds(d.inSeconds);
  }
}
