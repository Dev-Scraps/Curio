import 'package:curio/core/services/storage/robust.dart';
import 'package:flutter/foundation.dart';

/// Validation rules for storage values
class ValidationRule<T> {
  final String name;
  final T? defaultValue;
  final bool Function(dynamic) validator;
  final String? errorMessage;

  const ValidationRule({
    required this.name,
    this.defaultValue,
    required this.validator,
    this.errorMessage,
  });
}

/// Type-safe validated storage service
class ValidatedStorageService {
  RobustStorageService get storage => _storage;
  final RobustStorageService _storage;
  final Map<String, ValidationRule> _rules = {};

  ValidatedStorageService(this._storage) {
    _setupValidationRules();
  }

  /// Setup validation rules for all settings
  void _setupValidationRules() {
    // Language validation
    _rules['language'] = ValidationRule<String>(
      name: 'language',
      defaultValue: 'en',
      validator: (value) {
        if (value == null) return true;
        if (value is! String) return false;
        const validLanguages = [
          'en',
          'es',
          'hi',
          'fr',
          'de',
          'zh',
          'ja',
          'ar',
          'pt',
        ];
        return validLanguages.contains(value);
      },
      errorMessage: 'Invalid language code',
    );

    // Theme validation
    _rules['theme_mode'] = ValidationRule<String>(
      name: 'theme_mode',
      defaultValue: 'system',
      validator: (value) {
        if (value == null) return true;
        if (value is! String) return false;
        const validThemes = ['system', 'light', 'dark'];
        return validThemes.contains(value);
      },
      errorMessage: 'Invalid theme mode',
    );

    _rules['use_dynamic_color'] = ValidationRule<bool>(
      name: 'use_dynamic_color',
      defaultValue: true,
      validator: (value) => value is bool,
      errorMessage: 'Use dynamic color must be a boolean',
    );

    _rules['seed_color'] = ValidationRule<int>(
      name: 'seed_color',
      defaultValue: 0xFF68A500,
      validator: (value) => value is int,
      errorMessage: 'Seed color must be an integer ARGB value',
    );

    _rules['palette_style'] = ValidationRule<String>(
      name: 'palette_style',
      defaultValue: 'neutral',
      validator: (value) {
        if (value == null) return true;
        if (value is! String) return false;
        const validStyles = ['neutral', 'tonalspot', 'vibrant', 'expressive'];
        return validStyles.contains(value);
      },
      errorMessage: 'Invalid palette style',
    );

    // Font family validation
    _rules['font_family'] = ValidationRule<String>(
      name: 'font_family',
      defaultValue: 'Baloo Bhai 2',
      validator: (value) {
        if (value == null) return true;
        if (value is! String) return false;
        const validFonts = [
          'Baloo Bhai 2',
          'Baloo 2',
          'Inter',
          'Roboto',
          'Poppins',
          'Montserrat',
          'Lato',
          'Open Sans',
          'Raleway',
          'Nunito',
          'Playfair Display',
          'Merriweather',
          'Oswald',
          'Ubuntu',
          'Bebas Neue',
          'Dancing Script',
          'Pacifico',
        ];
        return validFonts.contains(value);
      },
      errorMessage: 'Invalid font family',
    );

    // Quality validation
    _rules['stream_quality'] = ValidationRule<String>(
      name: 'stream_quality',
      defaultValue: '720p',
      validator: (value) {
        if (value == null) return true;
        if (value is! String) return false;
        const validQualities = [
          'auto',
          '144p',
          '240p',
          '360p',
          '480p',
          '720p',
          '1080p',
          '1440p',
          '2160p',
        ];
        return validQualities.contains(value);
      },
      errorMessage: 'Invalid stream quality',
    );

    _rules['download_quality'] = ValidationRule<String>(
      name: 'download_quality',
      defaultValue: 'Best',
      validator: (value) {
        if (value == null) return true;
        if (value is! String) return false;
        const validQualities = [
          'Best',
          'Worst',
          '360p',
          '480p',
          '720p',
          '1080p',
          '1440p',
          '2160p',
        ];
        return validQualities.contains(value);
      },
      errorMessage: 'Invalid download quality',
    );

    _rules['download_path'] = ValidationRule<String>(
      name: 'download_path',
      defaultValue: '',
      validator: (value) {
        if (value == null) return true;
        if (value is! String) return false;
        // Allow empty string (default) or valid path
        if (value.isEmpty) return true;
        // Basic path validation - check for invalid characters
        final invalidChars = ['<', '>', ':', '"', '|', '?', '*'];
        return !invalidChars.any((char) => value.contains(char));
      },
      errorMessage: 'Invalid download path',
    );

    // Boolean validations
    _rules['setup_completed'] = ValidationRule<bool>(
      name: 'setup_completed',
      defaultValue: false,
      validator: (value) => value is bool,
      errorMessage: 'Setup completed must be a boolean',
    );

    _rules['pip_enabled'] = ValidationRule<bool>(
      name: 'pip_enabled',
      defaultValue: true,
      validator: (value) => value is bool,
      errorMessage: 'PiP enabled must be a boolean',
    );

    _rules['audio_only_mode'] = ValidationRule<bool>(
      name: 'audio_only_mode',
      defaultValue: false,
      validator: (value) => value is bool,
      errorMessage: 'Audio only mode must be a boolean',
    );

    _rules['hide_liked_playlist'] = ValidationRule<bool>(
      name: 'hide_liked_playlist',
      defaultValue: false,
      validator: (value) => value is bool,
      errorMessage: 'Hide liked playlist must be a boolean',
    );

    _rules['hide_watch_later_playlist'] = ValidationRule<bool>(
      name: 'hide_watch_later_playlist',
      defaultValue: false,
      validator: (value) => value is bool,
      errorMessage: 'Hide watch later playlist must be a boolean',
    );

    // Numeric validations
    _rules['library_tabs'] = ValidationRule<int>(
      name: 'library_tabs',
      defaultValue: 3,
      validator: (value) {
        if (value is! int) return false;
        return value >= 1 && value <= 5;
      },
      errorMessage: 'Library tabs must be between 1 and 5',
    );

    _rules['gemini_model'] = ValidationRule<String>(
      name: 'gemini_model',
      defaultValue: 'gemini-2.0-flash',
      validator: (value) {
        if (value == null) return true;
        if (value is! String) return false;
        const validModels = [
          'gemini-2.0-flash',
          'gemini-2.0-flash-exp',
          'gemini-2.0-pro',
          'gemini-1.5-pro',
          'gemini-1.5-flash',
          'gemini-pro',
          'gemini-pro-vision',
        ];
        return validModels.contains(value);
      },
      errorMessage: 'Invalid Gemini model',
    );

    _rules['perplexity_model'] = ValidationRule<String>(
      name: 'perplexity_model',
      defaultValue: 'sonar',
      validator: (value) {
        if (value == null) return true;
        if (value is! String) return false;
        const validModels = ['sonar'];
        return validModels.contains(value);
      },
      errorMessage: 'Invalid Perplexity model',
    );

    _rules['selected_ai_provider'] = ValidationRule<String>(
      name: 'selected_ai_provider',
      defaultValue: 'gemini',
      validator: (value) {
        if (value == null) return true;
        if (value is! String) return false;
        const validProviders = ['gemini', 'perplexity'];
        return validProviders.contains(value);
      },
      errorMessage: 'Invalid AI provider',
    );
  }

