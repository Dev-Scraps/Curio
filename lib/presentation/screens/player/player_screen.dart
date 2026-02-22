// ignore_for_file: use_build_context_synchronously, unused_field, duplicate_ignore, unused_element

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' hide Video;
import '../../../core/services/storage/storage.dart';
import '../../../domain/entities/video.dart';
import 'viewmodels/viewmodel.dart';
import 'widgets/controls.dart';
import 'widgets/gesture_handler.dart';
import 'controllers/modal_controller.dart';
import 'handlers/download_handler.dart';
import 'utils/theme.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final Video? video;
  final List<Video>? playlist;
  final int initialIndex;
  final bool audioOnly;

  const PlayerScreen({
    super.key,
    this.video,
    this.playlist,
    this.initialIndex = 0,
    this.audioOnly = false,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with WidgetsBindingObserver {
  late Player _player;
  late VideoController _controller;
  bool _isFullscreen = false;

  Timer? _controlsTimer;
  mk.VideoController? _videoController;
  int? _playerHash;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.playlist != null && widget.playlist!.isNotEmpty) {
        ref
            .read(playerViewModelProvider.notifier)
            .loadPlaylist(
              widget.playlist!,
              widget.initialIndex,
              forcedAudioOnly: widget.audioOnly,
            );
      } else if (widget.video != null) {
        ref
            .read(playerViewModelProvider.notifier)
            .loadVideo(widget.video!, forcedAudioOnly: widget.audioOnly);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isFullscreen) {
      PlayerTheme.resetSystemUI();
    }
    _controlsTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final viewModel = ref.read(playerViewModelProvider.notifier);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Mark player screen as inactive when app goes to background
        break;
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        // Only mark as active if we're still on the player screen
        if (mounted) {}
        break;
    }
  }

  void _showControls() {
    _controlsTimer?.cancel();
    ref.read(playerViewModelProvider.notifier).setControlsVisible(true);
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        ref.read(playerViewModelProvider.notifier).setControlsVisible(false);
      }
    });
  }

  void _toggleControls() {
    final visible = ref.read(playerViewModelProvider).isControlsVisible;
    if (visible) {
      _controlsTimer?.cancel();
      ref.read(playerViewModelProvider.notifier).setControlsVisible(false);
    } else {
      _showControls();
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      PlayerTheme.setFullscreenSystemUI();
    } else {
      PlayerTheme.setPortraitSystemUI();
    }
  }

  void _toggleAudioOnlyMode() {
    final viewModel = ref.read(playerViewModelProvider.notifier);
    final state = ref.read(playerViewModelProvider);

    // Toggle audio-only mode
    final newAudioOnlyMode = !state.isAudioOnly;

    // Reload the video with new audio mode if we have metadata
    if (state.metadata != null) {
      final currentVideo = Video(
        id: state.metadata!.videoId,
        title: state.metadata!.title,
        channelName: state.metadata!.uploader,
        channelId: '',
        viewCount: state.metadata!.viewCount.toString(),
        uploadDate: state.metadata!.uploadDate,
        duration:
            '${state.metadata!.duration ~/ 60}:${(state.metadata!.duration % 60).toString().padLeft(2, '0')}',
        thumbnailUrl: state.metadata!.rawData['thumbnail'] ?? '',
        url: 'https://www.youtube.com/watch?v=${state.metadata!.videoId}',
        isDownloaded: false,
      );
      viewModel.loadVideo(
        currentVideo,
        initialPosition: state.position,
        forcedAudioOnly: newAudioOnlyMode,
      );
    }

    // Go back to show the mini player
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerViewModelProvider);
    final viewModel = ref.read(playerViewModelProvider.notifier);
    final player = viewModel.player;
    final storage = ref.watch(storageServiceProvider);

    // Force Dark Mode for Player Screen (now theme-aware)
    PlayerTheme.setPlayerSystemUI(context);

    // Cache controller to prevent resizing/flickering on every build
    if (player != null &&
        (viewModel.player.hashCode != _playerHash ||
            _videoController == null)) {
      _videoController = mk.VideoController(player);
      _playerHash = viewModel.player.hashCode;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          // Video with gesture handling OR Thumbnail for audio-only mode
          if (player != null && !state.isAudioOnly)
            PlayerGestureHandler(
              state: state,
              viewModel: viewModel,
              onToggleControls: _toggleControls,
              child: _videoController != null
                  ? mk.Video(
                      controller: _videoController!,
                      controls: mk.NoVideoControls,
                    )
                  : const SizedBox.shrink(),
            ),
          // Show placeholder in audio-only mode
          if (state.isAudioOnly)
            PlayerGestureHandler(
              state: state,
              viewModel: viewModel,
              onToggleControls: _toggleControls,
              child: Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.music_note,
                        size: 80,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.metadata?.title ?? 'Audio Only',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Controls overlay
          if (state.isControlsVisible)
            PlayerControls(
              state: state,
              viewModel: viewModel,

              onSettingsMenu: () =>
                  PlayerModalController.showSettingsMenu(context),
              onAudioOnlyMode: _toggleAudioOnlyMode,
              onDownload: () =>
                  PlayerDownloadHandler.handleDownload(context, ref, state),
              onDescription: () =>
                  PlayerModalController.showDescriptionDialog(context, state),
              onPlaylist: () => PlayerModalController.showPlaylistDialog(
                context,
                state,
                viewModel,
              ),
              onFullscreen: _toggleFullscreen,
              isFullscreen: _isFullscreen,
              isAudioMode: storage.audioOnlyMode,
              onQualitySelector: () {},
            ),
        ],
      ),
    );
  }
}
