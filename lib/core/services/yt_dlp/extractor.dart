import 'dart:async';
import 'dart:io';
import 'package:curio/core/services/system/logger.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

/// Service for extracting metadata from video files (Native mode)
class MetadataExtractor {
  // Native mode - no native channel needed

  /// Extract thumbnail from video file (Native mode - returns null)
  /// In Native mode, thumbnails are handled by yt-dlp during download
  static Future<String?> extractThumbnail(String videoPath) async {
    LogService.w(
      'Thumbnail extraction not available in Native mode',
      'MetadataExtractor',
    );
    return null;
  }

  /// Extract duration from video file (Native mode - returns null)
  /// In Native mode, duration is handled by yt-dlp during download
  static Future<Duration?> extractDuration(String videoPath) async {
    LogService.w(
      'Duration extraction not available in Native mode',
      'MetadataExtractor',
    );
    return null;
  }

  /// Extract metadata from video file (Native mode - returns null)
  /// In Native mode, metadata is handled by yt-dlp during download
  static Future<Map<String, dynamic>?> extractMetadata(String videoPath) async {
    LogService.w(
      'Metadata extraction not available in Native mode',
      'MetadataExtractor',
    );
    return null;
  }

  /// Extract both thumbnail and duration efficiently (Native mode - returns null)
  /// In Native mode, these are handled by yt-dlp during download
  static Future<Map<String, String?>?> extractThumbnailAndDuration(
    String videoPath, {
    String? thumbnailOutputPath,
  }) async {
    LogService.w(
      'Combined metadata extraction not available in Native mode',
      'MetadataExtractor',
    );
    return null;
  }

  /// Check if FFMPEG is available (Native mode - always returns false)
  static Future<bool> isFFmpegAvailable() async {
    LogService.d('FFMPEG not available in Native mode', 'MetadataExtractor');
    return false;
  }
}
