import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Represents paths to all binary executables extracted from assets.
class BinaryPaths {
  final String ffmpegPath;
  final String ffprobePath;
  final String quickjsPath;

  const BinaryPaths({
    required this.ffmpegPath,
    required this.ffprobePath,
    required this.quickjsPath,
  });

  /// Returns true if all binaries exist on the filesystem.
  bool get allExist =>
      File(ffmpegPath).existsSync() &&
      File(ffprobePath).existsSync() &&
      File(quickjsPath).existsSync();

  Map<String, String> toMap() => {
    'ffmpeg_path': ffmpegPath,
    'ffprobe_path': ffprobePath,
    'quickjs_path': quickjsPath,
  };

  @override
  String toString() =>
      'BinaryPaths(ffmpeg: $ffmpegPath, ffprobe: $ffprobePath, quickjs: $quickjsPath)';
}

/// Manages extraction and setup of native binaries (FFmpeg, QuickJS) from assets.
///
/// On Android, binaries cannot be executed directly from the compressed assets folder.
/// This utility copies them to the app's internal storage and makes them executable.
///
/// ## Usage
/// ```dart
/// final paths = await BinaryManager.ensureBinaries();
/// print('FFmpeg at: ${paths.ffmpegPath}');
/// ```
///
/// ## 2026 Critical Notes
/// - **Signature Decryption**: QuickJS is essential for YouTube's n-challenge scrambling
/// - **1080p+ Downloads**: FFmpeg is required to merge separate video/audio streams
class BinaryManager {
  static const String _ffmpegAssetDir = 'ffmpeg';
  static const String _quickjsAssetDir = 'quickjs';

  static BinaryPaths? _cachedPaths;

  /// Ensures all binaries are extracted and executable.
  ///
  /// Returns [BinaryPaths] containing paths to all extracted binaries.
  /// This method is idempotent - it won't re-extract if binaries already exist.
  static Future<BinaryPaths> ensureBinaries() async {
    // Return cached paths if already extracted and valid
    if (_cachedPaths != null && _cachedPaths!.allExist) {
      return _cachedPaths!;
    }

    final supportDir = await getApplicationSupportDirectory();
    if (Platform.isAndroid) {
      final filesDir = supportDir.path;
      final ffmpegPath = '$filesDir/ffmpeg';
      final ffprobePath = '$filesDir/ffprobe';
      final quickjsPath = '$filesDir/qjs';

      final existingPaths = BinaryPaths(
        ffmpegPath: ffmpegPath,
        ffprobePath: ffprobePath,
        quickjsPath: quickjsPath,
      );

      if (existingPaths.allExist) {
        _cachedPaths = existingPaths;
        return existingPaths;
      }
    }
    final binDir = Directory('${supportDir.path}/bin');

    // Create bin directory if it doesn't exist
    if (!binDir.existsSync()) {
      await binDir.create(recursive: true);
    }

    // Detect current device architecture
    final arch = await _getCurrentArchitecture();
    print('BinaryManager: Detected architecture: $arch');

    // Extract FFmpeg binaries
    final ffmpegPath = await _extractBinary(
      assetPath: '$_ffmpegAssetDir/$arch/ffmpeg',
      targetDir: binDir.path,
      targetName: 'ffmpeg',
    );

    final ffprobePath = await _extractBinary(
      assetPath: '$_ffmpegAssetDir/$arch/ffprobe',
      targetDir: binDir.path,
      targetName: 'ffprobe',
    );

    // Extract QuickJS binary
    final quickjsPath = await _extractBinary(
      assetPath: '$_quickjsAssetDir/$arch/qjs',
      targetDir: binDir.path,
      targetName: 'qjs',
    );

    _cachedPaths = BinaryPaths(
      ffmpegPath: ffmpegPath,
      ffprobePath: ffprobePath,
      quickjsPath: quickjsPath,
    );

    print('BinaryManager: All binaries extracted successfully');
    print('BinaryManager: $_cachedPaths');

    return _cachedPaths!;
  }

