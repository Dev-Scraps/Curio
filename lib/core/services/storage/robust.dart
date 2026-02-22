import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

part 'robust.g.dart';

/// Enhanced storage service with robust error handling, caching, and optimization
@Riverpod(keepAlive: true)
RobustStorageService robustStorageService(Ref ref) {
  debugPrint('RobustStorageService: Initializing enhanced storage service');
  return RobustStorageService();
}

/// Storage operation result with error handling
class StorageResult<T> {
  final T? value;
  final String? error;
  final bool success;

  const StorageResult.success(this.value) : success = true, error = null;
  const StorageResult.failure(this.error) : success = false, value = null;

  bool get isSuccess => success;
  bool get isFailure => !success;
}

/// Storage operation types for batch processing
enum StorageOperationType { set, remove, clear }

/// Storage operation for batch processing
class StorageOperation {
  final StorageOperationType type;
  final String key;
  final dynamic value;

  const StorageOperation.set(this.key, this.value)
    : type = StorageOperationType.set;
  const StorageOperation.remove(this.key)
    : type = StorageOperationType.remove,
      value = null;
  const StorageOperation.clear()
    : type = StorageOperationType.clear,
      key = '',
      value = null;
}

/// Enhanced storage service with robust error handling and optimization
class RobustStorageService {
  late SharedPreferences _prefs;
  final _lock = Lock();
  final _cache = <String, dynamic>{};
  final _cacheTimestamps = <String, DateTime>{};
  final _changeController = StreamController<String>.broadcast();
  final _retryController = StreamController<StorageOperation>.broadcast();

