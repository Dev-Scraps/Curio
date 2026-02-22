import 'dart:async';
import 'package:curio/core/services/storage/robust.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Storage performance monitoring utility
class StorageMonitor {
  final RobustStorageService _storage;
  final _metricsController = StreamController<Map<String, dynamic>>.broadcast();

  Timer? _monitoringTimer;
  static const Duration _monitoringInterval = Duration(minutes: 1);

  StorageMonitor(this._storage) {
    _startMonitoring();
  }

  /// Start performance monitoring
  void _startMonitoring() {
    _monitoringTimer = Timer.periodic(_monitoringInterval, (_) {
      _collectMetrics();
    });
  }

  /// Collect and broadcast performance metrics
  void _collectMetrics() {
    final stats = _storage.getPerformanceStats();
    final metrics = {
      'timestamp': DateTime.now().toIso8601String(),
      'cacheSize': stats['cacheSize'],
      'maxCacheSize': stats['maxCacheSize'],
      'oldestCacheEntry': stats['oldestCacheEntry'],
      'newestCacheEntry': stats['newestCacheEntry'],
      'memoryUsage': _getMemoryUsage(),
      'healthScore': _calculateHealthScore(stats),
    };

    _metricsController.add(metrics);

    if (kDebugMode) {
      debugPrint('Storage Monitor: ${metrics.toString()}');
    }
  }

  /// Calculate storage health score (0-100)
  double _calculateHealthScore(Map<String, dynamic> stats) {
    double score = 100.0;

    // Deduct points for large cache size
    final cacheSize = stats['cacheSize'] as int? ?? 0;
    if (cacheSize > 100)
      score -= 20;
    else if (cacheSize > 50)
      score -= 10;

    // Deduct points for old cache entries
    final oldestEntry = stats['oldestCacheEntry'] as String?;
    if (oldestEntry != null) {
      final age = DateTime.now().difference(DateTime.parse(oldestEntry));
      if (age.inHours > 1)
        score -= 15;
      else if (age.inMinutes > 30)
        score -= 5;
    }

    return score.clamp(0.0, 100.0);
  }

  /// Get estimated memory usage
  Map<String, dynamic> _getMemoryUsage() {
    return {
      'estimatedCacheMemoryKB': _estimateCacheMemoryUsage(),
      'estimatedTotalMemoryKB': _estimateTotalMemoryUsage(),
    };
  }

  /// Estimate cache memory usage in KB
  double _estimateCacheMemoryUsage() {
    // Rough estimation: each cache entry ~100 bytes average
    return (_storage.getPerformanceStats()['cacheSize'] as int? ?? 0) * 0.1;
  }

  /// Estimate total memory usage in KB
  double _estimateTotalMemoryUsage() {
    // Include cache + service overhead
    return _estimateCacheMemoryUsage() + 50.0; // 50KB overhead estimate
  }

  /// Stream of performance metrics
  Stream<Map<String, dynamic>> get metrics => _metricsController.stream;

  /// Get current performance snapshot
  Map<String, dynamic> getCurrentSnapshot() {
    final stats = _storage.getPerformanceStats();
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'performanceStats': stats,
      'memoryUsage': _getMemoryUsage(),
      'healthScore': _calculateHealthScore(stats),
      'recommendations': _getRecommendations(stats),
    };
  }

  /// Get optimization recommendations
  List<String> _getRecommendations(Map<String, dynamic> stats) {
    final recommendations = <String>[];

    final cacheSize = stats['cacheSize'] as int? ?? 0;
    if (cacheSize > 100) {
      recommendations.add('Cache size is large. Consider optimizing cache.');
    }

    final oldestEntry = stats['oldestCacheEntry'] as String?;
    if (oldestEntry != null) {
      final age = DateTime.now().difference(DateTime.parse(oldestEntry));
      if (age.inHours > 1) {
        recommendations.add(
          'Cache contains old entries. Consider cache cleanup.',
        );
      }
    }

    final healthScore = _calculateHealthScore(stats);
    if (healthScore < 80) {
      recommendations.add(
        'Storage health is below optimal. Consider optimization.',
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add('Storage performance is optimal.');
    }

    return recommendations;
  }

  /// Force optimization based on current metrics
  Future<void> optimizeNow() async {
    debugPrint('Storage Monitor: Running optimization...');
    await _storage.optimizeCache();
    _collectMetrics();
    debugPrint('Storage Monitor: Optimization completed');
  }

  /// Stop monitoring
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  /// Resume monitoring
  void resumeMonitoring() {
    if (_monitoringTimer == null) {
      _startMonitoring();
    }
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _metricsController.close();
  }
}

/// Provider for storage monitor
final storageMonitorProvider = Provider<StorageMonitor>((ref) {
  final storage = ref.read(robustStorageServiceProvider);
  return StorageMonitor(storage);
});
