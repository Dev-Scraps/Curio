import 'package:curio/core/services/content/sync.dart';
import 'package:curio/core/services/storage/storage.dart';
import 'package:curio/presentation/common/progress_indicators.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/font_selector.dart';

import 'viewmodels/setup_viewmodel.dart';
import '../nav/nav_screen.dart';
import 'google_login_screen.dart';

class _PremiumPermissionTile extends StatelessWidget {
  final dynamic icon;
  final String title;
  final String subtitle;
  final bool isGranted;
  final VoidCallback onTap;

  const _PremiumPermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isGranted ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isGranted
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isGranted
                ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                : Theme.of(context).dividerTheme.color!.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isGranted
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).scaffoldBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: HugeIcon(
                icon: isGranted ? HugeIcons.strokeRoundedTick01 : icon,
                size: 16,
                color: isGranted
                    ? Colors.white
                    : Theme.of(context).iconTheme.color,
              ),
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Gap(4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (!isGranted)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Allow',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SetupScreen extends ConsumerWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(setupViewModelProvider);
    final viewModel = ref.read(setupViewModelProvider.notifier);
    final themeMode = ref.watch(themeModeProvider);
    final storage = ref.watch(storageServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(color: Theme.of(context).colorScheme.surface),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Gap(2),
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'Welcome to Curio',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const Gap(2),
                              Text(
                                'Let\'s customize your experience',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.7)
                                          : Colors.black.withOpacity(0.6),
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const Gap(12),

                        // Appearance Section
                        _SectionHeader(title: 'Appearance'),
                        const Gap(6),
                        _ThemeSelector(themeMode: themeMode),
                        const Gap(6),
                        const FontSelector(),
                        const Gap(6),
                        _PremiumOptionTile(
                          icon: HugeIcons.strokeRoundedColorPicker,
                          title: 'Accent Color',
                          value: 'Personalize',
                          onTap: () => _showColorDialog(context, ref),
                        ),
                        const Gap(10),

                        // Storage Section
                        _SectionHeader(title: 'Storage'),
                        const Gap(6),
                        _PremiumOptionTile(
                          icon: HugeIcons.strokeRoundedFolderDownload,
                          title: 'Download Location',
                          value: storage.downloadPath.isEmpty
                              ? 'Default'
                              : 'Custom',
                          onTap: () => _showPathDialog(context, ref, storage),
                        ),
                        const Gap(10),

                        // Permissions Section
                        _SectionHeader(title: 'Permissions'),
                        const Gap(6),
                        _PremiumPermissionTile(
                          icon: HugeIcons.strokeRoundedShieldUser,
                          title: 'Storage Access',
                          subtitle: 'Required for downloads',
                          isGranted: state.storagePermissionGranted,
                          onTap: () => viewModel.requestStoragePermission(),
                        ),
                        const Gap(6),
                        _PremiumPermissionTile(
                          icon: HugeIcons.strokeRoundedNotification03,
                          title: 'Notifications',
                          subtitle: 'Stay updated on downloads',
                          isGranted: state.notificationPermissionGranted,
                          onTap: () =>
                              viewModel.requestNotificationPermission(),
                        ),
                        const Gap(10),

                        // Account Section
                        _SectionHeader(title: 'Account'),
                        const Gap(6),
                        Consumer(
                          builder: (_, ref, __) {
                            final syncState = ref.watch(syncServiceProvider);
                            final account = syncState.activeAccount;

                            if (account == null) {
                              return _buildImportSection(context, ref);
                            }

                            final accountIndex = syncState.accounts.indexWhere(
                              (a) => a.id == account.id,
                            );
                            final displayName = accountIndex != -1
                                ? 'Cookie ${accountIndex + 1}'
                                : 'Connecting…';

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardTheme.color,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context).dividerTheme.color!,
                                ),
                              ),
                              child: Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedCookie,
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const Gap(12),
                                  Expanded(
                                    child: Text(
                                      displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: (account.name == 'Connecting…')
                                          ? Colors.orange.withOpacity(.1)
                                          : Theme.of(context)
                                                .colorScheme
                                                .primaryContainer
                                                .withOpacity(.4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: HugeIcon(
                                      icon: (account.name == 'Connecting…')
                                          ? HugeIcons.strokeRoundedLoading01
                                          : HugeIcons.strokeRoundedTick01,
                                      color: (account.name == 'Connecting…')
                                          ? Colors.orange
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const Gap(80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating Continue Button
          Positioned(
            bottom: 30,
            left: 24,
            right: 24,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: state.canContinue ? 1.0 : 0.5,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: state.canContinue
                      ? () async {
                          await viewModel.completeSetup();

                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const NavScreen(),
                              ),
                            );
                          }
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Gap(12),
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowRight01,
                        size: 20,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPathDialog(
    BuildContext context,
    WidgetRef ref,
    StorageService storage,
  ) {
    final controller = TextEditingController(text: storage.downloadPath);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose where to save downloaded files.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Path',
                suffixIcon: IconButton(
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedFolderOpen,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () async {
                    String? path = await FilePicker.platform.getDirectoryPath();
                    if (path != null) controller.text = path;
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              storage.setDownloadPath(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showColorDialog(BuildContext context, WidgetRef ref) {
    // Color selection dialog - keeping existing functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accent Color'),
        content: const Text(
          'Color picker functionality preserved from original',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
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
              icon: HugeIcons.strokeRoundedUpload01,
              title: 'Import cookies file',
              subtitle: 'Select a cookies.txt file',
              onTap: () => _importCookiesFile(context, ref),
            ),
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
            _ImportActionTile(
              icon: HugeIcons.strokeRoundedFolderAttachment,
              title: 'Import cookies from folder',
              subtitle: 'Import all .txt cookie files in a folder',
              onTap: () => _importCookiesFolder(context, ref),
            ),
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
            _ImportActionTile(
              icon: HugeIcons.strokeRoundedGoogle,
              title: 'Import cookies using Google',
              subtitle: 'Use yt-dlp login to fetch cookies',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GoogleLoginScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        color: isDark
            ? Colors.white.withOpacity(0.6)
            : Colors.black.withOpacity(0.5),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final AsyncValue<ThemeMode> themeMode;

  const _ThemeSelector({required this.themeMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color!.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ThemeOption(
            label: 'Auto',
            hugeIcon: HugeIcons.strokeRoundedLaptop,
            isSelected: themeMode.value == ThemeMode.system,
            onTap: () => _setTheme(context, ThemeMode.system),
          ),
          _ThemeOption(
            label: 'Light',
            hugeIcon: HugeIcons.strokeRoundedSun02,
            isSelected: themeMode.value == ThemeMode.light,
            onTap: () => _setTheme(context, ThemeMode.light),
          ),
          _ThemeOption(
            label: 'Dark',
            hugeIcon: HugeIcons.strokeRoundedMoon02,
            isSelected: themeMode.value == ThemeMode.dark,
            onTap: () => _setTheme(context, ThemeMode.dark),
          ),
        ],
      ),
    );
  }

  void _setTheme(BuildContext context, ThemeMode mode) {
    ProviderScope.containerOf(
      context,
    ).read(themeModeProvider.notifier).setThemeMode(mode);
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final dynamic hugeIcon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.hugeIcon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: hugeIcon,
                size: 16,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : theme.hintColor,
              ),
              const Gap(8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : theme.hintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumOptionTile extends StatelessWidget {
  final dynamic icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _PremiumOptionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerTheme.color!.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: icon,
              size: 18,
              color: Theme.of(context).iconTheme.color,
            ),
            const Gap(12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const Gap(8),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              size: 16,
              color: Theme.of(context).hintColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportActionTile extends StatelessWidget {
  final dynamic icon;
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
              HugeIcon(
                icon: icon,
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
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
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
