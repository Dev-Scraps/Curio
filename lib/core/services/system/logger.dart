import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter_logs/flutter_logs.dart' as fl;

enum LogLevel { debug, info, warning, error }

class LogService {
  static const String _appName = 'Curio';

  static void d(String tag, String message) {
    _log(LogLevel.debug, tag, message);
  }

  static void i(String tag, String message) {
    _log(LogLevel.info, tag, message);
  }

  static void w(
    String tag,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    _log(LogLevel.warning, tag, message, error, stackTrace);
  }

  static void e(
    String tag,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    _log(LogLevel.error, tag, message, error, stackTrace);
  }

  static void _log(
    LogLevel level,
    String tag,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    // In release mode, we might want to suppress debug/info logs or send errors to Crashlytics
    if (kReleaseMode && level == LogLevel.debug) return;

    final timestamp = DateTime.now()
        .toIso8601String()
        .split('T')
        .last
        .substring(0, 8);
    final emoji = _getEmoji(level);
    final levelName = level.name.toUpperCase();

    // Standard print for console visibility
    print('[$timestamp] $emoji [$levelName] [$tag]: $message');

    if (error != null) {
      print('[$timestamp] 💥 Error: $error');
      if (stackTrace != null) {
        print(stackTrace);
      }
    }

    // Dart Developer Log (visible in DevTools / Logging tab)
    dev.log(
      message,
      name: '$_appName.$tag',
      level: _getSeverity(level),
      error: error,
      stackTrace: stackTrace,
    );

    // Persist to file using FlutterLogs
    _logToFile(level, tag, message, error);
  }

  static void _logToFile(
    LogLevel level,
    String tag,
    String message, [
    dynamic error,
  ]) {
    switch (level) {
      case LogLevel.debug:
        fl.FlutterLogs.logThis(
          tag: tag,
          subTag: _appName,
          logMessage: message,
          level: fl.LogLevel.INFO,
        );
        break;
      case LogLevel.info:
        fl.FlutterLogs.logThis(
          tag: tag,
          subTag: _appName,
          logMessage: message,
          level: fl.LogLevel.INFO,
        );
        break;
      case LogLevel.warning:
        fl.FlutterLogs.logThis(
          tag: tag,
          subTag: _appName,
          logMessage: message,
          level: fl.LogLevel.WARNING,
        );
        break;
      case LogLevel.error:
        fl.FlutterLogs.logError(tag, _appName, message);
        if (error != null) {
          fl.FlutterLogs.logError(tag, _appName, 'Error details: $error');
        }
        break;
    }
  }

  static String _getEmoji(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🐛';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '⛔';
    }
  }

  static int _getSeverity(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}
