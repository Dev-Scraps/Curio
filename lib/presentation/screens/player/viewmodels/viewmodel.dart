import 'dart:io';
import 'dart:async';
import 'package:curio/core/services/storage/storage.dart';
import 'package:flutter/foundation.dart';
import '../widgets/format_parser.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:media_kit/media_kit.dart';
import '../../../../domain/entities/video.dart';
import '../../../../domain/entities/comment.dart';
import '../../../../core/services/yt_dlp/youtube.dart';
import '../../../../core/services/content/sync.dart';
import '../../../../core/services/system/notifications.dart';
import '../../../../core/services/yt_dlp/ytdlp.dart';
import '../../../../core/services/content/progress.dart';

part 'viewmodel.g.dart';

// Quality format info
class QualityFormat {
  final String formatId;
  final String resolution;
  final String codec;
  final int? filesize;
  final String? fps;
  final num? vbr;
  final num? abr;
  final num? tbr;
  final int? width;
  final int? height;
  final String vcodec;
  final String acodec;

  QualityFormat({
    required this.formatId,
    required this.resolution,
    required this.codec,
    this.filesize,
    this.fps,
    this.vbr,
    this.abr,
    this.tbr,
    this.width,
    this.height,
    required this.vcodec,
    required this.acodec,
  });

  @override
  String toString() =>
      '$resolution • $codec${fps != null ? ' • ${fps}fps' : ''}';
}

// Caption format info
class CaptionFormat {
  final String lang;
  final String name;
  final String type; // 'sub', 'vss', 'cc'

  CaptionFormat({required this.lang, required this.name, required this.type});

  @override
  String toString() => '$name ($lang)';
}

// Extended metadata
class VideoMetadata {
  final String videoId;
  final String title;
  final String uploader;
  final String uploaderUrl;
  final String uploadDate;
  final int viewCount;
  final double? averageRating;
  final int likeCount;
  final int commentCount;
  final String? description;
  final int duration;
  final String? license;
  final String? categories;
  final List<String>? tags;
  final List<QualityFormat> availableFormats;
  final String selectedFormat;
  final List<CaptionFormat> availableCaptions;
  final Map<String, dynamic> rawData;

  VideoMetadata({
    required this.videoId,
    required this.title,
    required this.uploader,
    required this.uploaderUrl,
    required this.uploadDate,
    required this.viewCount,
    this.averageRating,
    this.likeCount = 0,
    this.commentCount = 0,
    this.description,
    required this.duration,
    this.license,
    this.categories,
    this.tags,
    required this.availableFormats,
    required this.selectedFormat,
    this.availableCaptions = const [],
    required this.rawData,
  });
}

@riverpod
class PlayerViewModel extends _$PlayerViewModel {
  Player? _player;
  Video? _currentVideo;
  Timer? _sleepTimer;
  Timer? _progressSaveTimer;
  List<Video> _playlistQueue = [];
  int _currentPlaylistIndex = -1;
  bool _isDisposed = false;
  int _currentExtractionId = 0;

  void dispose() {
    _isDisposed = true;
    _saveProgressIfNeeded(); // Save final progress before disposal
    _player?.dispose();
    _player = null;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _progressSaveTimer?.cancel();
    _progressSaveTimer = null;
  }

  @override
  PlayerState build() {
    ref.onDispose(() {
      _saveProgressIfNeeded();
      _player?.dispose();
      _player = null; // CRITIVE: null out the player
      _sleepTimer?.cancel();
      _progressSaveTimer?.cancel();
    });

    return PlayerState(
      isPlaying: false,
      position: Duration.zero,
      duration: Duration.zero,
      isControlsVisible: true,
    );
  }

  /// Save progress if video is playing and meaningful progress has been made
  Future<void> _saveProgressIfNeeded() async {
    if (_currentVideo == null || _player == null) return;

    final position = _player!.state.position;
    final duration = _player!.state.duration;

    // Only save if we have valid duration and position
    if (duration.inSeconds > 0 && position.inSeconds > 5) {
      try {
        await ref
            .read(videoProgressServiceProvider)
            .saveProgress(
              videoId: _currentVideo!.id,
              watchedSeconds: position.inSeconds,
              totalSeconds: duration.inSeconds,
            );
      } catch (e) {
        print('[PlayerViewModel] Error saving progress: $e');
      }
    }
  }

