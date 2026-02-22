import 'dart:async';
import 'dart:io';
import 'package:curio/core/services/system/logger.dart';
import 'package:curio/core/services/yt_dlp/download_platform.dart';

class YtDlpDownloadService {
  final YtDlpDownloadPlatformService _platform = YtDlpDownloadPlatformService();
  static const _tag = 'YtDlpDownloadService';

  /// Enhanced download using direct yt-dlp integration with FFmpeg processing
  Future<Map<String, dynamic>> startEnhancedDownload({
    required String url,
    required List<String> formatIds,
    String outputDir = '/storage/emulated/0/Download/Curio',
    bool extractAudio = false,
    String audioFormat = 'mp3',
    String audioQuality = '192k',
    bool embedMetadata = true,
    // FFmpeg processing options
    bool convertVideo = false,
    String targetFormat = 'mp4',
    String videoCodec = 'libx264',
    String? resolution,
    bool optimizeMobile = false,
    int? targetSizeMb,
    bool embedSubtitles = false,
    String? subtitleFile,
    String subtitleLanguage = 'eng',
  }) async {
    LogService.d('Starting enhanced download for $url', _tag);

    try {
      final result = await _platform.startEnhancedDownload(
        url: url,
        formatIds: formatIds,
        outputDir: outputDir,
        extractAudio: extractAudio,
        audioFormat: audioFormat,
        audioQuality: audioQuality,
        embedMetadata: embedMetadata,
        // FFmpeg processing options
        convertVideo: convertVideo,
        targetFormat: targetFormat,
        videoCodec: videoCodec,
        resolution: resolution,
        optimizeMobile: optimizeMobile,
        targetSizeMb: targetSizeMb,
        embedSubtitles: embedSubtitles,
        subtitleFile: subtitleFile,
        subtitleLanguage: subtitleLanguage,
      );

      LogService.d('Enhanced download completed successfully', _tag);
      return result;
    } catch (e) {
      LogService.e('Enhanced download failed: $e', _tag);
      rethrow;
    }
  }

  /// Cancel enhanced download
  Future<Map<String, dynamic>> cancelEnhancedDownload() async {
    LogService.d('Cancelling enhanced download', _tag);

    try {
      final result = await _platform.cancelEnhancedDownload();
      LogService.d('Enhanced download cancelled successfully', _tag);
      return result;
    } catch (e) {
      LogService.e('Enhanced download cancel failed: $e', _tag);
      rethrow;
    }
  }

  /// Start download via Native yt-dlp
  Future<String> startDownload(
    String url, {
    required String outputPath,
    String? formatId,
    String? cookiePath,
    String? cookies,
    String? taskId,
  }) async {
    LogService.d('YtDlpDownloadService.startDownload requested', _tag);
    String? cookieString = cookies;
    if (cookieString == null && cookiePath != null) {
      try {
        cookieString = await File(cookiePath).readAsString();
      } catch (e) {
        LogService.w('Could not read cookies from $cookiePath: $e', _tag);
      }
    }

    final config = {
      'outputDir': outputPath,
      'outputTemplate': '%(title)s.%(ext)s',
      'format': formatId ?? 'best',
      'cookies': cookieString,
    };

    LogService.d('Starting download for $url via Native yt-dlp', _tag);
    return _platform.startDownload(url, config, taskId: taskId);
  }

  Future<Map<String, dynamic>?> getDownloadStatus(String taskId) {
    return _platform.getDownloadStatus(taskId);
  }

  Future<bool> cancelDownload(String taskId) {
    return _platform.cancelDownload(taskId);
  }

  Future<bool> pauseDownload(String taskId) {
    return _platform.pauseDownload(taskId);
  }

  Future<bool> resumeDownload(String taskId) {
    return _platform.resumeDownload(taskId);
  }
}
