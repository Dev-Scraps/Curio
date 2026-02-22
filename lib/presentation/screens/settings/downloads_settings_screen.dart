import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/services/storage/storage.dart';
import 'widgets/settings_widgets.dart';
import 'widgets/responsive_dialog.dart';

class DownloadsSettingsScreen extends ConsumerWidget {
  const DownloadsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Downloads'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Download Quality Section
          const SectionHeader(title: 'DOWNLOAD QUALITY'),
          const Gap(8),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Symbols.download,
                title: 'Download Quality',
                subtitle: storage.downloadQuality,
                onTap: () => _showQualityDialog(context, ref),
              ),
            ],
          ),
          const Gap(24),

          // YouTube PO Token Section
          const SectionHeader(title: 'YOUTUBE ACCESS'),
          const Gap(8),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Symbols.key,
                title: 'PO Token (Android Client)',
                subtitle: (storage.ytdlpPoToken ?? '').isNotEmpty
                    ? 'Configured'
                    : 'Not set',
                onTap: () => _showPoTokenDialog(context, ref),
              ),
            ],
          ),
          const Gap(24),

          // Download Location Section
          const SectionHeader(title: 'DOWNLOAD LOCATION'),
          const Gap(8),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Symbols.folder_open,
                title: 'Download Location',
                subtitle: _truncatePath(
                  storage.downloadPath.isEmpty
                      ? 'Download/Curio (Default)'
                      : storage.downloadPath,
                ),
                onTap: () => _showDownloadLocationDialog(context, ref),
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
                title: 'Quality vs Size',
                description: 'Higher quality uses more storage space',
              ),
              const Divider(height: 1, indent: 56),
              _TipTile(
                icon: Icons.info,
                title: 'External Storage',
                description: 'Choose SD card for large downloads',
              ),
              const Divider(height: 1, indent: 56),
              _TipTile(
                icon: Icons.info,
                title: 'Backup Downloads',
                description: 'Move important downloads to cloud storage',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPoTokenDialog(BuildContext context, WidgetRef ref) {
    final storage = ref.read(storageServiceProvider);
    final controller = TextEditingController(text: storage.ytdlpPoToken ?? '');

    context.showResponsiveDialog(
      title: 'YouTube PO Token',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paste your PO token to enable Android client formats. Leave empty to use web client.',
            style: TextStyle(fontSize: 14),
          ),
          const Gap(16),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'PO token (optional)',
              labelText: 'PO Token',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            storage.setYtdlpPoToken(controller.text.trim());
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PO token updated'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _showQualityDialog(BuildContext context, WidgetRef ref) {
    final storage = ref.read(storageServiceProvider);
    final current = storage.downloadQuality;
    final options = ['Best', '1080p', '720p', '480p', '360p', 'Worst'];

    context
        .showSelectionDialog<String>(
          title: 'Download Quality',
          items: options,
          itemBuilder: (option) => Text(option),
          initialValue: current,
          confirmText: 'Select',
        )
        .then((selected) {
          if (selected != null) {
            storage.setDownloadQuality(selected);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Download quality updated'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
  }

  void _showDownloadLocationDialog(BuildContext context, WidgetRef ref) {
    final storage = ref.read(storageServiceProvider);
    final controller = TextEditingController(text: storage.downloadPath);

    context.showResponsiveDialog(
      title: 'Download Location',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose where to save downloaded files. Leave empty to use default Download/Curio folder.',
            style: TextStyle(fontSize: 14),
          ),
          const Gap(16),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Leave empty for default',
              labelText: 'Custom Path (Optional)',
              suffixIcon: IconButton(
                icon: const Icon(Icons.cancel, color: Colors.grey, size: 18),
                onPressed: () => controller.clear(),
              ),
            ),
          ),
          const Gap(12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final path = await FilePicker.platform.getDirectoryPath();
                    if (path != null) {
                      controller.text = path;
                    }
                  },
                  icon: const Icon(Icons.folder),
                  label: const Text('Browse'),
                ),
              ),
              const Gap(8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => controller.clear(),
                  child: const Text('Use Default'),
                ),
              ),
            ],
          ),
          const Gap(8),
          Text(
            'Note: A "Curio" subfolder will be created automatically.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            storage.setDownloadPath(controller.text);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Download location updated'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _truncatePath(String path) {
    if (path.length <= 35) return path;
    return '...${path.substring(path.length - 32)}';
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
