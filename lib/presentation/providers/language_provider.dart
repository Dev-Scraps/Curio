import 'package:curio/core/services/storage/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

part 'language_provider.g.dart';

final _languageTriggerProvider = StreamProvider<int>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.changes
      .where((key) => key == StorageService.keyLanguage)
      .map((_) => DateTime.now().microsecondsSinceEpoch);
});

@riverpod
class LanguageNotifier extends _$LanguageNotifier {
  static const supportedLocales = [
    Locale('en'), // English
    Locale('es'), // Spanish
    Locale('hi'), // Hindi
    Locale('fr'), // French
    Locale('de'), // German
    Locale('zh'), // Chinese
    Locale('ja'), // Japanese
    Locale('ar'), // Arabic
    Locale('pt'), // Portuguese
  ];

  @override
  Future<Locale> build() async {
    ref.watch(_languageTriggerProvider);
    final storage = ref.watch(storageServiceProvider);
    final saved = storage.language;

    try {
      return Locale(saved);
    } catch (e) {
      // Fallback to system locale if saved value is invalid
      return _getSystemLocale();
    }
  }

  Locale _getSystemLocale() {
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;

    // Check if system locale is supported
    for (final supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == systemLocale.languageCode) {
        return supportedLocale;
      }
    }

    // Fallback to English
    return const Locale('en');
  }

  Future<void> setLanguage(Locale locale) async {
    state = AsyncData(locale);
    final storage = ref.read(storageServiceProvider);
    await storage.setLanguage(locale.languageCode);
  }

  String getLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'hi':
        return 'हिन्दी';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      case 'zh':
        return '中文';
      case 'ja':
        return '日本語';
      case 'ar':
        return 'العربية';
      case 'pt':
        return 'Português';
      default:
        return locale.languageCode.toUpperCase();
    }
  }

  String getNativeLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'hi':
        return 'हिन्दी';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      case 'zh':
        return '中文';
      case 'ja':
        return '日本語';
      case 'ar':
        return 'العربية';
      case 'pt':
        return 'Português';
      default:
        return locale.languageCode.toUpperCase();
    }
  }
}

// Provider for the list of supported locales
@riverpod
List<Locale> supportedLocales(Ref ref) {
  return LanguageNotifier.supportedLocales;
}

// Provider for localization delegates
@riverpod
List<LocalizationsDelegate<dynamic>> localizationDelegates(Ref ref) {
  return [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
}