  /// Start periodic progress autosave (every 10 seconds)
  void _startProgressAutosave() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _saveProgressIfNeeded(),
    );
  }

  Future<void> loadVideo(
    Video video, {
    Duration? initialPosition,
    bool? forcedAudioOnly,
  }) async {
    if (_isDisposed || !ref.mounted) return;

    try {
      _currentVideo = video;

      // Load saved stream quality from storage
      final storage = ref.read(storageServiceProvider);
      final savedQuality = storage.streamQuality;
      final useAudioOnly = forcedAudioOnly ?? storage.audioOnlyMode;

      print(
        '[PlayerViewModel] Loading video. AudioOnly: $useAudioOnly, Quality: $savedQuality',
      );

      // Update state to show loading
      state = state.copyWith(
        isPlaying: false,
        position: initialPosition ?? Duration.zero,
        duration: Duration.zero,
        selectedQuality: savedQuality,

        // PHASE 4: Full metadata and other data loading
        // Start additional background fetches concurrently for speed
        clearError: true,
        metadata: null,
        availableQualities: const [],
        isLoadingMetadata: true,
        isFirstFrameReady: false,
        playlistVideos: _playlistQueue,
        playlistIndex: _currentPlaylistIndex,
        playlistPosition: _currentPlaylistIndex >= 0
            ? _currentPlaylistIndex + 1
            : null,
        playlistTotal: _playlistQueue.isNotEmpty ? _playlistQueue.length : null,
        isAudioOnly: useAudioOnly,
      );

      // Ensure player instance exists and is not disposed
      if (_player == null) {
        _player = Player();
        _setupPlayerListeners();
      }

      // PHASE 1: Quick load logic
      print('[PlayerViewModel] PHASE 1: Initializing playback...');

      // Build metadata future but don't start it yet if we have local file
      Future<void>? metadataFuture;

      if (video.isDownloaded && video.filePath != null) {
        final file = File(video.filePath!);
        if (await file.exists()) {
          print('[PlayerViewModel] Local file found: ${video.filePath}');
          if (!ref.mounted || _isDisposed) return;
          try {
            await _player?.open(Media(file.path));
            print('[PlayerViewModel] Local playback started successfully');
          } catch (e) {
            if (!ref.mounted || _isDisposed) return;
            print(
              '[PlayerViewModel] Failed to open local file: $e. Falling back to online.',
            );
            await _loadOnlineVideo(video, forcedAudioOnly: forcedAudioOnly);
            metadataFuture = _extractMetadata(video);
          }
        } else {
          if (!ref.mounted || _isDisposed) return;
          print(
            '[PlayerViewModel] Local file missing: ${video.filePath}. Falling back to online.',
          );
          await _loadOnlineVideo(video, forcedAudioOnly: forcedAudioOnly);
          metadataFuture = _extractMetadata(video);
        }
      } else {
        await _loadOnlineVideo(video, forcedAudioOnly: forcedAudioOnly);
        metadataFuture = _extractMetadata(video);
      }

      if (initialPosition != null && initialPosition > Duration.zero) {
        await _player?.seek(initialPosition);
      }

      // Video already initialized in Phase 1

      // PHASE 2: Show video with quick title from video object
      print(
        '[PlayerViewModel] PHASE 2: Video initialized, starting playback...',
      );
      state = state.copyWith(
        duration: _player!.state.duration,
        isPlaying: false,
        // Create minimal metadata immediately for quick display
        metadata: VideoMetadata(
          videoId: video.id,
          title: video.title,
          uploader: video.channelName,
          uploaderUrl: '',
          uploadDate: video.uploadDate,
          viewCount: 0,
          duration: _player!.state.duration.inSeconds,
          availableFormats: [],
          selectedFormat: 'auto',
          rawData: {},
        ),
        // Don't set isLoadingMetadata to false yet - still fetching details
      );

      // Auto-play immediately
      await _player?.play();
      if (!ref.mounted || _isDisposed) return;
      state = state.copyWith(isPlaying: true);

      // Start autosaving progress every 10 seconds
      _startProgressAutosave();

      // Check for saved progress and restore if user wants
      try {
        final resumePosition = await ref
            .read(videoProgressServiceProvider)
            .getResumePosition(video.id);
        if (resumePosition != null && !_isDisposed && ref.mounted) {
          // Seek to saved position
          await _player?.seek(Duration(seconds: resumePosition));
          print(
            '[PlayerViewModel] Restored playback position to ${Duration(seconds: resumePosition)}',
          );
        }
      } catch (e) {
        print('[PlayerViewModel] Error restoring progress: $e');
      }

      // PHASE 3: Wait for metadata in parallel while streaming (if any)
      if (metadataFuture != null) {
        print(
          '[PlayerViewModel] PHASE 3: Fetching full metadata in background...',
        );
        try {
          await metadataFuture;
          if (!ref.mounted || _isDisposed) return;
          // After metadata is fetched, we also start background tasks
          loadComments(video.id);
          loadCaptions(video.id);
          loadSuggestedVideos(video.id);

          // Load audio tracks from yt-dlp
          if (video.url != null && video.url!.isNotEmpty) {
            loadAudioTracks(video.url!);
          }
        } catch (e) {
          print('[PlayerViewModel] Metadata fetch error (non-blocking): $e');
        }
      } else {
        print('[PlayerViewModel] Skipping metadata fetch (offline mode)');
        // Still load audio tracks for local files
        if (video.url != null && video.url!.isNotEmpty) {
          loadAudioTracks(video.url!);
        }
      }
    } catch (e) {
      print('Error loading video: $e');
      if (ref.mounted && !_isDisposed) {
        state = state.copyWith(
          errorMessage: e.toString(),
          isLoadingMetadata: false,
        );
      }
    }
  }

  Future<void> loadPlaylist(
    List<Video> videos,
    int startIndex, {
    bool? forcedAudioOnly,
  }) async {
    if (_isDisposed || !ref.mounted || videos.isEmpty) return;

    try {
      // Ensure startIndex is within bounds
      startIndex = startIndex.clamp(0, videos.length - 1);

      _playlistQueue = List<Video>.from(videos);
      _currentPlaylistIndex = startIndex;

      // Update state to reflect new playlist
      if (!_isDisposed && ref.mounted) {
        state = state.copyWith(
          playlistVideos: _playlistQueue,
          playlistIndex: _currentPlaylistIndex,
          playlistPosition: _currentPlaylistIndex + 1,
          playlistTotal: _playlistQueue.length,
          isLoadingMetadata: true,
        );
      }

      // Load the target video with audio-only mode if specified
      if (!_isDisposed && ref.mounted) {
        await loadVideo(
          _playlistQueue[_currentPlaylistIndex],
          forcedAudioOnly: forcedAudioOnly,
        );
      }
    } catch (e) {
      if (!_isDisposed && ref.mounted) {
        state = state.copyWith(
          errorMessage: 'Error loading playlist: $e',
          isLoadingMetadata: false,
        );
      }
    }
  }

  Future<void> playNextVideo() async {
    if (_playlistQueue.isEmpty ||
        _currentPlaylistIndex >= _playlistQueue.length - 1) {
      // If we're at the end of the playlist, stop or loop back to start
      // Uncomment the next line to enable playlist looping
      // _currentPlaylistIndex = -1;
      return;
    }

    _currentPlaylistIndex++;
    state = state.copyWith(
      playlistIndex: _currentPlaylistIndex,
      playlistPosition: _currentPlaylistIndex + 1,
    );
    // Preserve audio-only mode when navigating to next video
    await loadVideo(
      _playlistQueue[_currentPlaylistIndex],
      forcedAudioOnly: state.isAudioOnly,
    );
  }

  Future<void> playPreviousVideo() async {
    if (_playlistQueue.isEmpty || _currentPlaylistIndex <= 0) return;

    _currentPlaylistIndex--;
    state = state.copyWith(
      playlistIndex: _currentPlaylistIndex,
      playlistPosition: _currentPlaylistIndex + 1,
    );
    // Preserve audio-only mode when navigating to previous video
    await loadVideo(
      _playlistQueue[_currentPlaylistIndex],
      forcedAudioOnly: state.isAudioOnly,
    );
  }

  Future<void> playVideoAtIndex(int index) async {
    if (_playlistQueue.isEmpty || index < 0 || index >= _playlistQueue.length) {
      return;
    }

    _currentPlaylistIndex = index;
    state = state.copyWith(
      playlistIndex: _currentPlaylistIndex,
      playlistPosition: _currentPlaylistIndex + 1,
    );
    await loadVideo(_playlistQueue[_currentPlaylistIndex]);
  }

  Future<void> _extractMetadata(Video video) async {
    final extractionId = _currentExtractionId;

    try {
      print('[PlayerViewModel] Extracting full metadata...');
      if (_isDisposed) return;

      final ytDlpService = ref.read(ytDlpServiceProvider);
      final syncService = ref.read(syncServiceProvider.notifier);
      final notificationService = ref.read(notificationServiceProvider);
      final cookiePath = await syncService.getActiveCookiePath();

      if (!ref.mounted || _isDisposed) return;

      // Show fetching notification
      notificationService.showFetchingNotification(videoTitle: video.title);

      // Build proper video URL (not playlist URL)
      String videoUrl = video.url ?? '';
      if (videoUrl.isEmpty || videoUrl.contains('playlist')) {
        videoUrl = 'https://www.youtube.com/watch?v=${video.id}';
      }

      print('[PlayerViewModel] Extracting metadata for: $videoUrl');

      String? metadataFetchError;
      final metadata = await ytDlpService.fetchMetadata(
        videoUrl,
        cookiePath: cookiePath,
      );
      if (!ref.mounted || _isDisposed) return;

      if (metadata.containsKey('_error')) {
        metadataFetchError = metadata['_error'] as String?;
        print(
          '[PlayerViewModel] YtDlpService returned safe metadata with error: $metadataFetchError',
        );
      }

      print('[PlayerViewModel] Metadata fetched, parsing formats (isolate)...');

      // Parse quality formats in an isolate
      final formats = await _parseFormats(metadata);
      if (!ref.mounted || _isDisposed) return;

      print('[PlayerViewModel] Found ${formats.length} available qualities');
      for (var fmt in formats) {
        print('  - ${fmt.resolution} (${fmt.codec})');
      }

      // Build complete metadata object
      final videoMetadata = VideoMetadata(
        videoId: video.id,
        title: metadata['title'] ?? video.title,
        uploader: metadata['uploader'] ?? video.channelName,
        uploaderUrl: metadata['uploader_url'] ?? '',
        uploadDate: metadata['upload_date'] ?? video.uploadDate,
        viewCount: int.tryParse(metadata['view_count']?.toString() ?? '0') ?? 0,
        averageRating: double.tryParse(
          metadata['average_rating']?.toString() ?? '0',
        ),
        likeCount: int.tryParse(metadata['like_count']?.toString() ?? '0') ?? 0,
        commentCount:
            int.tryParse(metadata['comment_count']?.toString() ?? '0') ?? 0,
        description: metadata['description'],
        duration: metadata['duration'] ?? 0,
        license: metadata['license'],
        categories: metadata['categories']?.toString(),
        tags: (metadata['tags'] as List?)?.cast<String>(),
        availableFormats: formats,
        selectedFormat: 'auto',
        rawData: metadata,
      );

      print('[PlayerViewModel] Metadata extraction complete');

      // Update state with full metadata and complete quality list
      if (!_isDisposed && ref.mounted && extractionId == _currentExtractionId) {
        state = state.copyWith(
          metadata: videoMetadata,
          availableQualities: formats,
          isLoadingMetadata: false,
          errorMessage: metadataFetchError,
        );
      }
    } catch (e) {
      if (!_isDisposed && ref.mounted && extractionId == _currentExtractionId) {
        state = state.copyWith(isLoadingMetadata: false);
      }
    } finally {
      // Always dismiss fetching notification
      ref.read(notificationServiceProvider).cancel('fetching');
    }
  }

  Future<List<QualityFormat>> _parseFormats(
    Map<String, dynamic> metadata,
  ) async {
    final formatsList = metadata['formats'] as List?;
    if (formatsList == null) return [];

    print('[PlayerViewModel] Raw formats list length: ${formatsList.length}');

    final results = <QualityFormat>[];
    int videoCount = 0, audioCount = 0, combinedCount = 0;

    for (final format in formatsList) {
      if (format is! Map) continue;

      final vcodec = (format['vcodec']?.toString() ?? 'none');
      final acodec = (format['acodec']?.toString() ?? 'none');
      final formatId = format['format_id']?.toString() ?? '';
      final height = format['height'] as int?;

      // Debug: Print each format being processed
      print(
        '[PlayerViewModel] Processing format $formatId: vcodec=$vcodec, acodec=$acodec, height=$height',
      );

      // Skip formats with no video and no audio codecs (manifests, thumbnails, etc.)
      if (vcodec == 'none' && acodec == 'none') {
        print('[PlayerViewModel] Skipping format $formatId: no audio/video');
        continue;
      }

      final width = format['width'] as int?;
      final ext = format['ext']?.toString() ?? '';
      final filesize =
          format['filesize'] as int? ?? format['filesize_approx'] as int?;
      final fps = format['fps'] as num?;
      final abr = format['abr'] as num?;
      final vbr = format['vbr'] as num?;
      final tbr = format['tbr'] as num?;

      // Debug: Print each format being processed
      print(
        '[PlayerViewModel] Processing format $formatId: vcodec=$vcodec, acodec=$acodec, height=$height, ext=$ext',
      );

      // Count format types
      if (vcodec != 'none' && acodec != 'none') {
        combinedCount++;
        print('[PlayerViewModel] Format $formatId is COMBINED');
      } else if (vcodec != 'none') {
        videoCount++;
        print('[PlayerViewModel] Format $formatId is VIDEO-ONLY');
      } else {
        audioCount++;
        print('[PlayerViewModel] Format $formatId is AUDIO-ONLY');
      }

      // Create detailed label based on format type
      String label;
      if (vcodec == 'none') {
        // Audio format - show bitrate
        label = abr != null ? '${abr.round()}kbps' : 'Audio';
      } else {
        // Video format - show resolution with details
        String resLabel = height != null ? '${height}p' : 'Video';
        if (height != null && height >= 2160) {
          resLabel = '4K';
        } else if (height != null && height >= 1440) {
          resLabel = '2K';
        }
        label = resLabel;
      }

      // Build codec string with details
      String codecInfo = ext.toUpperCase();
      if (vcodec != 'none' && vcodec != 'none') {
        // Extract codec name (e.g., "av01.0.01M.08" -> "AV1")
        final codecName = vcodec.split('.')[0].toUpperCase();
        codecInfo = codecName;
      }
      if (acodec != 'none' && acodec != 'none' && vcodec == 'none') {
        // Audio codec
        final codecName = acodec.split('.')[0].toUpperCase();
        codecInfo = codecName;
      }

      results.add(
        QualityFormat(
          formatId: formatId,
          resolution: label,
          codec: codecInfo,
          filesize: filesize,
          fps: fps?.toString(),
          vbr: vbr,
          abr: abr,
          tbr: tbr,
          width: width,
          height: height,
          vcodec: vcodec,
          acodec: acodec,
        ),
      );
    }

    print(
      '[PlayerViewModel] Format counts - Video: $videoCount, Audio: $audioCount, Combined: $combinedCount',
    );
    print('[PlayerViewModel] Total parsed formats: ${results.length}');

    // Sort: Resolution (height) descending, then combined preferred over video-only
    results.sort((a, b) {
      // 1. Sort by resolution (height) descending
      final aHeight = a.height ?? 0;
      final bHeight = b.height ?? 0;
      if (aHeight != bHeight) {
        return bHeight.compareTo(aHeight); // Descending
      }

      // 2. If same resolution, prefer combined over video-only
      // Extract format details for type comparison
      final aFormat = formatsList.firstWhere(
        (f) => f is Map && f['format_id']?.toString() == a.formatId,
        orElse: () => <String, dynamic>{},
      );
      final bFormat = formatsList.firstWhere(
        (f) => f is Map && f['format_id']?.toString() == b.formatId,
        orElse: () => <String, dynamic>{},
      );

      final aVcodec = aFormat['vcodec']?.toString() ?? 'none';
      final aAcodec = aFormat['acodec']?.toString() ?? 'none';
      final bVcodec = bFormat['vcodec']?.toString() ?? 'none';
      final bAcodec = bFormat['acodec']?.toString() ?? 'none';

      final aIsCombined = aVcodec != 'none' && aAcodec != 'none';
      final bIsCombined = bVcodec != 'none' && bAcodec != 'none';

      if (aIsCombined != bIsCombined) {
        return aIsCombined ? -1 : 1; // Combined first if heights equal
      }

      // 3. Keep existing tie-breakers (bitrate/tbr)
      final aTbr = aFormat['tbr'] as num? ?? 0;
      final bTbr = bFormat['tbr'] as num? ?? 0;
      return bTbr.compareTo(aTbr);
    });

    return results;
  }

  // Quality naming moved to isolate parser; helper removed.

  void selectQuality(String formatId) {
    state = state.copyWith(
      selectedQuality: formatId,
      isBuffering: true,
      isChangingQuality: true,
    );
    _reloadVideoWithQuality(formatId);
  }

  Future<void> loadAudioTracks(String videoUrl) async {
    try {
      final ytDlp = ref.read(ytDlpServiceProvider);
      print(
        '[PlayerViewModel] loadAudioTracks: Fetching audio tracks for $videoUrl',
      );
      final audioTracksData = await ytDlp.getAudioTracks(videoUrl);
      print(
        '[PlayerViewModel] loadAudioTracks: Received ${audioTracksData.length} raw tracks',
      );

      final audioTracks = audioTracksData.map((data) {
        final track = AudioTrack(
          id: data['itag']?.toString() ?? '',
          language: data['lang']?.toString() ?? 'unknown',
          label: data['name']?.toString() ?? 'Audio Track',
        );
        print(
          '[PlayerViewModel] Parsed audio track: ${track.id} (${track.language}) - ${track.label}',
        );
        return track;
      }).toList();

      if (ref.mounted) {
        state = state.copyWith(
          availableAudioTracks: audioTracks,
          selectedAudioTrack: audioTracks.isNotEmpty
              ? audioTracks.first.id
              : null,
        );
      }
    } catch (e) {
      print('[PlayerViewModel] Error loading audio tracks: $e');
    }
  }

  Future<void> selectAudioTrack(String trackId) async {
    if (_currentVideo == null) return;

    try {
      // Reload video with the selected audio track format
      await _loadOnlineVideo(_currentVideo!, formatId: trackId);

      if (ref.mounted) {
        state = state.copyWith(selectedAudioTrack: trackId);
      }
    } catch (e) {
      print('[PlayerViewModel] Error selecting audio track: $e');
    }
  }

  Future<void> _reloadVideoWithQuality(String formatId) async {
    if (_currentVideo == null) return;

    try {
      // SAVE CURRENT POSITION AND PLAYBACK STATE BEFORE SWITCHING
      final currentPosition = _player?.state.position ?? Duration.zero;
      final wasPlaying = _player?.state.playing ?? false;
      print(
        '[PlayerViewModel] Saving position before quality change: $currentPosition, wasPlaying: $wasPlaying',
      );

      // Pause current playback and clear buffering state
      if (_player != null && _player!.state.playing) {
        await _player!.pause();
      }

      // Set buffering state to show loading indicator
      state = state.copyWith(isBuffering: true, isFirstFrameReady: false);

      final youtubeService = ref.read(youtubeServiceProvider);
      final syncService = ref.read(syncServiceProvider.notifier);
      final cookiePath = await syncService.getActiveCookiePath();

      // Use dual-source method to get both video and audio URLs and headers
      final result = await youtubeService.getVideoAndAudioUrls(
        _currentVideo!.id,
        cookiePath ?? '',
        formatId: formatId,
      );

      final headers = result.headers;

      // Ensure we have at least some headers if service returned empty
      if (headers.isEmpty) {
        headers.addAll({
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36',
          'Accept': '*/*',
          'Origin': 'https://www.youtube.com',
          'Referer': 'https://www.youtube.com/watch?v=${_currentVideo!.id}',
        });
      }

      // Fix: urls var is gone.
      final String videoUrl = result.videoUrl;
      final String? bestAudioUrl = result.audioUrl;
      final List<Map<String, String>> sourceAudioTracks = result.audioTracks;

      // If we have separate audio tracks
      if (bestAudioUrl != null || sourceAudioTracks.isNotEmpty) {
        print(
          '[PlayerViewModel] Using dual-source playback: video + separate audio',
        );

        print('[PlayerViewModel] Video URL: $videoUrl');
        print(
          '[PlayerViewModel] Audio Tracks: ${sourceAudioTracks.length} tracks found',
        );

        // Format headers for mpv options
        // mpv expects 'http-header-fields' to be a comma-separated list of "Key: Value"
        final headerFields = headers.entries
            .where((e) => e.key.toLowerCase() != 'user-agent')
            .map((e) => '${e.key}: ${e.value}')
            .join(',');

        print('[PlayerViewModel] Setting mpv headers: $headerFields');

        // Construct list of audio URLs
        String audioFilesValue;
        if (sourceAudioTracks.isNotEmpty) {
          // Add all URLs. Mpv supports comma separated list?
          // Note: if URLs contain commas, this breaks. URL encoding?
          // Mpv --audio-files expects paths.
          audioFilesValue = sourceAudioTracks.map((t) => t['url']).join(',');
        } else {
          audioFilesValue = bestAudioUrl!;
        }

        // Create video media with external audio file via mpv option
        final Map<String, String> extras = {
          'audio-files': audioFilesValue,
          'audio-files-auto': 'inf',
          'user-agent': headers['User-Agent'] ?? 'Mozilla/5.0', // Fallback
          'http-header-fields': headerFields,
        };

        if (cookiePath != null && cookiePath.isNotEmpty) {
          print('[PlayerViewModel] Setting mpv cookies-file: $cookiePath');
          extras['cookies-file'] = cookiePath;
        }

        final videoMediaWithAudio = Media(
          videoUrl,
          httpHeaders: headers,
          extras: extras,
        );

        await _player?.open(videoMediaWithAudio, play: false);

        // Wait a bit for tracks to load
        await Future.delayed(const Duration(milliseconds: 1000));

        print('[PlayerViewModel] Audio URL provided: $bestAudioUrl');
        print(
          '[PlayerViewModel] Available audio tracks: ${_player?.state.tracks.audio.map((t) => t.id)}',
        );

        // If we have multiple tracks, ensure the external one (likely the last one or non-default) is selected
        final playerAudioTracks = _player?.state.tracks.audio ?? [];
        // Look for a track that is NOT 'auto' and NOT 'no' (which usually means 'no audio')
        // Prefer one that matches our language preference if implemented, otherwise pick first valid.
        final externalTrack = playerAudioTracks.firstWhere(
          (t) => t.id != 'auto' && t.id != 'no',
          orElse: () => playerAudioTracks.first,
        );

        if (externalTrack.id != 'auto') {
          print(
            '[PlayerViewModel] External audio track found (ID: ${externalTrack.id}). Selecting it...',
          );
          await _player?.setAudioTrack(externalTrack);
        } else {
          print(
            '[PlayerViewModel] WARNING: External audio track not found in player tracks!',
          );
        }
      } else {
        // Combined format (has both video and audio)
        print('[PlayerViewModel] Using combined format playback');
        // Recreate videoMedia since we removed the top variable
        final videoMedia = Media(videoUrl, httpHeaders: headers);
        await _player?.open(videoMedia, play: false);
      }

      // Wait a moment for the media to load properly before seeking
      await Future.delayed(const Duration(milliseconds: 500));

      // RESTORE POSITION AFTER NEW STREAM LOADS
      if (currentPosition > Duration.zero) {
        print(
          '[PlayerViewModel] Attempting to restore position after quality change: $currentPosition',
        );

        // Try to seek to the saved position with retry logic
        int retryCount = 0;
        const maxRetries = 3;

        while (retryCount < maxRetries) {
          try {
            await _player?.seek(currentPosition);

            // Verify the position was actually set
            await Future.delayed(const Duration(milliseconds: 100));
            final actualPosition = _player?.state.position ?? Duration.zero;

            // Check if we're close enough to the target position (within 2 seconds)
            if ((actualPosition - currentPosition).inSeconds.abs() <= 2) {
              print(
                '[PlayerViewModel] Successfully restored position after quality change: $actualPosition',
              );
              break;
            } else {
              print(
                '[PlayerViewModel] Position not accurately restored, retrying... Attempt: ${retryCount + 1}',
              );
              retryCount++;
              if (retryCount < maxRetries) {
                await Future.delayed(const Duration(milliseconds: 200));
              }
            }
          } catch (e) {
            print(
              '[PlayerViewModel] Error seeking to position, retrying... $e',
            );
            retryCount++;
            if (retryCount < maxRetries) {
              await Future.delayed(const Duration(milliseconds: 300));
            }
          }
        }

        if (retryCount >= maxRetries) {
          print(
            '[PlayerViewModel] Failed to restore position after $maxRetries attempts',
          );
        }
      }

      // Update state and restore playback
      state = state.copyWith(
        duration: _player?.state.duration ?? Duration.zero,
        isBuffering: false,
        isChangingQuality: false,
      );

      // Restore playback state
      if (wasPlaying) {
        await _player?.play();
        state = state.copyWith(isPlaying: true);
      } else {
        // Start playback since user selected a quality
        await _player?.play();
        state = state.copyWith(isPlaying: true);
      }
    } catch (e) {
      print('Error reloading video with quality: $e');
      if (ref.mounted && !_isDisposed) {
        state = state.copyWith(
          errorMessage: e.toString(),
          isLoadingMetadata: false,
          isBuffering: false,
          isChangingQuality: false,
        );
      }
    }
  }

  Future<void> _loadOnlineVideo(
    Video video, {
    bool isRetry = false,
    bool? forcedAudioOnly,
    String? formatId,
  }) async {
    final youtubeService = ref.read(youtubeServiceProvider);
    final syncService = ref.read(syncServiceProvider.notifier);
    final storage = ref.read(storageServiceProvider);
    final cookiePath = await syncService.getActiveCookiePath();

    try {
      print(
        '[PlayerViewModel] Loading stream URL${isRetry ? ' (RETRY with fresh URL)' : ''}...',
      );

      // If this is a retry, clear the stream URL cache first
      if (isRetry) {
        final ytDlpService = ref.read(ytDlpServiceProvider);
        ytDlpService.clearStreamUrlCache();
        print('[PlayerViewModel] Stream URL cache cleared for retry');
      }

      final useAudioOnly =
          forcedAudioOnly ?? ref.read(storageServiceProvider).audioOnlyMode;
      final savedQuality = storage.streamQuality;

      // Use formatId if provided, otherwise use saved quality or 'best' for audio-only
      final qualitySetting = formatId ?? (useAudioOnly ? 'best' : savedQuality);

      final streamUrl = await youtubeService.getStreamUrl(
        video.id,
        cookiePath ?? '',
        audioOnly: useAudioOnly,
        qualitySetting: qualitySetting,
      );

      print(
        '[PlayerViewModel] Stream URL obtained: ${streamUrl.substring(0, 50)}...',
      );

      // Enhanced HTTP headers to prevent 403 errors
      final headers = {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': '*/*',
        'Accept-Encoding': 'identity;q=1, *;q=0',
        'Accept-Language': 'en-US,en;q=0.9',
        'Origin': 'https://www.youtube.com',
        'Referer': 'https://www.youtube.com/watch?v=${video.id}',
        'Sec-Fetch-Dest': 'video',
        'Sec-Fetch-Mode': 'no-cors',
        'Sec-Fetch-Site': 'cross-site',
      };

      // Open media with HTTP headers using media_kit
      await _player?.open(Media(streamUrl, httpHeaders: headers));
      print('[PlayerViewModel] Video player opened with HTTP headers');
    } catch (e) {
      print('[PlayerViewModel] Error getting stream URL: $e');

      // If the player was disposed during the async gap, don't retry or update state
      if (!ref.mounted || _isDisposed) return;

      // If this is the first attempt, retry with cache bypass
      if (!isRetry) {
        print(
          '[PlayerViewModel] First attempt failed, retrying with fresh URL...',
        );
        await _loadOnlineVideo(video, isRetry: true);
      } else {
        // Both attempts failed, rethrow
        print('[PlayerViewModel] Retry also failed, giving up');
        rethrow;
      }
    }
  }

  void togglePlayPause() {
    if (_isDisposed || _player == null) return;
    try {
      if (_player!.state.playing) {
        _player!.pause();
        state = state.copyWith(isPlaying: false);
      } else {
        _player!.play();
        state = state.copyWith(isPlaying: true);
      }
    } catch (e) {
      print('[PlayerViewModel] Error toggling play/pause: $e');
    }
  }

  void seekTo(Duration position) {
    if (_isDisposed || _player == null) return;
    try {
      _player!.seek(position);
    } catch (e) {
      print('[PlayerViewModel] Error seeking: $e');
    }
  }

  void toggleControls() {
    state = state.copyWith(isControlsVisible: !state.isControlsVisible);
  }

  void setPlaybackSpeed(double speed) {
    if (_isDisposed || _player == null) return;
    try {
      _player!.setRate(speed);
      state = state.copyWith(playbackSpeed: speed);
    } catch (e) {
      print('[PlayerViewModel] Error setting playback speed: $e');
    }
  }

  Future<void> loadComments(String videoId) async {
    if (_isDisposed) return;
    state = state.copyWith(isLoadingComments: true);
    try {
      final syncService = ref.read(syncServiceProvider.notifier);
      final cookiePath = await syncService.getActiveCookiePath();
      if (!ref.mounted || _isDisposed) return;

      final ytDlpService = ref.read(ytDlpServiceProvider);

      final url = 'https://www.youtube.com/watch?v=$videoId';

      // Fetch comments using yt-dlp
      final metadata = await ytDlpService.fetchMetadata(
        url,
        cookiePath: cookiePath,
      );
      if (!ref.mounted || _isDisposed) return;

      final comments = <Comment>[];

      // Try to extract comments from metadata
      if (metadata.containsKey('comments')) {
        final commentsList = metadata['comments'] as List?;
        if (commentsList != null) {
          for (final commentData in commentsList) {
            try {
              if (commentData is Map) {
                final comment = Comment(
                  id: commentData['id']?.toString() ?? '',
                  author: commentData['author']?.toString() ?? '',
                  authorId: commentData['author_id']?.toString() ?? '',
                  text: commentData['text']?.toString() ?? '',
                  publishedAt:
                      commentData['published_at']?.toString() ??
                      DateTime.now().toIso8601String(),
                  likeCount:
                      int.tryParse(commentData['likes']?.toString() ?? '0') ??
                      0,
                  authorProfileImageUrl: commentData['author_thumbnail']
                      ?.toString(),
                  isPinned: commentData['is_favorited'] == true,
                );
                comments.add(comment);
              }
            } catch (e) {
              print('Error parsing comment: $e');
            }
          }
        }
      }

      if (!_isDisposed && ref.mounted) {
        state = state.copyWith(comments: comments, isLoadingComments: false);
      }
    } catch (e) {
      print('Error loading comments: $e');
      if (!_isDisposed && ref.mounted) {
        state = state.copyWith(comments: [], isLoadingComments: false);
      }
    }
  }

  Future<void> loadSuggestedVideos(String videoId) async {
    if (_isDisposed) return;
    state = state.copyWith(isLoadingSuggested: true);
    try {
      // For now, use a simple approach: search for videos with similar tags from metadata
      if (state.metadata?.tags != null && state.metadata!.tags!.isNotEmpty) {
        final syncService = ref.read(syncServiceProvider.notifier);
        final cookiePath = await syncService.getActiveCookiePath();
        if (!ref.mounted || _isDisposed) return;

        final ytDlpService = ref.read(ytDlpServiceProvider);

        // Use the first tag to search for related videos
        final searchQuery = state.metadata!.tags!.first;

        try {
          // Search YouTube for videos with the tag
          final searchUrl = 'ytsearch5:$searchQuery';
          final metadata = await ytDlpService.fetchMetadata(
            searchUrl,
            cookiePath: cookiePath,
          );
          if (!ref.mounted || _isDisposed) return;

          final suggested = <Video>[];

          if (metadata.containsKey('entries')) {
            final entries = metadata['entries'] as List?;
            if (entries != null) {
              for (final entry in entries) {
                try {
                  // Skip the current video
                  if (entry['id']?.toString() == videoId) continue;

                  final video = Video.fromJson(entry);
                  suggested.add(video);
                } catch (e) {
                  print('Error parsing suggested video: $e');
                }
              }
            }
          }

          if (!_isDisposed && ref.mounted) {
            state = state.copyWith(
              suggestedVideos: suggested,
              isLoadingSuggested: false,
            );
          }
        } catch (e) {
          print('Error searching for suggested videos: $e');
          // Fallback to empty list
          if (!_isDisposed && ref.mounted) {
            state = state.copyWith(
              suggestedVideos: [],
              isLoadingSuggested: false,
            );
          }
        }
      } else {
        // No tags available, return empty list
        if (!_isDisposed && ref.mounted) {
          state = state.copyWith(
            suggestedVideos: [],
            isLoadingSuggested: false,
          );
        }
      }
    } catch (e) {
      print('Error loading suggested videos: $e');
      if (!_isDisposed && ref.mounted) {
        state = state.copyWith(isLoadingSuggested: false);
      }
    }
  }

  void setOrientation(Orientation orientation) {
    state = state.copyWith(orientation: orientation);
  }

  void setVolume(double volume) {
    _player?.setVolume(volume * 100); // media_kit uses 0-100 scale
    state = state.copyWith(volume: volume);
  }

  void setControlsVisible(bool value) {
    state = state.copyWith(isControlsVisible: value);
  }

  void toggleDescriptionExpanded() {
    state = state.copyWith(isDescriptionExpanded: !state.isDescriptionExpanded);
  }

  void setPlaylistInfo(int? position, int? total) {
    state = state.copyWith(playlistPosition: position, playlistTotal: total);
  }

  Future<void> loadCaptions(String videoId) async {
    if (state.metadata == null || _isDisposed) return;

    try {
      final syncService = ref.read(syncServiceProvider.notifier);
      final cookiePath = await syncService.getActiveCookiePath();
      if (!ref.mounted || _isDisposed) return;

      final ytDlpService = ref.read(ytDlpServiceProvider);

      final url = 'https://www.youtube.com/watch?v=$videoId';

      // Fetch available captions
      final captions = await ytDlpService.getCaptions(
        url,
        cookiePath: cookiePath,
      );
      if (!ref.mounted || _isDisposed) return;

      print('[PlayerViewModel] Found ${captions.length} caption formats');

      // Update metadata with captions
      final updatedMetadata = VideoMetadata(
        videoId: state.metadata!.videoId,
        title: state.metadata!.title,
        uploader: state.metadata!.uploader,
        uploaderUrl: state.metadata!.uploaderUrl,
        uploadDate: state.metadata!.uploadDate,
        viewCount: state.metadata!.viewCount,
        averageRating: state.metadata!.averageRating,
        description: state.metadata!.description,
        duration: state.metadata!.duration,
        license: state.metadata!.license,
        categories: state.metadata!.categories,
        tags: state.metadata!.tags,
        availableFormats: state.metadata!.availableFormats,
        selectedFormat: state.metadata!.selectedFormat,
        rawData: state.metadata!.rawData,
      );

      if (!_isDisposed && ref.mounted) {
        state = state.copyWith(metadata: updatedMetadata);
      }
    } catch (e) {
      print('Error loading captions: $e');
      // Continue without captions if loading fails
    }
  }

  void selectCaption(String lang) {
    state = state.copyWith(selectedCaption: lang);
  }

  void disableCaptions() {
    state = state.copyWith(selectedCaption: null);
  }

  void setSleepTimer(int? minutes) {
    _sleepTimer?.cancel();

    if (minutes == null) {
      state = state.copyWith(sleepTimerMinutes: null);
      return;
    }

    state = state.copyWith(sleepTimerMinutes: minutes);

    _sleepTimer = Timer(Duration(minutes: minutes), () {
      if (_player != null && _player!.state.playing) {
        _player!.pause();
        state = state.copyWith(isPlaying: false, sleepTimerMinutes: null);
      }
    });
  }

  void _setupPlayerListeners() {
    if (_player == null) return;

    _player!.stream.error.listen((error) {
      if (!_isDisposed && ref.mounted) {
        print('PLAYER ERROR: $error');
        state = state.copyWith(errorMessage: 'Playback error: $error');
      }
    });

    _player!.stream.position.listen((position) {
      if (!_isDisposed && ref.mounted) {
        state = state.copyWith(position: position);
      }
    });

    _player!.stream.duration.listen((duration) {
      if (!_isDisposed && ref.mounted) {
        state = state.copyWith(duration: duration);
      }
    });

    _player!.stream.playing.listen((playing) {
      if (!_isDisposed && ref.mounted) {
        state = state.copyWith(isPlaying: playing);
      }
    });

    _player!.stream.buffering.listen((buffering) {
      if (!_isDisposed && ref.mounted) {
        state = state.copyWith(isBuffering: buffering);
        if (!buffering && !state.isFirstFrameReady) {
          state = state.copyWith(isFirstFrameReady: true);
        }
      }
    });

    _player!.stream.completed.listen((completed) {
      if (completed) {
        if (_playlistQueue.isNotEmpty &&
            _currentPlaylistIndex < _playlistQueue.length - 1) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!_isDisposed) {
              playNextVideo();
            }
          });
        }
      }
    });
  }

  void stop() {
    print('[PlayerViewModel] Stop called');
    _currentExtractionId++; // Invalidate any ongoing metadata extraction
    try {
      if (!_isDisposed && _player != null) {
        _player?.stop();
      }
    } catch (e) {
      print('[PlayerViewModel] Error stopping player: $e');
    }
    state = PlayerState(
      isPlaying: false,
      position: Duration.zero,
      duration: Duration.zero,
      isControlsVisible: true,
    );
  }

  Player? get player => _player;
}

class AudioTrack {
  final String id;
  final String language;
  final String label;

  AudioTrack({required this.id, required this.language, required this.label});

  @override
  String toString() => label;
}

class PlayerState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isControlsVisible;
  final double playbackSpeed;
  final String? errorMessage;
  final List<Comment> comments;
  final List<Video> suggestedVideos;
  final bool isLoadingComments;
  final bool isLoadingSuggested;
  final Orientation orientation;
  final bool isDescriptionExpanded;
  final int? playlistPosition;
  final int? playlistTotal;
  final VideoMetadata? metadata;
  final List<QualityFormat> availableQualities;
  final String selectedQuality;
  final bool isLoadingMetadata;
  final bool isBuffering;
  final bool isFirstFrameReady;
  final double volume;
  final String? selectedCaption;
  final int? sleepTimerMinutes;
  final List<Video> playlistVideos;
  final int playlistIndex;
  final bool isChangingQuality;
  final bool isAudioOnly;
  final List<AudioTrack> availableAudioTracks;
  final String? selectedAudioTrack;

  PlayerState({
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.isControlsVisible,
    this.playbackSpeed = 1.0,
    this.errorMessage,
    this.comments = const [],
    this.suggestedVideos = const [],
    this.isLoadingComments = false,
    this.isLoadingSuggested = false,
    this.orientation = Orientation.portrait,
    this.isDescriptionExpanded = false,
    this.playlistPosition,
    this.playlistTotal,
    this.metadata,
    this.availableQualities = const [],
    this.selectedQuality = 'auto',
    this.isLoadingMetadata = false,
    this.isBuffering = true,
    this.isFirstFrameReady = true,
    this.volume = 1.0,
    this.selectedCaption,
    this.sleepTimerMinutes,
    this.playlistVideos = const [],
    this.playlistIndex = -1,
    this.isChangingQuality = false,
    this.isAudioOnly = false,
    this.availableAudioTracks = const [],
    this.selectedAudioTrack,
  });

  PlayerState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isControlsVisible,
    double? playbackSpeed,
    String? errorMessage,
    List<Comment>? comments,
    List<Video>? suggestedVideos,
    bool? isLoadingComments,
    bool? isLoadingSuggested,
    Orientation? orientation,
    bool? isDescriptionExpanded,
    int? playlistPosition,
    int? playlistTotal,
    VideoMetadata? metadata,
    List<QualityFormat>? availableQualities,
    String? selectedQuality,
    bool? isLoadingMetadata,
    bool clearError = false,
    bool? isBuffering,
    bool? isFirstFrameReady,
    double? volume,
    String? selectedCaption,
    int? sleepTimerMinutes,
    List<Video>? playlistVideos,
    int? playlistIndex,
    bool? isChangingQuality,
    bool? isAudioOnly,
    List<AudioTrack>? availableAudioTracks,
    String? selectedAudioTrack,
  }) {
    return PlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isControlsVisible: isControlsVisible ?? this.isControlsVisible,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      comments: comments ?? this.comments,
      suggestedVideos: suggestedVideos ?? this.suggestedVideos,
      isLoadingComments: isLoadingComments ?? this.isLoadingComments,
      isLoadingSuggested: isLoadingSuggested ?? this.isLoadingSuggested,
      orientation: orientation ?? this.orientation,
      isDescriptionExpanded:
          isDescriptionExpanded ?? this.isDescriptionExpanded,
      playlistPosition: playlistPosition ?? this.playlistPosition,
      playlistTotal: playlistTotal ?? this.playlistTotal,
      metadata: metadata ?? this.metadata,
      availableQualities: availableQualities ?? this.availableQualities,
      selectedQuality: selectedQuality ?? this.selectedQuality,
      isLoadingMetadata: isLoadingMetadata ?? this.isLoadingMetadata,
      isBuffering: isBuffering ?? this.isBuffering,
      isFirstFrameReady: isFirstFrameReady ?? this.isFirstFrameReady,
      volume: volume ?? this.volume,
      selectedCaption: selectedCaption ?? this.selectedCaption,
      sleepTimerMinutes: sleepTimerMinutes ?? this.sleepTimerMinutes,
      playlistVideos: playlistVideos ?? this.playlistVideos,
      playlistIndex: playlistIndex ?? this.playlistIndex,
      isChangingQuality: isChangingQuality ?? this.isChangingQuality,
      isAudioOnly: isAudioOnly ?? this.isAudioOnly,
      availableAudioTracks: availableAudioTracks ?? this.availableAudioTracks,
      selectedAudioTrack: selectedAudioTrack ?? this.selectedAudioTrack,
    );
  }
}
