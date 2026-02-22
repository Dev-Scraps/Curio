import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit/media_kit.dart' as mk;

class MediaAudioHandler extends BaseAudioHandler {
  final mk.Player _player;

  MediaAudioHandler(this._player) {
    _setupPlaybackCallbacks();
    _setupMediaItem();
  }

  void _setupPlaybackCallbacks() {
    _player.stream.playing.listen((isPlaying) {
      if (isPlaying) {
        playbackState.add(
          playbackState.value.copyWith(
            controls: [MediaControl.pause, MediaControl.stop],
            processingState: AudioProcessingState.ready,
            playing: true,
          ),
        );
      } else {
        playbackState.add(
          playbackState.value.copyWith(
            controls: [MediaControl.play, MediaControl.stop],
            processingState: AudioProcessingState.ready,
            playing: false,
          ),
        );
      }
    });

    _player.stream.position.listen((position) {
      playbackState.add(playbackState.value.copyWith(updatePosition: position));
    });

    _player.stream.duration.listen((duration) {
      playbackState.add(
        playbackState.value.copyWith(updatePosition: _player.state.position),
      );
    });

    _player.stream.completed.listen((completed) {
      if (completed) {
        playbackState.add(
          playbackState.value.copyWith(
            processingState: AudioProcessingState.completed,
          ),
        );
      }
    });
  }

  void _setupMediaItem() {
    // This will be updated when a video starts playing
    mediaItem.add(
      const MediaItem(id: '', title: 'Curio', artist: '', artUri: null),
    );
  }
}
