import 'dart:convert';

import 'package:curio/core/services/system/binary_manager.dart';
import 'package:curio/core/services/yt_dlp/base.dart';

/// High-resolution video download service using yt-dlp with FFmpeg and QuickJS.
///
/// This service integrates the Dart [BinaryManager] with the Python yt_dlp_manager
/// via Chaquopy to enable downloads of 1080p+ videos that require stream merging.
///
/// ## Usage
/// ```dart
/// final service = HighResDownloadService();
/// final result = await service.downloadVideo(
///   url: 'https://youtube.com/watch?v=...',
///   outputDir: '/storage/emulated/0/Download/Curio',
/// );
/// if (result.success) {
///   print('Downloaded to: ${result.filePath}');
/// }
/// ```
class HighResDownloadService extends YtDlpBasePlatformService {
  BinaryPaths? _binaryPaths;

  /// Ensures all binaries (FFmpeg, QuickJS) are extracted and ready.
  ///
  /// This should be called early in app initialization.
  @override
  Future<void> initialize({String channelName = 'Stable'}) async {
    _binaryPaths = await BinaryManager.ensureBinaries();
    print('HighResDownloadService: Binaries ready at $_binaryPaths');
  }

  /// Downloads a video in the highest available resolution (1080p+).
  ///
  /// This method:
  /// 1. Ensures binary dependencies are extracted
  /// 2. Calls the Python yt_dlp_manager via Chaquopy
  /// 3. Returns the download result
  ///
  /// Parameters:
  /// - [url]: The video URL to download
  /// - [outputDir]: Directory to save the downloaded file
  /// - [cookies]: Optional authentication cookies
  Future<HighResDownloadResult> downloadVideo({
    required String url,
    required String outputDir,
    String? cookies,
  }) async {
    // Ensure binaries are ready
    if (_binaryPaths == null) {
      await initialize();
    }
    final paths = _binaryPaths!;

    try {
      // Call Python yt_dlp_manager.download_high_res via Chaquopy bridge
      // This invokes the Python function with the binary paths
      final response = await invokeMethod<String>('downloadHighRes', {
        'url': url,
        'ffmpeg_path': paths.ffmpegPath,
        'quickjs_path': paths.quickjsPath,
        'output_dir': outputDir,
        if (cookies != null && cookies.isNotEmpty) 'cookies': cookies,
      });

      if (response == null || response.isEmpty) {
        return HighResDownloadResult.error('No response from download service');
      }

      final result = json.decode(response) as Map<String, dynamic>;

      if (result['success'] == true) {
        return HighResDownloadResult(
          success: true,
          filePath: result['file_path'] as String?,
          title: result['title'] as String?,
          resolution: result['resolution'] as String?,
        );
      } else {
        return HighResDownloadResult.error(
          result['error'] as String? ?? 'Unknown error',
        );
      }
    } catch (e) {
      print('HighResDownloadService: Error downloading $url: $e');
      return HighResDownloadResult.error(e.toString());
    }
  }

  /// Gets video information without downloading.
  ///
  /// Useful for showing available formats before download.
  Future<Map<String, dynamic>> getVideoInfo({
    required String url,
    String? cookies,
  }) async {
    if (_binaryPaths == null) {
      await initialize();
    }
    final paths = _binaryPaths!;

    try {
      final response = await invokeMethod<String>('getHighResVideoInfo', {
        'url': url,
        'ffmpeg_path': paths.ffmpegPath,
        'quickjs_path': paths.quickjsPath,
        if (cookies != null && cookies.isNotEmpty) 'cookies': cookies,
      });

      if (response == null || response.isEmpty) {
        return {'success': false, 'error': 'No response'};
      }

      return json.decode(response) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Verifies that all required binaries are working correctly.
  Future<Map<String, bool>> verifyBinaries() async {
    return await BinaryManager.verifyBinaries();
  }
}

/// Result of a high-resolution video download.
class HighResDownloadResult {
  final bool success;
  final String? filePath;
  final String? title;
  final String? resolution;
  final String? error;

  const HighResDownloadResult({
    required this.success,
    this.filePath,
    this.title,
    this.resolution,
    this.error,
  });

  factory HighResDownloadResult.error(String message) {
    return HighResDownloadResult(success: false, error: message);
  }

  @override
  String toString() {
    if (success) {
      return 'HighResDownloadResult(success, $resolution, $filePath)';
    }
    return 'HighResDownloadResult(failed: $error)';
  }
}

// ============================================================================
// INTEGRATION EXAMPLE
// ============================================================================
//
// The following shows how to integrate high-res downloads in your Flutter app:
//
// 1. INITIALIZATION (in app startup or download screen init):
//
//    final downloadService = HighResDownloadService();
//    await downloadService.initialize();
//
// 2. DOWNLOAD A VIDEO:
//
//    final result = await downloadService.downloadVideo(
//      url: 'https://youtube.com/watch?v=dQw4w9WgXcQ',
//      outputDir: '/storage/emulated/0/Download/Curio',
//    );
//
//    if (result.success) {
//      ScaffoldMessenger.of(context).showSnackBar(
//        SnackBar(content: Text('Downloaded: ${result.title}')),
//      );
//    } else {
//      ScaffoldMessenger.of(context).showSnackBar(
//        SnackBar(content: Text('Error: ${result.error}')),
//      );
//    }
//
// 3. KOTLIN HANDLER (add to YtDlpHandler.kt):
//
//    "downloadHighRes" -> downloadHighRes(call, result)
//
//    private fun downloadHighRes(call: MethodCall, result: MethodChannel.Result) {
//        val url = call.argument<String>("url") ?: return result.error(...)
//        val ffmpegPath = call.argument<String>("ffmpeg_path")
//        val quickjsPath = call.argument<String>("quickjs_path")
//        val outputDir = call.argument<String>("output_dir")
//        val cookies = call.argument<String>("cookies")
//
//        backgroundScope.launch {
//            val response = runCatching {
//                ensurePythonStarted()
//                val py = Python.getInstance()
//                val module = py.getModule("yt_dlp_manager")
//                module.callAttr(
//                    "download_high_res",
//                    url, ffmpegPath, quickjsPath, outputDir, cookies
//                ).toString()
//            }.getOrElse { error -> errorJson(error) }
//
//            withContext(Dispatchers.Main) { result.success(response) }
//        }
//    }
