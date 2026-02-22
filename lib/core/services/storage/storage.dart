import 'dart:async';
import 'dart:io';
import 'package:curio/core/services/storage/robust.dart';
import 'package:curio/core/services/storage/validated.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

part 'storage.g.dart';

/* -------------------------------------------------
   Riverpod provider – enhanced with robust storage
   ------------------------------------------------- */
@Riverpod(keepAlive: true)
RobustStorageService robustStorageService(Ref ref) {
  debugPrint('RobustStorageService: Initializing enhanced storage service');
  return RobustStorageService();
}

@Riverpod(keepAlive: true)
StorageService storageService(Ref ref) {
  debugPrint('StorageService provider: Using robust validated storage');
  final robustStorage = ref.read(robustStorageServiceProvider);
  return StorageService._(ValidatedStorageService(robustStorage));
}

/* -------------------------------------------------
   Enhanced Storage Service with validation and robust error handling
   ------------------------------------------------- */
class StorageService {
  final ValidatedStorageService _validatedStorage;
  StorageService._(this._validatedStorage);

  /* safe fallback for testing */
  factory StorageService.empty() {
    final robustStorage = RobustStorageService();
    return StorageService._(ValidatedStorageService(robustStorage));
  }

  /* ---------- Change Notification ---------- */
  Stream<String> get changes => _validatedStorage.changes;

  /* ---------- keys ---------- */
  static const String keySetupCompleted = 'setup_completed';
  static const String keyLanguage = 'language';
  static const String keyPerformanceMode = 'performance_mode';
  static const String keyLibraryTabs = 'library_tabs';
  static const String keyUseMediaStore = 'use_media_store';
  static const String keySyncFrequency = 'sync_frequency';
  static const String keyStorageLocation = 'storage_location';
  static const String keyProxy = 'proxy';
  static const String keyUserAgent = 'user_agent';
  static const String keyFrostedIntensity = 'frosted_intensity';
  static const String keyFontFamily = 'font_family';
  static const String keyPlaylistOrder = 'playlist_order';
  static const String keyYtDlpChannel = 'ytdlp_channel';
  static const String keyStreamQuality = 'stream_quality';
  static const String keyDownloadQuality = 'download_quality';
  static const String keyDownloadPath = 'download_path';
  static const String keyHideLikedPlaylist = 'hide_liked_playlist';
  static const String keyHideWatchLaterPlaylist = 'hide_watch_later_playlist';
  static const String keyGeminiApiKey = 'gemini_api_key';
  static const String keyGeminiModel = 'gemini_model';
  static const String keyPerplexityApiKey = 'perplexity_api_key';
  static const String keyPerplexityModel = 'perplexity_model';
  static const String keySelectedAIProvider = 'selected_ai_provider';
  static const String keyPipEnabled = 'pip_enabled';
  static const String keyAudioOnlyMode = 'audio_only_mode';
  static const String keyThemeMode = 'theme_mode';
  static const String keyUseDynamicColor = 'use_dynamic_color';
  static const String keySeedColor = 'seed_color';
  static const String keyPaletteStyle = 'palette_style';
  static const String keyYtDlpPoToken = 'ytdlp_po_token';

  /* ---------- getters / setters ---------- */
  bool get isSetupCompleted => _validatedStorage.isSetupCompleted;
  Future<void> setSetupCompleted(bool v) =>
      _validatedStorage.setSetupCompleted(v);

  String get language => _validatedStorage.language;
  Future<void> setLanguage(String v) => _validatedStorage.setLanguage(v);

  String get performanceMode => _validatedStorage.performanceMode;
  Future<void> setPerformanceMode(String v) =>
      _validatedStorage.setPerformanceMode(v);

  int get libraryTabs => _validatedStorage.libraryTabs;
  Future<void> setLibraryTabs(int v) => _validatedStorage.setLibraryTabs(v);

  bool get useMediaStore => _validatedStorage.useMediaStore;
  Future<void> setUseMediaStore(bool v) =>
      _validatedStorage.setUseMediaStore(v);

  String get syncFrequency => _validatedStorage.syncFrequency;
  Future<void> setSyncFrequency(String v) =>
      _validatedStorage.setSyncFrequency(v);

  String? get storageLocation => _validatedStorage.storageLocation;
  Future<void> setStorageLocation(String? v) =>
      _validatedStorage.setStorageLocation(v);

  String? get proxy => _validatedStorage.proxy;
  Future<void> setProxy(String? v) => _validatedStorage.setProxy(v);

  String? get userAgent => _validatedStorage.userAgent;
  Future<void> setUserAgent(String? v) => _validatedStorage.setUserAgent(v);

  double get frostedIntensity => _validatedStorage.frostedIntensity;
  Future<void> setFrostedIntensity(double v) =>
      _validatedStorage.setFrostedIntensity(v);

  String get fontFamily => _validatedStorage.fontFamily;
  Future<void> setFontFamily(String v) => _validatedStorage.setFontFamily(v);

  List<String> get playlistOrder => _validatedStorage.playlistOrder;
  Future<void> setPlaylistOrder(List<String> v) =>
      _validatedStorage.setPlaylistOrder(v);

  String get ytdlpChannel => _validatedStorage.ytdlpChannel;
  Future<void> setYtDlpChannel(String v) =>
      _validatedStorage.setYtDlpChannel(v);

  String get streamQuality => _validatedStorage.streamQuality;
  Future<void> setStreamQuality(String v) =>
      _validatedStorage.setStreamQuality(v);

  String get downloadQuality => _validatedStorage.downloadQuality;
  Future<void> setDownloadQuality(String v) =>
      _validatedStorage.setDownloadQuality(v);

  String get downloadPath => _validatedStorage.downloadPath;