  /// Validate a value against its rule
  bool _validateValue(String key, dynamic value) {
    final rule = _rules[key];
    if (rule == null) return true; // No rule means no validation

    // Cast the value to the expected type for the validator
    try {
      final isValid = rule.validator(value);
      if (!isValid) {
        debugPrint('Validation failed for $key: ${rule.errorMessage}');
      }
      return isValid;
    } catch (e) {
      debugPrint('Type validation error for $key: $e');
      return false;
    }
  }

  /// Get validated value or return default
  Future<T> getValidated<T>(String key) async {
    final rule = _rules[key] as ValidationRule<T>?;
    if (rule == null) {
      debugPrint('No validation rule found for key: $key');
      final rawValue = await _getRawValue<T>(key);
      return rawValue ?? rule?.defaultValue as T;
    }

    final rawValue = await _getRawValue<T>(key);
    if (rawValue != null && _validateValue(key, rawValue)) {
      return rawValue;
    }

    // Return default value if validation fails
    debugPrint('Using default value for $key: ${rule.defaultValue}');
    if (rule.defaultValue != null) {
      await _setRawValue(key, rule.defaultValue);
    }
    return rule.defaultValue as T;
  }

  /// Set validated value
  Future<bool> setValidated<T>(String key, T value) async {
    if (!_validateValue(key, value)) {
      debugPrint('Value validation failed for $key');
      return false;
    }

    final result = await _setRawValue(key, value);
    return result.isSuccess;
  }

  /// Get raw value from storage
  Future<T?> _getRawValue<T>(String key) async {
    try {
      switch (T) {
        case const (String):
          return await _storage.getString(key) as T?;
        case const (int):
          return await _storage.getInt(key) as T?;
        case const (double):
          return await _storage.getDouble(key) as T?;
        case const (bool):
          return await _storage.getBool(key) as T?;
        case const (List<String>):
          return await _storage.getStringList(key) as T?;
        default:
          debugPrint('Unsupported type for key $key: ${T.toString()}');
          return null;
      }
    } catch (e) {
      debugPrint('Error getting raw value for $key: $e');
      return null;
    }
  }

