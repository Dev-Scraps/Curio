import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/services/content/sync.dart';
import '../../../core/services/storage/storage.dart';
import '../../providers/playlists_provider.dart';
import 'widgets/settings_widgets.dart';

class LibrarySettingsScreen extends ConsumerWidget {
  const LibrarySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    final syncState = ref.watch(syncServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Library'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sync Section
          const SectionHeader(title: 'SYNC'),
          const Gap(8),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Symbols.refresh,
                title: 'Sync Library',
                subtitle: 'Fetch latest from YouTube',
                onTap: () async {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Syncing...')));
                  try {
                    await ref
                        .read(syncServiceProvider.notifier)
                        .syncFullLibrary();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✓ Sync completed')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sync failed: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          const Gap(24),

          // Account Status Section
          const SectionHeader(title: 'ACCOUNT STATUS'),
          const Gap(8),
          SettingsCard(
            children: [
              _AccountStatusTile(
                icon: Icons.person,
                title: 'Account',
                subtitle: syncState.activeAccount?.name ?? 'Not signed in',
                description: syncState.activeAccount?.email ?? 'Tap to sign in',
                isSignedIn: syncState.activeAccount != null,
              ),
            ],
          ),
          const Gap(24),

          // Playlist Visibility Section
          const SectionHeader(title: 'PLAYLIST VISIBILITY'),
          const Gap(8),
          SettingsCard(
            children: [
              SwitchTile(
                icon: Symbols.visibility_off,
                title: 'Hide Liked Videos',
                value: storage.hideLikedPlaylist,
                onChanged: (v) {
                  storage.setHideLikedPlaylist(v);
                  ref.invalidate(playlistsProvider);
                },
              ),
              const Divider(height: 1, indent: 56),
              SwitchTile(
                icon: Symbols.schedule,
                title: 'Hide Watch Later',
                value: storage.hideWatchLaterPlaylist,
                onChanged: (v) {
                  storage.setHideWatchLaterPlaylist(v);
                  ref.invalidate(playlistsProvider);
                },
              ),
            ],
          ),
          const Gap(24),

          const SectionHeader(title: 'TIPS'),
          const Gap(8),
          SettingsCard(
            children: [
              _TipTile(
                icon: Icons.info,
                title: 'Regular Sync',
                description: 'Sync weekly for latest content',
              ),
              const Divider(height: 1, indent: 56),
              _TipTile(
                icon: Icons.info,
                title: 'Storage Space',
                description: 'Clear cache if app becomes slow',
              ),
              const Divider(height: 1, indent: 56),
              _TipTile(
                icon: Icons.info,
                title: 'Privacy',
                description: 'Your data stays on your device',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountStatusTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final dynamic icon;
  final bool isSignedIn;

  const _AccountStatusTile({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.isSignedIn,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: isSignedIn
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            size: 20,
          ),
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
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSignedIn
                  ? Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withOpacity(0.1)
                  : Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isSignedIn ? 'Connected' : 'Offline',
              style: TextStyle(
                fontSize: 12,
                color: isSignedIn
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryInfoTile extends StatelessWidget {
  final String title;
  final String description;
  final dynamic icon;

  const _LibraryInfoTile({
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
