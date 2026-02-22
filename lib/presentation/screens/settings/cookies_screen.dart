import 'package:curio/core/services/content/sync.dart';
import 'package:file_picker/file_picker.dart';
import 'package:curio/presentation/common/progress_indicators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'dart:io';

import '../setup/google_login_screen.dart';

class CookiesScreen extends ConsumerWidget {
  const CookiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cookies'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImportSection(context, ref),
            const Gap(24),
            // Cookie List Section
            if (syncState.accounts.isNotEmpty) ...[
              Text(
                'Imported Cookies',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Gap(12),
              _CookiesList(
                accounts: syncState.accounts,
                activeAccount: syncState.activeAccount,
                ref: ref,
              ),
            ] else ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Symbols.cookie, size: 48, color: Colors.grey),
                      Gap(16),
                      Text('No cookies imported yet'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImportSection(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _ImportActionTile(
              icon: Symbols.upload,
              title: 'Import cookies file',
              subtitle: 'Select a cookies.txt file',
              onTap: () => _importCookiesFile(context, ref),
            ),
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
            _ImportActionTile(
              icon: Symbols.folder,
              title: 'Import cookies from folder',
              subtitle: 'Import all .txt cookie files in a folder',
              onTap: () => _importCookiesFolder(context, ref),
            ),
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
            _ImportActionTile(
              icon: Symbols.account_circle,
              title: 'Sign in with Google',
              subtitle: 'Use yt-dlp login to fetch cookies',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const GoogleLoginScreen(forceFreshLogin: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importCookiesFile(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        dialogTitle: 'Select cookies file',
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;

        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const AlertDialog(
              content: Row(
                children: [
                  M3CircularProgressIndicator(),
                  Gap(16),
                  Text('Importing cookies...'),
                ],
              ),
            ),
          );
        }

        try {
          await ref.read(syncServiceProvider.notifier).importCookies(filePath);

          if (context.mounted) {
            Navigator.pop(context); // Close loading
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Cookies imported successfully!'),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.pop(context); // Close loading
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to import cookies: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importCookiesFolder(BuildContext context, WidgetRef ref) async {
    try {
      final dirPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select cookies folder',
      );

      if (dirPath == null) return;

      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected folder does not exist'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final cookieFiles = await dir
          .list(recursive: false)
          .where((e) => e is File && e.path.toLowerCase().endsWith('.txt'))
          .cast<File>()
          .toList();

      if (cookieFiles.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No .txt cookie files found in this folder'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Row(
              children: [
                const M3CircularProgressIndicator(),
                const Gap(16),
                Text('Importing ${cookieFiles.length} file(s)...'),
              ],
            ),
          ),
        );
      }

      int successCount = 0;
      for (final f in cookieFiles) {
        try {
          await ref.read(syncServiceProvider.notifier).importCookies(f.path);
          successCount++;
        } catch (_) {}
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported $successCount/${cookieFiles.length} cookie file(s)',
            ),
            backgroundColor: successCount > 0
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting folder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _ImportActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ImportActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
              const Gap(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Symbols.arrow_forward,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CookiesList extends StatelessWidget {
  final List<dynamic> accounts;
  final dynamic activeAccount;
  final WidgetRef ref;

  const _CookiesList({
    required this.accounts,
    required this.activeAccount,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: accounts.asMap().entries.map((entry) {
          final index = entry.key;
          final account = entry.value;
          final isActive = account.id == activeAccount?.id;
          final isLast = index == accounts.length - 1;

          return Column(
            children: [
              InkWell(
                onTap: isActive
                    ? null
                    : () {
                        ref
                            .read(syncServiceProvider.notifier)
                            .switchAccount(account.id);
                      },
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(16) : Radius.zero,
                  bottom: isLast ? const Radius.circular(16) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Symbols.cookie,
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      const Gap(16),
                      Expanded(
                        child: Text(
                          'Cookie ${index + 1}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isActive
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else ...[
                        IconButton(
                          onPressed: () =>
                              _deleteAccount(context, account, index),
                          icon: Icon(
                            Symbols.delete,
                            color: Theme.of(context).colorScheme.error,
                            size: 20,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 68,
                  endIndent: 16,
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _deleteAccount(BuildContext context, dynamic account, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Cookie'),
        content: Text('Are you sure you want to remove "Cookie ${index + 1}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(syncServiceProvider.notifier).removeAccount(account.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Cookies removed successfully'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
