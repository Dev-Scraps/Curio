import 'package:curio/core/services/system/logger.dart';
import 'package:curio/core/services/yt_dlp/download_service.dart';
import 'package:curio/core/services/yt_dlp/format.dart';
import 'package:curio/core/services/yt_dlp/metadata_platform.dart';
import 'package:curio/core/services/yt_dlp/metadata_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ytdlp.g.dart';

@Riverpod(keepAlive: true)
YtDlpService ytDlpService(Ref ref) {
  return YtDlpService();
}

class YtDlpService {
  final YtDlpMetadataPlatformService _platform = YtDlpMetadataPlatformService();
  final YtDlpMetadataService _metadata = YtDlpMetadataService();
  late final YtDlpFormatService _format;
  final YtDlpDownloadService _download = YtDlpDownloadService();

  static const _tag = 'YtDlpService';

  YtDlpService() {
    _format = YtDlpFormatService(_metadata);
  }

  Future<void> initialize({String channel = 'Stable'}) async {
    await _platform.initialize(channelName: channel);
    LogService.d(
      'YtDlpService initialized with Chaquopy Python bridge ($channel channel)',
      _tag,
    );
  }

  // --- Version ---
  Future<String> getVersion() async {
    return _platform.getVersion();
  }

  // --- Metadata (Delegated) ---
  Future<Map<String, dynamic>> fetchMetadata(
    String url, {
    String? cookiePath,
    String? cookies,
    bool useCache = true,
    bool flat = false,
    List<String>? fields,
  }) => _metadata.fetchMetadata(
    url,
    cookiePath: cookiePath,
    cookies: cookies,
    useCache: useCache,
    flat: flat,
    fields: fields,
  );

  Future<Map<String, dynamic>> fetchBasicMetadata(String url) =>
      _metadata.fetchBasicMetadata(url);

  Future<void> setPoToken(String? token) => _platform.setPoToken(token);

  Future<Map<String, dynamic>> getEnhancedVideoInfo(String url) =>
      _metadata.getEnhancedVideoInfo(url);

  Future<List<dynamic>> getCaptions(
    String url, {
    String? cookiePath,
    String? cookies,
  }) => _metadata.getCaptions(url, cookiePath: cookiePath, cookies: cookies);

  Future<List<Map<String, dynamic>>> getUserPlaylists({String? cookies}) =>
      _metadata.getUserPlaylists(cookies: cookies);

  Future<List<dynamic>> getAudioTracks(String url) =>
      _metadata.getAudioTracks(url);

  // --- Formats (Delegated) ---
  Future<String> getStreamUrl(
    String url, {
    String? cookiePath,
    String? cookies,
    String? formatId,
    String? qualitySetting,
  }) => _format.getStreamUrl(
    url,
    cookiePath: cookiePath,
    cookies: cookies,
    formatId: formatId,
    qualitySetting: qualitySetting,
  );

  Future<String> getAudioStreamUrl(
    String url, {
    String? cookiePath,
    String? cookies,
    String? qualitySetting,
  }) => _format.getAudioStreamUrl(
    url,
    cookiePath: cookiePath,
    cookies: cookies,
    qualitySetting: qualitySetting,
  );

  /// Get both video and audio URLs for dual-source playback (high-res DASH formats)
  Future<
    ({
      String videoUrl,
      String? audioUrl,
      List<Map<String, String>> audioTracks,
      Map<String, String> headers,
    })
  >
  getVideoAndAudioUrls(
    String url, {
    String? cookiePath,
    String? cookies,
    String? formatId,
    String? qualitySetting,
  }) => _format.getVideoAndAudioUrls(
    url,
    cookiePath: cookiePath,
    cookies: cookies,
    formatId: formatId,
    qualitySetting: qualitySetting,
  );

  Future<List<Map<String, dynamic>>> getFormats(
    String url, {
    String? cookiePath,
    String? cookies,
  }) => _format.getFormats(url, cookiePath: cookiePath, cookies: cookies);

  Future<Map<String, dynamic>> getFormatsCategorized(
    String url, {
    String? cookies,
  }) => _format.getFormatsCategorized(url, cookies: cookies);

  // --- Download (Delegated) ---
  Future<Map<String, dynamic>> startEnhancedDownload({
    required String url,
    required List<String> formatIds,
    String outputDir = '/storage/emulated/0/Download/Curio',
    bool extractAudio = false,
    String audioFormat = 'mp3',
    bool embedMetadata = true,
  }) => _download.startEnhancedDownload(
    url: url,
    formatIds: formatIds,
    outputDir: outputDir,
    extractAudio: extractAudio,
    audioFormat: audioFormat,
    embedMetadata: embedMetadata,
  );

  Future<Map<String, dynamic>> cancelEnhancedDownload() =>
      _download.cancelEnhancedDownload();

  Future<String> startDownload(
    String url, {
    required String outputPath,
    String? formatId,
    String? cookiePath,
    String? cookies,
    String? taskId,
  }) => _download.startDownload(
    url,
    outputPath: outputPath,
    formatId: formatId,
    cookiePath: cookiePath,
    cookies: cookies,
    taskId: taskId,
  );

  Future<Map<String, dynamic>?> getDownloadStatus(String taskId) =>
      _download.getDownloadStatus(taskId);

  Future<bool> cancelDownload(String taskId) =>
      _download.cancelDownload(taskId);

  Future<bool> pauseDownload(String taskId) => _download.pauseDownload(taskId);

  Future<bool> resumeDownload(String taskId) =>
      _download.resumeDownload(taskId);

  // --- Cache Management ---
  void clearStreamUrlCache() => clearAllCaches();

  void clearAllCaches() {
    _metadata.clearCache();
    LogService.d('All caches cleared', _tag);
  }

  void dispose() {
    clearAllCaches();
  }
}
