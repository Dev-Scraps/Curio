import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/services/storage/database.dart';
import '../../../core/services/storage/storage.dart';
import '../../../core/services/system/permissions.dart';
import '../../providers/playlists_provider.dart';
import '../../providers/videos_provider.dart';
import 'widgets/settings_widgets.dart';

class DataManagementScreen extends ConsumerWidget {
  const DataManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data & Storage'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Backup & Restore Section
          const SectionHeader(title: 'BACKUP & RESTORE'),
          const Gap(8),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Symbols.upload,
                title: 'Backup Database',
                subtitle: 'Save your data to external storage',
                onTap: () => _backupDatabase(context, ref),
              ),
              const Divider(height: 1, indent: 56),
              SettingsTile(
                icon: Symbols.download,
                title: 'Restore Database',
                subtitle: 'Restore from backup file',
                onTap: () => _restoreDatabase(context, ref),
              ),
            ],
          ),
          const Gap(24),

          // Data Management Section
          const SectionHeader(title: 'DATA MANAGEMENT'),
          const Gap(8),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Symbols.delete,
                title: 'Clear Data',
                subtitle: 'Remove all video and playlist data',
                iconColor: Colors.red,
                onTap: () => _clearData(context, ref),
              ),
            ],
          ),
          const Gap(24),

          // Warnings Section
          const SectionHeader(title: 'IMPORTANT NOTES'),
          const Gap(8),
          SettingsCard(
            children: [
              _WarningTile(
                icon: Icons.info,
                title: 'Backup First',
                description: 'Always backup before clearing data',
              ),
              const Divider(height: 1, indent: 56),
              _WarningTile(
                icon: Icons.info,
                title: 'Restore Requires Restart',
                description: 'App restart needed after restore',
              ),
              const Divider(height: 1, indent: 56),
              _WarningTile(
                icon: Icons.info,
                title: 'Cloud Sync',
                description: 'Consider cloud backup for important data',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _backupDatabase(BuildContext context, WidgetRef ref) async {
    final storage = ref.read(storageServiceProvider);
    final dbService = ref.read(databaseServiceProvider);
    final hasPerm = await ref
        .read(permissionServiceProvider)
        .requestStoragePermission();

    if (!hasPerm) return;

    try {
      final dbPath = await dbService.database.then((db) => db.path);

      // Use file picker to select backup location
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Backup Location',
        initialDirectory: storage.downloadPath.isNotEmpty
            ? storage.downloadPath
            : '/storage/emulated/0/Download',
      );

      if (selectedDirectory == null) {
        return; // User cancelled
      }

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final backupPath = '$selectedDirectory/Curio_backup_$timestamp.db';

      await File(dbPath).copy(backupPath);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Database backed up to: ${backupPath.split('/').last}',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restoreDatabase(BuildContext context, WidgetRef ref) async {
    final storage = ref.read(storageServiceProvider);
    final dbService = ref.read(databaseServiceProvider);
    final hasPerm = await ref
        .read(permissionServiceProvider)
        .requestStoragePermission();

    if (!hasPerm) return;

    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Database'),
        content: const Text(
          'This will replace your current database with the selected backup. This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Use file picker to select backup file
      debugPrint('Opening file picker for database restore...');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Database Backup File',
        type: FileType.any,
        initialDirectory: '/storage/emulated/0/Download',
      );

      debugPrint('File picker result: $result');

      if (result == null || result.files.single.path == null) {
        debugPrint('User cancelled or no file selected');
        return; // User cancelled
      }

      final selectedFile = result.files.single.path!;
      debugPrint('Selected file: $selectedFile');

      // Check if the selected file has .db extension
      if (!selectedFile.toLowerCase().endsWith('.db')) {
        debugPrint('Invalid file extension: $selectedFile');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a .db file'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final backupFile = File(result.files.single.path!);
      final dbPath = await dbService.database.then((db) => db.path);

      // Replace current database with backup
      await backupFile.copy(dbPath);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Database restored successfully! Please restart the app.',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 5),
          ),
        );

        // Trigger data refresh for all providers
        ref.invalidate(playlistsProvider);
        ref.invalidate(likedVideosProvider);
        ref.invalidate(watchLaterVideosProvider);
        ref.invalidate(downloadedVideosProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearData(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Data'),
        content: const Text(
          'This will delete all video and playlist data. You can re-sync anytime. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final db = ref.read(databaseServiceProvider);
                await db.database.then((database) async {
                  await database.delete('videos');
                  await database.delete('playlists');
                });

                ref.invalidate(playlistsProvider);
                ref.invalidate(likedVideosProvider);
                ref.invalidate(watchLaterVideosProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('✓ Data cleared'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _StorageInfoTile extends StatelessWidget {
  final String title;
  final String description;
  final dynamic icon;

  const _StorageInfoTile({
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

class _WarningTile extends StatelessWidget {
  final String title;
  final String description;
  final dynamic icon;

  const _WarningTile({
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
          Icon(icon, color: Colors.orange, size: 20),
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