  /// Extracts a single binary from assets to target directory.
  ///
  /// Returns the absolute path to the extracted binary.
  static Future<String> _extractBinary({
    required String assetPath,
    required String targetDir,
    required String targetName,
  }) async {
    final targetPath = '$targetDir/$targetName';
    final targetFile = File(targetPath);

    // Skip extraction if file already exists and is executable
    if (targetFile.existsSync()) {
      print('BinaryManager: $targetName already exists at: $targetPath');
      // Ensure it's still executable (might have been reset)
      await _makeExecutable(targetPath);
      return targetPath;
    }

    try {
      // Load binary from Flutter assets
      print('BinaryManager: Extracting $targetName from assets/$assetPath');
      final byteData = await rootBundle.load('assets/$assetPath');

      // Write to target location
      await targetFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      // Make the binary executable (chmod 755)
      await _makeExecutable(targetPath);

      print('BinaryManager: Extracted $targetName to: $targetPath');
      return targetPath;
    } catch (e) {
      print('BinaryManager: Failed to extract $targetName: $e');
      rethrow;
    }
  }

  /// Makes a file executable using chmod 755.
  ///
  /// On Android, this is required before the binary can be run via Process.run().
  static Future<void> _makeExecutable(String path) async {
    if (!Platform.isAndroid && !Platform.isLinux && !Platform.isMacOS) {
      // chmod not available on Windows/other platforms
      return;
    }

    final result = await Process.run('chmod', ['755', path]);

    if (result.exitCode != 0) {
      print('BinaryManager: chmod failed for $path: ${result.stderr}');
      throw Exception('Failed to make $path executable: ${result.stderr}');
    }

    print('BinaryManager: Made executable: $path');
  }

  /// Detects the current device's CPU architecture.
  ///
  /// Maps to one of: arm64-v8a, armeabi-v7a, x86, x86_64
  static Future<String> _getCurrentArchitecture() async {
    if (Platform.isAndroid) {
      // On Android, check the ABI
      try {
        final result = await Process.run('getprop', ['ro.product.cpu.abi']);
        final abi = result.stdout.toString().trim();

        switch (abi) {
          case 'arm64-v8a':
            return 'arm64-v8a';
          case 'armeabi-v7a':
          case 'armeabi':
            return 'armeabi-v7a';
          case 'x86':
            return 'x86';
          case 'x86_64':
            return 'x86_64';
          default:
            // Fallback to arm64-v8a for modern devices
            return 'arm64-v8a';
        }
      } catch (e) {
        print('BinaryManager: Failed to detect ABI, defaulting to arm64-v8a');
        return 'arm64-v8a';
      }
    }

    // Fallback for non-Android platforms (development/testing)
    return 'arm64-v8a';
  }

  /// Gets the FFmpeg binary path, extracting if necessary.
  static Future<String> getFFmpegPath() async {
    final paths = await ensureBinaries();
    return paths.ffmpegPath;
  }

  /// Gets the FFprobe binary path, extracting if necessary.
  static Future<String> getFFprobePath() async {
    final paths = await ensureBinaries();
    return paths.ffprobePath;
  }

  /// Gets the QuickJS binary path, extracting if necessary.
  static Future<String> getQuickJSPath() async {
    final paths = await ensureBinaries();
    return paths.quickjsPath;
  }

  /// Clears cached paths, forcing re-extraction on next call.
  ///
  /// Useful for debugging or after app updates that include new binaries.
  static void clearCache() {
    _cachedPaths = null;
  }

  /// Verifies that all binaries are valid and executable.
  ///
  /// Returns a map with verification results for each binary.
  static Future<Map<String, bool>> verifyBinaries() async {
    final paths = await ensureBinaries();

    return {
      'ffmpeg': await _verifyBinary(paths.ffmpegPath, ['-version']),
      'ffprobe': await _verifyBinary(paths.ffprobePath, ['-version']),
      'quickjs': await _verifyBinary(paths.quickjsPath, ['--help']),
    };
  }

  static Future<bool> _verifyBinary(String path, List<String> testArgs) async {
    try {
      final result = await Process.run(path, testArgs);
      return result.exitCode == 0;
    } catch (e) {
      print('BinaryManager: Verification failed for $path: $e');
      return false;
    }
  }
}
