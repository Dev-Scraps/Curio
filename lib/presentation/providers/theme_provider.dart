import 'package:curio/core/services/storage/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_provider.g.dart';

final _themeTriggerProvider = StreamProvider<int>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.changes
      .where((key) => key == StorageService.keyThemeMode)
      .map((_) => DateTime.now().microsecondsSinceEpoch);
});

@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  Future<ThemeMode> build() async {
    ref.watch(_themeTriggerProvider);
    final storage = ref.watch(storageServiceProvider);
    final saved = storage.getThemeMode();
    if (saved == 'light') return ThemeMode.light;
    if (saved == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(mode);
    final storage = ref.read(storageServiceProvider);
    String value;
    switch (mode) {
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.dark:
        value = 'dark';
        break;
      case ThemeMode.system:
        value = 'system';
        break;
    }
    await storage.setThemeMode(value);
  }
}
