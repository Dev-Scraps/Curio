import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/services/storage/storage.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/font_selector.dart';
import 'widgets/settings_widgets.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Section
          const SectionHeader(title: 'THEME'),
          const Gap(8),
          SettingsCard(
            children: [
              SwitchTile(
                icon: Symbols.palette,
                title: 'Dynamic Color',
                value: storage.useDynamicColor,
                onChanged: (v) => storage.setUseDynamicColor(v),
              ),
              const Divider(height: 1, indent: 56),
              SettingsTile(
                icon: Symbols.colorize,
                title: 'Seed Color',
                subtitle: storage.useDynamicColor
                    ? 'Wallpaper'
                    : '#${storage.seedColor.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Color(storage.seedColor),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                ),
                onTap: storage.useDynamicColor
                    ? null
                    : () => _showSeedColorDialog(context, ref),
              ),
              const Divider(height: 1, indent: 56),
              SettingsTile(
                icon: Symbols.palette,
                title: 'Palette Style',
                subtitle: storage.paletteStyle.replaceFirst(
                  storage.paletteStyle[0],
                  storage.paletteStyle[0].toUpperCase(),
                ),
                onTap: () => _showPaletteStyleDialog(context, ref),
              ),
              const Divider(height: 1, indent: 56),
              SettingsTile(
                icon: Symbols.dark_mode,
                title: 'Theme Mode',
                subtitle: _getThemeModeName(
                  ref.watch(themeModeProvider).value ?? ThemeMode.system,
                ),
                onTap: () => _showThemeDialog(context, ref),
              ),
              const FontSelector(),
            ],
          ),
          const Gap(24),

          // Preview Section
          const SectionHeader(title: 'PREVIEW'),
          const Gap(8),
          SettingsCard(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sample Text',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const Gap(8),
                    Text(
                      'This is how your text will appear with the current theme and font settings.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Gap(12),
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Gap(8),
                        Text(
                          'Primary Color',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Spacer(),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Gap(8),
                        Text(
                          'Secondary Color',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  void _showSeedColorDialog(BuildContext context, WidgetRef ref) {
    final storage = ref.read(storageServiceProvider);
    final current = storage.seedColor;

    final presets = <int>[
      0xFF476810, // Green from palette
      0xFF68A500, // Light Green
      0xFF2E7D32, // Forest Green
      0xFF00695C, // Teal
      0xFF006064, // Cyan
      0xFF1565C0, // Blue
      0xFF283593, // Indigo
      0xFF6A1B9A, // Purple
      0xFF880E4F, // Pink
      0xFFC2185B, // Magenta
      0xFFD32F2F, // Red
      0xFFE64A19, // Deep Orange
      0xFFE6A700, // Orange
      0xFFF57F17, // Yellow
      0xFF827717, // Olive
      0xFF4E342E, // Brown
      0xFF37474F, // Blue Grey
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seed Color'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Color Preview Box
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: Color(current),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  '#${Color(current).value.toRadixString(16).substring(2).toUpperCase()}',
                  style: TextStyle(
                    color: Color(current).computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Preset Colors Grid
            SizedBox(
              width: double.maxFinite,
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: presets.length,
                itemBuilder: (context, index) {
                  final seed = presets[index];
                  final isSelected = seed == current;
                  return GestureDetector(
                    onTap: () async {
                      await storage.setSeedColor(seed);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(seed),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(seed).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 28,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _showFullColorPickerDialog(context, ref),
            child: const Text('Color Picker'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<int?> _promptForSeedColorHex(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom seed color'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g. FF68A500 or 68A500',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    final raw = result?.trim();
    if (raw == null || raw.isEmpty) return null;

    final cleaned = raw.startsWith('#') ? raw.substring(1) : raw;
    final hex = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    if (hex.length != 8) return null;

    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return parsed;
  }

  void _showPaletteStyleDialog(BuildContext context, WidgetRef ref) {
    final storage = ref.read(storageServiceProvider);
    final current = storage.paletteStyle;

    final styles = ['neutral', 'tonalspot', 'vibrant', 'expressive'];

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Palette Style'),
        children: styles
            .map(
              (style) => RadioListTile<String>(
                title: Text(
                  style.replaceFirst(style[0], style[0].toUpperCase()),
                ),
                value: style,
                groupValue: current,
                onChanged: (v) {
                  if (v != null) {
                    storage.setPaletteStyle(v);
                    Navigator.pop(context);
                  }
                },
              ),
            )
            .toList(),
      ),
    );
  }

  void _showFullColorPickerDialog(BuildContext context, WidgetRef ref) {
    final storage = ref.read(storageServiceProvider);
    Color pickerColor = Color(storage.seedColor);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Color Picker'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Color Preview Box
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: pickerColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '#${pickerColor.value.toRadixString(16).substring(2).toUpperCase()}',
                    style: TextStyle(
                      color: pickerColor.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Color Picker
              SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: pickerColor,
                  onColorChanged: (Color color) {
                    setState(() => pickerColor = color);
                  },
                  pickerAreaHeightPercent: 0.8,
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
              onPressed: () async {
                await storage.setSeedColor(pickerColor.value);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Select'),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(themeModeProvider).value;
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Theme Mode'),
        children: [
          RadioListTile<ThemeMode>(
            title: const Text('System'),
            value: ThemeMode.system,
            groupValue: current,
            onChanged: (v) {
              if (v != null) {
                ref.read(themeModeProvider.notifier).setThemeMode(v);
                Navigator.pop(context);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Light'),
            value: ThemeMode.light,
            groupValue: current,
            onChanged: (v) {
              if (v != null) {
                ref.read(themeModeProvider.notifier).setThemeMode(v);
                Navigator.pop(context);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Dark'),
            value: ThemeMode.dark,
            groupValue: current,
            onChanged: (v) {
              if (v != null) {
                ref.read(themeModeProvider.notifier).setThemeMode(v);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
