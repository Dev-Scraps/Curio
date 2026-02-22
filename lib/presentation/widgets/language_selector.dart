import 'package:curio/presentation/common/progress_indicators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../l10n/app_localizations.dart';
import '../providers/language_provider.dart';

class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocaleAsync = ref.watch(languageProvider);
    final supportedLocales = ref.watch(supportedLocalesProvider);
    final l10n = AppLocalizations.of(context)!;

    return currentLocaleAsync.when(
      data: (currentLocale) {
        return ListTile(
          leading: HugeIcon(
            icon: HugeIcons.strokeRoundedHome02,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 24,
          ),
          title: Text(l10n.language),
          subtitle: Text(_getLanguageDisplayName(currentLocale)),
          trailing: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowRight01,
            color: Colors.grey,
            size: 20,
          ),
          onTap: () => _showLanguageDialog(
            context,
            ref,
            currentLocale,
            supportedLocales,
            l10n,
          ),
        );
      },
      loading: () => ListTile(
        leading: HugeIcon(
          icon: HugeIcons.strokeRoundedHome02,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 24,
        ),
        title: Text(l10n.language),
        subtitle: const LinearProgressIndicator(),
      ),
      error: (_, __) => ListTile(
        leading: HugeIcon(
          icon: HugeIcons.strokeRoundedHome02,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 24,
        ),
        title: Text(l10n.language),
        subtitle: const Text('Error loading language'),
      ),
    );
  }

  String _getLanguageDisplayName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'hi':
        return 'हिन्दी';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      case 'zh':
        return '中文';
      case 'ja':
        return '日本語';
      case 'ar':
        return 'العربية';
      case 'pt':
        return 'Português';
      default:
        return locale.languageCode.toUpperCase();
    }
  }

  void _showLanguageDialog(
    BuildContext context,
    WidgetRef ref,
    Locale currentLocale,
    List<Locale> supportedLocales,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.language),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: supportedLocales.length,
              itemBuilder: (context, index) {
                final locale = supportedLocales[index];
                final isSelected =
                    locale.languageCode == currentLocale.languageCode;

                return RadioListTile<Locale>(
                  title: Text(_getLanguageDisplayName(locale)),
                  subtitle: Text(_getNativeLanguageName(locale)),
                  value: locale,
                  groupValue: currentLocale,
                  onChanged: (Locale? newLocale) {
                    if (newLocale != null) {
                      ref
                          .read(languageProvider.notifier)
                          .setLanguage(newLocale);
                      Navigator.of(context).pop();
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  String _getNativeLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'hi':
        return 'हिन्दी';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      case 'zh':
        return '中文';
      case 'ja':
        return '日本語';
      case 'ar':
        return 'العربية';
      case 'pt':
        return 'Português';
      default:
        return locale.languageCode.toUpperCase();
    }
  }
}

class LanguageSelectorBottomSheet extends ConsumerWidget {
  const LanguageSelectorBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocaleAsync = ref.watch(languageProvider);
    final supportedLocales = ref.watch(supportedLocalesProvider);
    final l10n = AppLocalizations.of(context)!;

    return currentLocaleAsync.when(
      data: (currentLocale) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          l10n.language,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: supportedLocales.length,
                      itemBuilder: (context, index) {
                        final locale = supportedLocales[index];
                        final isSelected =
                            locale.languageCode == currentLocale.languageCode;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSelected
                                ? Theme.of(context).primaryColor
                                : Theme.of(context).dividerColor,
                            child: Text(
                              _getLanguageFlag(locale),
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                          title: Text(_getLanguageDisplayName(locale)),
                          subtitle: Text(_getNativeLanguageName(locale)),
                          trailing: isSelected
                              ? HugeIcon(
                                  icon: HugeIcons.strokeRoundedFavourite,
                                  color: Theme.of(context).primaryColor,
                                  size: 20,
                                )
                              : null,
                          onTap: () {
                            ref
                                .read(languageProvider.notifier)
                                .setLanguage(locale);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: M3CircularProgressIndicator()),
      error: (_, __) => Center(child: Text('Error loading languages')),
    );
  }

  String _getLanguageDisplayName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'hi':
        return 'हिन्दी';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      case 'zh':
        return '中文';
      case 'ja':
        return '日本語';
      case 'ar':
        return 'العربية';
      case 'pt':
        return 'Português';
      default:
        return locale.languageCode.toUpperCase();
    }
  }

  String _getNativeLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'hi':
        return 'हिन्दी';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      case 'zh':
        return '中文';
      case 'ja':
        return '日本語';
      case 'ar':
        return 'العربية';
      case 'pt':
        return 'Português';
      default:
        return locale.languageCode.toUpperCase();
    }
  }

  String _getLanguageFlag(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return '🇺🇸';
      case 'es':
        return '🇪🇸';
      case 'hi':
        return '🇮🇳';
      case 'fr':
        return '🇫🇷';
      case 'de':
        return '🇩🇪';
      case 'zh':
        return '🇨🇳';
      case 'ja':
        return '🇯🇵';
      case 'ar':
        return '🇸🇦';
      case 'pt':
        return '🇧🇷';
      default:
        return '🌐';
    }
  }
}
