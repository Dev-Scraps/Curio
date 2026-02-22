import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../l10n/app_localizations.dart';
import '../providers/font_provider.dart';
import '../../core/services/storage/storage.dart';
import '../common/bottom_sheet_helper.dart';

class FontSelector extends ConsumerWidget {
  const FontSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFont = ref.watch(fontFamilyProvider);
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      leading: Icon(
        Symbols.text_format,
        color: Theme.of(context).primaryColor,
        size: 24,
      ),
      title: Text(l10n.font),
      subtitle: Text(currentFont),
      trailing: const Icon(Symbols.arrow_forward, color: Colors.grey, size: 20),
      onTap: () => _showFontDialog(context, ref, currentFont, l10n),
    );
  }

  void _showFontDialog(
    BuildContext context,
    WidgetRef ref,
    String currentFont,
    AppLocalizations l10n,
  ) {
    BottomSheetHelper.show(
      context: context,
      title: l10n.font,
      builder: (context, scrollController) =>
          _FontSelectionContent(scrollController: scrollController),
    );
  }
}

class _FontSelectionContent extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const _FontSelectionContent({required this.scrollController});

  @override
  ConsumerState<_FontSelectionContent> createState() =>
      _FontSelectionContentState();
}

class _FontSelectionContentState extends ConsumerState<_FontSelectionContent> {
  @override
  Widget build(BuildContext context) {
    final currentFont = ref.watch(fontFamilyProvider);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // Font List - Simplified to show only font name in that style
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: availableFonts.length,
            itemBuilder: (context, index) {
              final fontOption = availableFonts[index];
              final isSelected = currentFont == fontOption.displayName;

              return _SimpleFontTile(
                fontOption: fontOption,
                isSelected: isSelected,
                onTap: () {
                  ref
                      .read(storageServiceProvider)
                      .setFontFamily(fontOption.displayName);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SimpleFontTile extends StatelessWidget {
  final FontOption fontOption;
  final bool isSelected;
  final VoidCallback onTap;

  const _SimpleFontTile({
    required this.fontOption,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Font name displayed in its own style
            Expanded(
              child: Text(
                fontOption.displayName,
                style: fontOption.getTextTheme().titleMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            // Selection indicator
            if (isSelected)
              Icon(
                Symbols.check_circle,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
