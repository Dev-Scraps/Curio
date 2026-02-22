import 'package:curio/core/services/system/notifications.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'package:audio_service/audio_service.dart';

import 'package:flutter_logs/flutter_logs.dart';
import 'core/services/storage/storage.dart';
import 'core/services/yt_dlp/ytdlp.dart';
import 'core/services/audio_handler.dart';
import 'core/utils/storage_test.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/font_provider.dart';
import 'presentation/providers/language_provider.dart';
import 'presentation/screens/setup/setup_screen.dart';
import 'presentation/screens/nav/nav_screen.dart';

import 'core/services/content/downloader.dart';
import 'l10n/app_localizations.dart';

final storageTriggerProvider = StreamProvider<int>((ref) {
  return ref
      .watch(storageServiceProvider)
      .changes
      .map((_) => DateTime.now().microsecondsSinceEpoch);
});

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize File Logging
  FlutterLogs.initLogs(
    logLevelsEnabled: [
      LogLevel.INFO,
      LogLevel.WARNING,
      LogLevel.ERROR,
      LogLevel.SEVERE,
    ],
    timeStampFormat: TimeStampFormat.TIME_FORMAT_READABLE,
    directoryStructure: DirectoryStructure.FOR_DATE,
    logFileExtension: LogFileExtension.LOG,
    enabled: true,
  );

  runApp(const ProviderScope(child: AppBootstrap()));
}

/* -------------------------------------------------------------------------- */
/* ROOT APP */
/* -------------------------------------------------------------------------- */

class _AppHome extends ConsumerWidget {
  // ignore: unused_element_parameter
  const _AppHome({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setupDone = ref.watch(storageServiceProvider).isSetupCompleted;

    return setupDone ? const NavScreen() : const SetupScreen();
  }
}

class CurioApp extends ConsumerWidget {
  const CurioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeAsync = ref.watch(themeModeProvider);
    final languageAsync = ref.watch(languageProvider);
    ref.watch(storageTriggerProvider);
    final storage = ref.watch(storageServiceProvider);

    return themeModeAsync.when(
      data: (mode) {
        return languageAsync.when(
          data: (locale) {
            final isDark = _isDark(mode);
            final textTheme = ref.watch(textThemeProvider);
            final useDynamicColor = storage.useDynamicColor;
            final seedColor = storage.seedColor;

            SystemChrome.setSystemUIOverlayStyle(
              SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                statusBarIconBrightness: isDark
                    ? Brightness.light
                    : Brightness.dark,
                systemNavigationBarIconBrightness: isDark
                    ? Brightness.light
                    : Brightness.dark,
              ),
            );

            return DynamicColorBuilder(
              builder: (lightDynamic, darkDynamic) {
                return MaterialApp(
                  title: 'Curio',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme(
                    textTheme,
                    seedColor: seedColor,
                    dynamicColorScheme: useDynamicColor ? lightDynamic : null,
                  ),
                  darkTheme: AppTheme.darkTheme(
                    textTheme,
                    seedColor: seedColor,
                    dynamicColorScheme: useDynamicColor ? darkDynamic : null,
                  ),
                  themeMode: mode,
                  locale: locale,
                  localizationsDelegates: [
                    AppLocalizations.delegate,
                    ...ref.watch(localizationDelegatesProvider),
                  ],
                  supportedLocales: ref.watch(supportedLocalesProvider),
                  home: const _AppHome(),
                );
              },
            );
          },
          loading: () => const _Splash(),
          error: (err, _) => _Error(err),
        );
      },
      loading: () => const _Splash(),
      error: (err, _) => _Error(err),
    );
  }

  bool _isDark(ThemeMode m) =>
      m == ThemeMode.dark ||
      (m == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);
}

/* -------------------------------------------------------------------------- */
/* BOOTSTRAP — SAFE PLACE FOR HEAVY INIT */
/* -------------------------------------------------------------------------- */
class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap> {
  bool ready = false;
  Object? error;
  late StorageService storage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    try {
      MediaKit.ensureInitialized();

      // Initialize Audio Service
      await AudioService.init(
        builder: () => MediaAudioHandler(Player()),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.curio.app.channel.audio',
          androidNotificationChannelName: 'Curio Playback',
          androidNotificationOngoing: true,
        ),
      );

      storage = ref.read(storageServiceProvider);

      final yt = ref.read(ytDlpServiceProvider);
      await yt.initialize(channel: storage.ytdlpChannel);
      await yt.setPoToken(storage.ytdlpPoToken);

      await testPublicStorageAccess();

      final notifications = ref.read(notificationServiceProvider);
      await notifications.initialize();

      // Sync local downloads in background
      final downloadService = ref.read(downloadServiceProvider.notifier);
      downloadService.syncLocalFiles().catchError((e) {
        print('Background sync error: $e');
      });

      setState(() => ready = true);
    } catch (e) {
      setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return MaterialApp(
        home: Scaffold(body: Center(child: Text('$error'))),
      );
    }

    if (!ready) {
      return MaterialApp(
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    return ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
      child: const CurioApp(),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* PLACEHOLDERS */
/* -------------------------------------------------------------------------- */

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final Object error;
  const _Error(this.error);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}
