import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/services/storage/storage.dart';
import 'widgets/settings_widgets.dart';

class PlaybackSettingsScreen extends ConsumerWidget {
  const PlaybackSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Playback'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Video Quality Section
          const SectionHeader(title: 'VIDEO QUALITY'),
          const Gap(8),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Symbols.play_circle,
                title: 'Stream Quality',
                subtitle: storage.streamQuality,
                onTap: () => _showQualityDialog(context, ref, true),
              ),
            ],
          ),
          const Gap(24),

          // Audio Settings Section
          const SectionHeader(title: 'AUDIO'),
          const Gap(8),
          SettingsCard(
            children: [
              SwitchTile(
                icon: Symbols.headphones,
                title: 'Audio-Only Mode',
                value: storage.audioOnlyMode,
                onChanged: (v) => storage.setAudioOnlyMode(v),
              ),
            ],
          ),
          const Gap(24),

          // Tips Section
          const SectionHeader(title: 'TIPS'),
          const Gap(8),
          SettingsCard(
            children: [
              _TipTile(
                icon: Icons.info,
                title: 'Data Usage',
                description: 'Lower quality saves mobile data',
              ),
              const Divider(height: 1, indent: 56),
              _TipTile(
                icon: Icons.info,
                title: 'Performance',
                description:
                    'Lower quality improves performance on older devices',
              ),
              const Divider(height: 1, indent: 56),
              _TipTile(
                icon: Icons.info,
                title: 'Audio Mode',
                description: 'Audio-only mode saves battery and data',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQualityDialog(BuildContext context, WidgetRef ref, bool isStream) {
    final storage = ref.read(storageServiceProvider);
    final current = isStream ? storage.streamQuality : storage.downloadQuality;
    final options = ['Best', '1080p', '720p', '480p', '360p', 'Worst'];

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(isStream ? 'Stream Quality' : 'Download Quality'),
        children: options.map((opt) {
          return RadioListTile<String>(
            title: Text(opt),
            value: opt,
            groupValue: current,
            onChanged: (v) {
              if (v != null) {
                if (isStream) {
                  storage.setStreamQuality(v);
                } else {
                  storage.setDownloadQuality(v);
                }
                Navigator.pop(context);
              }
            },
          );
        }).toList(),
      ),
    );
  }
}

class _QualityInfoTile extends StatelessWidget {
  final String title;
  final String description;
  final dynamic icon;

  const _QualityInfoTile({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipTile extends StatelessWidget {
  final String title;
  final String description;
  final dynamic icon;

  const _TipTile({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 20),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