  /// Set raw value to storage
  Future<StorageResult<void>> _setRawValue(String key, dynamic value) async {
    try {
      if (value is String) {
        return await _storage.setString(key, value);
      } else if (value is int) {
        return await _storage.setInt(key, value);
      } else if (value is double) {
        return await _storage.setDouble(key, value);
      } else if (value is bool) {
        return await _storage.setBool(key, value);
      } else if (value is List<String>) {
        return await _storage.setStringList(key, value);
      } else {
        return StorageResult.failure('Unsupported type: ${value.runtimeType}');
      }
    } catch (e) {
      debugPrint('Error setting raw value for $key: $e');
      return StorageResult.failure('Storage error: $e');
    }
  }

  // Type-safe getters with validation (synchronous for compatibility)

  bool get isSetupCompleted => _storage.getBoolSync('setup_completed') ?? false;
  Future<bool> setSetupCompleted(bool value) =>
      setValidated('setup_completed', value);

  String get language => _storage.getStringSync('language') ?? 'en';
  Future<bool> setLanguage(String value) => setValidated('language', value);

  String get performanceMode =>
      _storage.getStringSync('performance_mode') ?? 'Balanced';
  Future<bool> setPerformanceMode(String value) =>
      setValidated('performance_mode', value);

  int get libraryTabs => _storage.getIntSync('library_tabs') ?? 3;
  Future<bool> setLibraryTabs(int value) => setValidated('library_tabs', value);

  bool get useMediaStore => _storage.getBoolSync('use_media_store') ?? false;
  Future<bool> setUseMediaStore(bool value) =>
      setValidated('use_media_store', value);

  String get syncFrequency =>
      _storage.getStringSync('sync_frequency') ?? 'Manual';
  Future<bool> setSyncFrequency(String value) =>
      setValidated('sync_frequency', value);

  String? get storageLocation => _storage.getStringSync('storage_location');
  Future<bool> setStorageLocation(String? value) async {
    if (value == null) {
      return (await _storage.remove('storage_location')).isSuccess;
    }
    return (await _storage.setString('storage_location', value)).isSuccess;
  }

  String? get proxy => _storage.getStringSync('proxy');
  Future<bool> setProxy(String? value) async {
    if (value == null) {
      return (await _storage.remove('proxy')).isSuccess;
    }
    return (await _storage.setString('proxy', value)).isSuccess;
  }

  String? get userAgent => _storage.getStringSync('user_agent');
  Future<bool> setUserAgent(String? value) async {
    if (value == null) {
      return (await _storage.remove('user_agent')).isSuccess;
    }
    return (await _storage.setString('user_agent', value)).isSuccess;
  }

  double get frostedIntensity =>
      _storage.getDoubleSync('frosted_intensity') ?? 0.5;
  Future<bool> setFrostedIntensity(double value) =>
      setValidated('frosted_intensity', value);

  String get fontFamily =>
      _storage.getStringSync('font_family') ?? 'Baloo Bhai 2';
  Future<bool> setFontFamily(String value) =>
      setValidated('font_family', value);

  List<String> get playlistOrder =>
      _storage.getStringListSync('playlist_order') ?? [];
  Future<bool> setPlaylistOrder(List<String> value) =>
      setValidated('playlist_order', value);

  String get ytdlpChannel =>
      _storage.getStringSync('ytdlp_channel') ?? 'Stable';
  Future<bool> setYtDlpChannel(String value) =>
      setValidated('ytdlp_channel', value);

  String get streamQuality =>
      _storage.getStringSync('stream_quality') ?? '720p';
  Future<bool> setStreamQuality(String value) =>
      setValidated('stream_quality', value);

  String get downloadQuality =>
      _storage.getStringSync('download_quality') ?? 'Best';
  Future<bool> setDownloadQuality(String value) =>
      setValidated('download_quality', value);

  String get downloadPath => _storage.getStringSync('download_path') ?? '';
  Future<bool> setDownloadPath(String value) =>
      setValidated('download_path', value);

  bool get hideLikedPlaylist =>
      _storage.getBoolSync('hide_liked_playlist') ?? false;
  Future<bool> setHideLikedPlaylist(bool value) =>
      setValidated('hide_liked_playlist', value);

  bool get hideWatchLaterPlaylist =>
      _storage.getBoolSync('hide_watch_later_playlist') ?? false;
  Future<bool> setHideWatchLaterPlaylist(bool value) =>
      setValidated('hide_watch_later_playlist', value);

