import 'dart:convert';

import 'package:curio/core/services/yt_dlp/base.dart';

class YtDlpDownloadPlatformService extends YtDlpBasePlatformService {
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
    final result = await invokeMethod<String>('startEnhancedDownload', {
      'url': url,
      'format_ids': formatIds,
      'output_dir': outputDir,
      'extract_audio': extractAudio,
      'audio_format': audioFormat,
      'audio_quality': audioQuality,
      'embed_metadata': embedMetadata,
      // FFmpeg processing options
      'convert_video': convertVideo,
      'target_format': targetFormat,
      'video_codec': videoCodec,
      'resolution': resolution,
      'optimize_mobile': optimizeMobile,
      'target_size_mb': targetSizeMb,
      'embed_subtitles': embedSubtitles,
      'subtitle_file': subtitleFile,
      'subtitle_language': subtitleLanguage,
    });

    if (result == null || result.isEmpty) {
      throw Exception('No response from enhanced download service');
    }

    // Parse JSON string response
    try {
      final resultMap = json.decode(result) as Map<String, dynamic>;

      if (resultMap['success'] == true) {
        return resultMap;
      } else {
        throw Exception(
          resultMap['message'] as String? ??
              resultMap['error'] as String? ??
              'Enhanced download failed',
        );
      }
    } catch (e) {
      throw Exception('Failed to parse enhanced download response: $e');
    }
  }

  Future<Map<String, dynamic>> cancelEnhancedDownload() async {
    final result = await invokeMethod<String>('cancelEnhancedDownload');
    if (result == null || result.isEmpty) {
      throw Exception('No response from enhanced cancel service');
    }

    // Parse JSON string response
    try {
      return json.decode(result) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to parse cancel response: $e');
    }
  }

  Future<String> startDownload(
    String url,
    Map<String, dynamic> config, {
    String? taskId,
  }) async {
    print(
      'YtDlpDownloadPlatformService.startDownload called with taskId: $taskId',
    );
    final resultTaskId = await invokeMethod<String>('startDownload', {
      'url': url,
      'config': config,
      'taskId': taskId,
    });

    if (resultTaskId == null || resultTaskId.isEmpty) {
      throw Exception('Failed to start download: No task ID returned');
    }

    return resultTaskId;
  }

  Future<Map<String, dynamic>?> getDownloadStatus(String taskId) async {
    final jsonString = await invokeMethod<String>('getDownloadStatus', {
      'taskId': taskId,
    });

    if (jsonString == null || jsonString.isEmpty || jsonString == '{}') {
      return null;
    }

    // In a real app with standardized responses, we'd use fromJson here
    return json.decode(jsonString) as Map<String, dynamic>;
  }

  Future<bool> cancelDownload(String taskId) async {
    final result = await invokeMethod<bool>('cancelDownload', {
      'taskId': taskId,
    });
    return result ?? false;
  }

  Future<bool> pauseDownload(String taskId) async {
    final result = await invokeMethod<bool>('pauseDownload', {
      'taskId': taskId,
    });
    return result ?? false;
  }

  Future<bool> resumeDownload(String taskId) async {
    final result = await invokeMethod<bool>('resumeDownload', {
      'taskId': taskId,
    });
    return result ?? false;
  }
}