  Future<void> setDownloadPath(String path) async {
    await _validatedStorage.setDownloadPath(path);
  }

  /// Get the download directory - uses user-set path or defaults to Download/Curio
  Future<Directory> getDownloadDirectory() async {
    // Check if user has set a custom download path
    final customPath = downloadPath;
    if (customPath.isNotEmpty) {
      final customDir = Directory(customPath);
      if (await customDir.exists()) {
        // Create Curio subdirectory in custom path
        final curioDir = Directory(p.join(customPath, 'Curio'));
        if (!await curioDir.exists()) {
          await curioDir.create(recursive: true);
        }
        return curioDir;
      }
    }

    // Default: Use device's Download directory
    try {
      if (Platform.isAndroid) {
        // Force standard path on Android to match Native code and User expectation
        // User asked for "Downloads" but standard is "Download". We use the standard.
        final standardDir = Directory('/storage/emulated/0/Download/Curio');
        if (!await standardDir.exists()) {
          await standardDir.create(recursive: true);
        }
        return standardDir;
      }

      // Try to get the Downloads directory first
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final curioDir = Directory(p.join(downloadsDir.path, 'Curio'));
        if (!await curioDir.exists()) {
          await curioDir.create(recursive: true);
        }
        return curioDir;
      }
    } catch (e) {
      // Fallback to external storage if Downloads directory is not accessible
    }

    // Final fallback: Use app's external files directory
    final externalDir = await getExternalStorageDirectory();
    if (externalDir != null) {
      final curioDir = Directory(p.join(externalDir.path, 'Curio'));
      if (!await curioDir.exists()) {
        await curioDir.create(recursive: true);
      }
      return curioDir;
    }

    // Last resort: Use app documents directory
    final documentsDir = await getApplicationDocumentsDirectory();
    final curioDir = Directory(p.join(documentsDir.path, 'Curio'));
    if (!await curioDir.exists()) {
      await curioDir.create(recursive: true);
    }
    return curioDir;
  }

  bool get hideLikedPlaylist => _validatedStorage.hideLikedPlaylist;
  Future<void> setHideLikedPlaylist(bool v) =>
      _validatedStorage.setHideLikedPlaylist(v);

  bool get hideWatchLaterPlaylist => _validatedStorage.hideWatchLaterPlaylist;
  Future<void> setHideWatchLaterPlaylist(bool v) =>
      _validatedStorage.setHideWatchLaterPlaylist(v);

  String? get geminiApiKey => _validatedStorage.geminiApiKey;
  Future<void> setGeminiApiKey(String? v) =>
      _validatedStorage.setGeminiApiKey(v);

  String get geminiModel => _validatedStorage.geminiModel;
  Future<void> setGeminiModel(String v) => _validatedStorage.setGeminiModel(v);

  String? get perplexityApiKey => _validatedStorage.perplexityApiKey;
  Future<void> setPerplexityApiKey(String? v) =>
      _validatedStorage.setPerplexityApiKey(v);

  String get perplexityModel => _validatedStorage.perplexityModel;
  Future<void> setPerplexityModel(String v) =>
      _validatedStorage.setPerplexityModel(v);

  String get selectedAIProvider => _validatedStorage.selectedAIProvider;
  Future<void> setSelectedAIProvider(String v) =>
      _validatedStorage.setSelectedAIProvider(v);

  bool get useDynamicColor => _validatedStorage.useDynamicColor;
  Future<void> setUseDynamicColor(bool v) =>
      _validatedStorage.setUseDynamicColor(v);

  int get seedColor => _validatedStorage.seedColor;
  Future<void> setSeedColor(int v) => _validatedStorage.setSeedColor(v);

  String get paletteStyle => _validatedStorage.paletteStyle;
  Future<bool> setPaletteStyle(String v) =>
      _validatedStorage.setPaletteStyle(v);

  bool get pipEnabled => _validatedStorage.pipEnabled;
  Future<void> setPipEnabled(bool v) => _validatedStorage.setPipEnabled(v);

  bool get audioOnlyMode => _validatedStorage.audioOnlyMode;
  Future<void> setAudioOnlyMode(bool v) =>
      _validatedStorage.setAudioOnlyMode(v);

  String getThemeMode() => _validatedStorage.themeMode;
  Future<void> setThemeMode(String v) => _validatedStorage.setThemeMode(v);

  String? get ytdlpPoToken =>
      _validatedStorage.storage.getStringSync(keyYtDlpPoToken);
  Future<void> setYtdlpPoToken(String? v) async {
    if (v == null || v.isEmpty) {
      await _validatedStorage.storage.remove(keyYtDlpPoToken);
      return;
    }
    await _validatedStorage.storage.setString(keyYtDlpPoToken, v);
  }

  /* ---------- Advanced Methods ---------- */

  /// Validate all settings and reset invalid ones to defaults
  Future<void> validateAllSettings() => _validatedStorage.validateAllSettings();

  /// Export all settings as a map
  Future<Map<String, dynamic>> exportSettings() =>
      _validatedStorage.exportSettings();

  /// Import settings from a map with validation
  Future<bool> importSettings(Map<String, dynamic> settings) =>
      _validatedStorage.importSettings(settings);

  /// Reset all settings to their default values
  Future<void> resetToDefaults() => _validatedStorage.resetToDefaults();

  /// Get validation report for all settings
  Future<Map<String, dynamic>> getValidationReport() =>
      _validatedStorage.getValidationReport();

  /// Optimize storage cache for better performance
  Future<void> optimizeCache() => _validatedStorage.storage.optimizeCache();

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() =>
      _validatedStorage.storage.getPerformanceStats();

  /// Dispose resources
  void dispose() => _validatedStorage.dispose();
}