  static const Duration _cacheTimeout = Duration(minutes: 5);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 100);

  RobustStorageService() {
    _prefs = _FallbackSharedPreferences();
    _initialize();
    _setupRetryMechanism();
  }

  /// Initialize the storage service
  Future<void> _initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      debugPrint('RobustStorageService: Successfully initialized');
    } catch (e) {
      debugPrint('RobustStorageService: Initialization failed - $e');
      // Use fallback storage
      _prefs = _FallbackSharedPreferences();
    }
  }

  /// Setup retry mechanism for failed operations
  void _setupRetryMechanism() {
    _retryController.stream.listen((operation) async {
      await _executeWithRetry(operation);
    });
  }

  /// Execute operation with retry mechanism
  Future<StorageResult<void>> _executeWithRetry(
    StorageOperation operation, [
    int attempt = 0,
  ]) async {
    try {
      await _lock.synchronized(() async {
        switch (operation.type) {
          case StorageOperationType.set:
            await _performSet(operation.key, operation.value);
            break;
          case StorageOperationType.remove:
            await _performRemove(operation.key);
            break;
          case StorageOperationType.clear:
            await _performClear();
            break;
        }
      });
      return const StorageResult.success(null);
    } catch (e) {
      if (attempt < _maxRetries) {
        debugPrint(
          'RobustStorageService: Retrying operation (attempt ${attempt + 1}/$_maxRetries)',
        );
        await Future.delayed(_retryDelay * (attempt + 1));
        return _executeWithRetry(operation, attempt + 1);
      } else {
        debugPrint(
          'RobustStorageService: Operation failed after $_maxRetries attempts - $e',
        );
        return StorageResult.failure('Storage operation failed: $e');
      }
    }
  }

  /// Stream of storage changes for real-time updates
  Stream<String> get changes => _changeController.stream;

  /// Notify listeners of storage changes
  void _notifyChange(String key) {
    _changeController.add(key);
    _invalidateCache(key);
  }

  /// Cache management
  void _updateCache(String key, dynamic value) {
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();
  }

  void _invalidateCache(String key) {
    _cache.remove(key);
    _cacheTimestamps.remove(key);
  }

  void _cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = _cacheTimestamps.entries
        .where((entry) => now.difference(entry.value) > _cacheTimeout)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _invalidateCache(key);
    }
  }

  /// Get cached value if valid
  T? _getCachedValue<T>(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp != null &&
        DateTime.now().difference(timestamp) < _cacheTimeout) {
      return _cache[key] as T?;
    }
    return null;
  }

  // Core storage operations with error handling and caching

  Future<bool?> getBool(String key) async {
    final cached = _getCachedValue<bool>(key);
    if (cached != null) return cached;

    try {
      final value = await _lock.synchronized(() => _prefs.getBool(key));
      _updateCache(key, value);
      return value;
    } catch (e) {
      debugPrint('RobustStorageService: Error getting bool for key $key - $e');
      return null;
    }
  }

  Future<StorageResult<void>> setBool(String key, bool value) async {
    final operation = StorageOperation.set(key, value);
    final result = await _executeWithRetry(operation);
    if (result.isSuccess) {
      _updateCache(key, value);
      _notifyChange(key);
    }
    return result;
  }

  Future<String?> getString(String key) async {
    final cached = _getCachedValue<String>(key);
    if (cached != null) return cached;

    try {
      final value = await _lock.synchronized(() => _prefs.getString(key));
      _updateCache(key, value);
      return value;
    } catch (e) {
      debugPrint(
        'RobustStorageService: Error getting string for key $key - $e',
      );
      return null;
    }
  }

  Future<StorageResult<void>> setString(String key, String value) async {
    final operation = StorageOperation.set(key, value);
    final result = await _executeWithRetry(operation);
    if (result.isSuccess) {
      _updateCache(key, value);
      _notifyChange(key);
    }
    return result;
  }

  Future<int?> getInt(String key) async {
    final cached = _getCachedValue<int>(key);
    if (cached != null) return cached;

    try {
      final value = await _lock.synchronized(() => _prefs.getInt(key));
      _updateCache(key, value);
      return value;
    } catch (e) {
      debugPrint('RobustStorageService: Error getting int for key $key - $e');
      return null;
    }
  }

  Future<StorageResult<void>> setInt(String key, int value) async {
    final operation = StorageOperation.set(key, value);
    final result = await _executeWithRetry(operation);
    if (result.isSuccess) {
      _updateCache(key, value);
      _notifyChange(key);
    }
    return result;
  }

  Future<double?> getDouble(String key) async {
    final cached = _getCachedValue<double>(key);
    if (cached != null) return cached;

    try {
      final value = await _lock.synchronized(() => _prefs.getDouble(key));
      _updateCache(key, value);
      return value;
    } catch (e) {
      debugPrint(
        'RobustStorageService: Error getting double for key $key - $e',
      );
      return null;
    }
  }

  Future<StorageResult<void>> setDouble(String key, double value) async {
    final operation = StorageOperation.set(key, value);
    final result = await _executeWithRetry(operation);
    if (result.isSuccess) {
      _updateCache(key, value);
      _notifyChange(key);
    }
    return result;
  }

  Future<List<String>?> getStringList(String key) async {
    final cached = _getCachedValue<List<String>>(key);
    if (cached != null) return cached;

    try {
      final value = await _lock.synchronized(() => _prefs.getStringList(key));
      _updateCache(key, value);
      return value;
    } catch (e) {
      debugPrint(
        'RobustStorageService: Error getting string list for key $key - $e',
      );
      return null;
    }
  }

  Future<StorageResult<void>> setStringList(
    String key,
    List<String> value,
  ) async {
    final operation = StorageOperation.set(key, value);
    final result = await _executeWithRetry(operation);
    if (result.isSuccess) {
      _updateCache(key, value);
      _notifyChange(key);
    }
    return result;
  }

  Future<StorageResult<void>> remove(String key) async {
    final operation = StorageOperation.remove(key);
    final result = await _executeWithRetry(operation);
    if (result.isSuccess) {
      _invalidateCache(key);
      _notifyChange(key);
    }
    return result;
  }

  Future<StorageResult<void>> clear() async {
    final operation = StorageOperation.clear();
    final result = await _executeWithRetry(operation);
    if (result.isSuccess) {
      _cache.clear();
      _cacheTimestamps.clear();
      _notifyChange('clear_all');
    }
    return result;
  }

  Future<bool> containsKey(String key) async {
    try {
      return await _lock.synchronized(() => _prefs.containsKey(key));
    } catch (e) {
      debugPrint('RobustStorageService: Error checking key $key - $e');
      return false;
    }
  }

  Future<Set<String>> getKeys() async {
    try {
      return await _lock.synchronized(() => _prefs.getKeys());
    } catch (e) {
      debugPrint('RobustStorageService: Error getting keys - $e');
      return <String>{};
    }
  }

  // Batch operations for better performance

  Future<StorageResult<void>> executeBatch(
    List<StorageOperation> operations,
  ) async {
    try {
      await _lock.synchronized(() async {
        for (final operation in operations) {
          switch (operation.type) {
            case StorageOperationType.set:
              await _performSet(operation.key, operation.value);
              break;
            case StorageOperationType.remove:
              await _performRemove(operation.key);
              break;
            case StorageOperationType.clear:
              await _performClear();
              break;
          }
        }
        await _prefs.commit();
      });

      // Notify all changes
      for (final operation in operations) {
        if (operation.type == StorageOperationType.set) {
          _updateCache(operation.key, operation.value);
          _notifyChange(operation.key);
        } else if (operation.type == StorageOperationType.remove) {
          _invalidateCache(operation.key);
          _notifyChange(operation.key);
        }
      }

      return const StorageResult.success(null);
    } catch (e) {
      debugPrint('RobustStorageService: Batch operation failed - $e');
      return StorageResult.failure('Batch operation failed: $e');
    }
  }

  // Atomic transaction support

  Future<StorageResult<void>> executeTransaction(
    Map<String, dynamic> values,
  ) async {
    final operations = values.entries
        .map((entry) => StorageOperation.set(entry.key, entry.value))
        .toList();

    return executeBatch(operations);
  }

  // Low-level operations

  // Synchronous getters for backward compatibility
  String? getStringSync(String key) {
    try {
      return _cache[key] as String? ?? _prefs.getString(key);
    } catch (e) {
      debugPrint('Error getting sync string for $key: $e');
      return null;
    }
  }

  bool? getBoolSync(String key) {
    try {
      return _cache[key] as bool? ?? _prefs.getBool(key);
    } catch (e) {
      debugPrint('Error getting sync bool for $key: $e');
      return null;
    }
  }

  int? getIntSync(String key) {
    try {
      return _cache[key] as int? ?? _prefs.getInt(key);
    } catch (e) {
      debugPrint('Error getting sync int for $key: $e');
      return null;
    }
  }

  double? getDoubleSync(String key) {
    try {
      return _cache[key] as double? ?? _prefs.getDouble(key);
    } catch (e) {
      debugPrint('Error getting sync double for $key: $e');
      return null;
    }
  }

  List<String>? getStringListSync(String key) {
    try {
      return _cache[key] as List<String>? ?? _prefs.getStringList(key);
    } catch (e) {
      debugPrint('Error getting sync string list for $key: $e');
      return null;
    }
  }

  Future<void> _performSet(String key, dynamic value) async {
    if (value is String) {
      await _prefs.setString(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    } else if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is List<String>) {
      await _prefs.setStringList(key, value);
    } else {
      throw ArgumentError('Unsupported type: ${value.runtimeType}');
    }
  }

  Future<void> _performRemove(String key) async {
    await _prefs.remove(key);
  }

  Future<void> _performClear() async {
    await _prefs.clear();
  }

  // Memory management

  void dispose() {
    _changeController.close();
    _retryController.close();
    _cache.clear();
    _cacheTimestamps.clear();
  }

  // Utility methods

  Future<void> reload() async {
    try {
      await _prefs.reload();
      _cache.clear();
      _cacheTimestamps.clear();
      debugPrint('RobustStorageService: Storage reloaded');
    } catch (e) {
      debugPrint('RobustStorageService: Error reloading storage - $e');
    }
  }

  Future<bool> commit() async {
    try {
      return await _prefs.commit();
    } catch (e) {
      debugPrint('RobustStorageService: Error committing storage - $e');
      return false;
    }
  }

  // Performance monitoring

  Map<String, dynamic> getPerformanceStats() {
    return {
      'cacheSize': _cache.length,
      'maxCacheSize': _cacheTimestamps.length,
      'oldestCacheEntry': _cacheTimestamps.isEmpty
          ? null
          : _cacheTimestamps.values
                .reduce((a, b) => a.isBefore(b) ? a : b)
                .toIso8601String(),
      'newestCacheEntry': _cacheTimestamps.isEmpty
          ? null
          : _cacheTimestamps.values
                .reduce((a, b) => a.isAfter(b) ? a : b)
                .toIso8601String(),
    };
  }

  Future<void> optimizeCache() async {
    _cleanupExpiredCache();
    debugPrint('RobustStorageService: Cache optimized');
  }
}

/// Fallback SharedPreferences implementation for error scenarios
class _FallbackSharedPreferences implements SharedPreferences {
  final _data = <String, dynamic>{};

  @override
  bool? getBool(String key) => _data[key] as bool?;

  @override
  Future<bool> setBool(String key, bool value) async {
    _data[key] = value;
    return true;
  }

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  @override
  int? getInt(String key) => _data[key] as int?;

  @override
  Future<bool> setInt(String key, int value) async {
    _data[key] = value;
    return true;
  }

  @override
  double? getDouble(String key) => _data[key] as double?;

  @override
  Future<bool> setDouble(String key, double value) async {
    _data[key] = value;
    return true;
  }

  @override
  List<String>? getStringList(String key) => _data[key] as List<String>?;

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _data.clear();
    return true;
  }

  @override
  Future<bool> commit() async => true;

  @override
  Future<void> reload() async {}

  @override
  bool containsKey(String key) => _data.containsKey(key);

  @override
  Set<String> getKeys() => _data.keys.toSet();

  @override
  Object? get(String key) => _data[key];
}