  String? get geminiApiKey => _storage.getStringSync('gemini_api_key');
  Future<bool> setGeminiApiKey(String? value) async {
    if (value == null || value.isEmpty) {
      return (await _storage.remove('gemini_api_key')).isSuccess;
    }
    return (await _storage.setString('gemini_api_key', value)).isSuccess;
  }

  String get geminiModel =>
      _storage.getStringSync('gemini_model') ?? 'gemini-2.0-flash';
  Future<bool> setGeminiModel(String value) =>
      setValidated('gemini_model', value);

  String? get perplexityApiKey => _storage.getStringSync('perplexity_api_key');
  Future<bool> setPerplexityApiKey(String? value) async {
    if (value == null || value.isEmpty) {
      return (await _storage.remove('perplexity_api_key')).isSuccess;
    }
    return (await _storage.setString('perplexity_api_key', value)).isSuccess;
  }

  String get perplexityModel =>
      _storage.getStringSync('perplexity_model') ?? 'sonar';
  Future<bool> setPerplexityModel(String value) =>
      setValidated('perplexity_model', value);

  String get selectedAIProvider =>
      _storage.getStringSync('selected_ai_provider') ?? 'perplexity';
  Future<bool> setSelectedAIProvider(String value) =>
      setValidated('selected_ai_provider', value);

  bool get useDynamicColor => _storage.getBoolSync('use_dynamic_color') ?? true;
  Future<bool> setUseDynamicColor(bool value) =>
      setValidated('use_dynamic_color', value);

  int get seedColor => _storage.getIntSync('seed_color') ?? 0xFF68A500;
  Future<bool> setSeedColor(int value) => setValidated('seed_color', value);

  String get paletteStyle =>
      _storage.getStringSync('palette_style') ?? 'neutral';
  Future<bool> setPaletteStyle(String value) =>
      setValidated('palette_style', value);

  bool get pipEnabled => _storage.getBoolSync('pip_enabled') ?? true;
  Future<bool> setPipEnabled(bool value) => setValidated('pip_enabled', value);

  bool get audioOnlyMode => _storage.getBoolSync('audio_only_mode') ?? false;
  Future<bool> setAudioOnlyMode(bool value) =>
      setValidated('audio_only_mode', value);

  String get themeMode => _storage.getStringSync('theme_mode') ?? 'system';
  Future<bool> setThemeMode(String value) => setValidated('theme_mode', value);

  // Stream access
  Stream<String> get changes => _storage.changes;

  Future<void> validateAllSettings() async {
    debugPrint('Validating all settings...');

    for (final entry in _rules.entries) {
      final key = entry.key;
      final rule = entry.value;

      final currentValue = await _getRawValue(key);
      if (currentValue != null && !rule.validator(currentValue)) {
        debugPrint('Invalid value found for $key: ${rule.errorMessage}');
        if (rule.defaultValue != null) {
          await _setRawValue(key, rule.defaultValue);
          debugPrint('Reset $key to default value: ${rule.defaultValue}');
        }
      }
    }

    debugPrint('Settings validation completed');
  }

  Future<Map<String, dynamic>> exportSettings() async {
    final settings = <String, dynamic>{};

    for (final key in _rules.keys) {
      final value = await _getRawValue(key);
      if (value != null) {
        settings[key] = value;
      }
    }

    return settings;
  }

  Future<bool> importSettings(Map<String, dynamic> settings) async {
    final operations = <StorageOperation>[];

    for (final entry in settings.entries) {
      final key = entry.key;
      final value = entry.value;

      if (_validateValue(key, value)) {
        operations.add(StorageOperation.set(key, value));
      } else {
        debugPrint('Skipping invalid setting during import: $key');
      }
    }

    final result = await _storage.executeBatch(operations);
    return result.isSuccess;
  }

  Future<void> resetToDefaults() async {
    debugPrint('Resetting all settings to defaults...');

    final operations = <StorageOperation>[];

    for (final entry in _rules.entries) {
      final key = entry.key;
      final defaultValue = entry.value.defaultValue;

      if (defaultValue != null) {
        operations.add(StorageOperation.set(key, defaultValue));
      }
    }

    await _storage.executeBatch(operations);
    debugPrint('Settings reset to defaults completed');
  }

  Future<Map<String, dynamic>> getValidationReport() async {
    final report = <String, dynamic>{};

    for (final entry in _rules.entries) {
      final key = entry.key;
      final rule = entry.value;
      final currentValue = await _getRawValue(key);

      report[key] = {
        'currentValue': currentValue,
        'defaultValue': rule.defaultValue,
        'isValid': currentValue != null ? rule.validator(currentValue) : false,
        'errorMessage': rule.errorMessage,
      };
    }

    return report;
  }

  void dispose() {
    _storage.dispose();
  }
}
