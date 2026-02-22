import 'package:curio/core/services/content/sync.dart';
import 'package:curio/core/services/storage/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart';
import '/../l10n/app_localizations.dart';
import 'cookies_screen.dart';
import 'widgets/settings_widgets.dart';
import 'ai_config_screen.dart';
import 'about_screen.dart' as about;
import 'appearance_settings_screen.dart';
import 'playback_settings_screen.dart';
import 'downloads_settings_screen.dart';
import 'library_settings_screen.dart';
import 'data_management_screen.dart';

// Watch this provider to rebuild UI on storage changes
final settingsChangeTriggerProvider = StreamProvider.autoDispose<int>((ref) {
  return ref
      .watch(storageServiceProvider)
      .changes
      .map((key) => DateTime.now().microsecondsSinceEpoch);
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to all storage change triggers for real-time updates
    ref.listen(settingsChangeTriggerProvider, (_, __) {});

    final storage = ref.watch(storageServiceProvider);
    final syncState = ref.watch(syncServiceProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: false,
            snap: false,
            elevation: 0,
            centerTitle: true,
            title: Text(
              'Settings',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Cookies Section
                const SectionHeader(title: 'Cookies'),
                SettingsCard(
                  children: [
                    SettingsTile(
                      icon: Symbols.cookie_rounded,
                      title: 'Manage Cookies',
                      subtitle: 'Import and manage cookies',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CookiesScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(24),

                // AI Assistant Section
                const SectionHeader(title: 'AI Assistant'),
                SettingsCard(
                  children: [
                    SettingsTile(
                      icon: Symbols.key_rounded,
                      title: 'API Configuration',
                      subtitle: _getAIConfigStatus(storage),
                      trailing: _getAIConfigIcon(context, storage),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AIConfigScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(24),

                // Appearance Section
                SectionHeader(title: AppLocalizations.of(context)!.appearance),
                SettingsCard(
                  children: [
                    SettingsTile(
                      icon: Symbols.palette_rounded,
                      title: 'Theme & Appearance',
                      subtitle: 'Theme, colors, fonts',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AppearanceSettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(24),

                // Playback Section
                const SectionHeader(title: 'Playback'),
                SettingsCard(
                  children: [
                    SettingsTile(
                      icon: Symbols.play_circle_rounded,
                      title: 'Playback Settings',
                      subtitle: 'Quality, audio options',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PlaybackSettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(24),

                // Downloads Section
                const SectionHeader(title: 'Downloads'),
                SettingsCard(
                  children: [
                    SettingsTile(
                      icon: Symbols.download_rounded,
                      title: 'Download Settings',
                      subtitle: 'Quality, location',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DownloadsSettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(24),

                // Library Section
                const SectionHeader(title: 'Library'),
                SettingsCard(
                  children: [
                    SettingsTile(
                      icon: Symbols.sync_rounded,
                      title: 'Library Settings',
                      subtitle: 'Sync, playlists, visibility',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LibrarySettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(24),

                // Data & Storage Section
                const SectionHeader(title: 'Data & Storage'),
                SettingsCard(
                  children: [
                    SettingsTile(
                      icon: Symbols.folder_open_rounded,
                      title: 'Data Management',
                      subtitle: 'Backup, restore, clear',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DataManagementScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(24),

                // About Section
                const SectionHeader(title: 'About'),
                SettingsCard(
                  children: [
                    SettingsTile(
                      icon: Symbols.info_rounded,
                      title: 'App Info',
                      subtitle: 'Version 1.0.0',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const about.AboutScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(32),

                SafeArea(child: const Gap(10)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _getAIConfigStatus(dynamic storage) {
    final provider = storage.selectedAIProvider;
    final hasKey = provider == 'perplexity'
        ? (storage.perplexityApiKey != null &&
              storage.perplexityApiKey!.isNotEmpty)
        : (storage.geminiApiKey != null && storage.geminiApiKey!.isNotEmpty);

    if (hasKey) {
      return '${provider == 'perplexity' ? 'Perplexity' : 'Gemini'} configured';
    } else {
      return 'Not configured';
    }
  }

  Widget? _getAIConfigIcon(BuildContext context, dynamic storage) {
    final provider = storage.selectedAIProvider;
    final hasKey = provider == 'perplexity'
        ? (storage.perplexityApiKey != null &&
              storage.perplexityApiKey!.isNotEmpty)
        : (storage.geminiApiKey != null && storage.geminiApiKey!.isNotEmpty);

    if (hasKey) {
      return Icon(
        Symbols.check_circle_rounded,
        size: 20.0,
        color: Theme.of(context).colorScheme.primary,
      );
    }
    return null;
  }
}
