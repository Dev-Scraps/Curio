import 'package:curio/core/services/storage/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

final _fontFamilyTriggerProvider = StreamProvider<int>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.changes
      .where((key) => key == StorageService.keyFontFamily)
      .map((_) => DateTime.now().microsecondsSinceEpoch);
});

/// Provider for current font family (SAFE)
final fontFamilyProvider = Provider<String>((ref) {
  ref.watch(_fontFamilyTriggerProvider);
  final storage = ref.watch(storageServiceProvider);

  // 🚨 MUST handle null (app startup)
  return storage.fontFamily;
});

/// Provider for TextTheme based on selected font (SAFE)
final textThemeProvider = Provider<TextTheme>((ref) {
  final fontFamily = ref.watch(fontFamilyProvider);

  switch (fontFamily) {
    case 'Baloo Bhai 2':
      return GoogleFonts.balooBhai2TextTheme();
    case 'Baloo 2':
      return GoogleFonts.baloo2TextTheme();
    case 'Roboto':
      return GoogleFonts.robotoTextTheme();
    case 'Poppins':
      return GoogleFonts.poppinsTextTheme();
    case 'Montserrat':
      return GoogleFonts.montserratTextTheme();
    case 'Lato':
      return GoogleFonts.latoTextTheme();
    case 'Open Sans':
      return GoogleFonts.openSansTextTheme();
    case 'Raleway':
      return GoogleFonts.ralewayTextTheme();
    case 'Nunito':
      return GoogleFonts.nunitoTextTheme();
    case 'Playfair Display':
      return GoogleFonts.playfairDisplayTextTheme();
    case 'Merriweather':
      return GoogleFonts.merriweatherTextTheme();
    case 'Oswald':
      return GoogleFonts.oswaldTextTheme();
    case 'Ubuntu':
      return GoogleFonts.ubuntuTextTheme();
    case 'Bebas Neue':
      return GoogleFonts.bebasNeueTextTheme();
    case 'Dancing Script':
      return GoogleFonts.dancingScriptTextTheme();
    case 'Pacifico':
      return GoogleFonts.pacificoTextTheme();
    case 'Inter':
      return GoogleFonts.interTextTheme();
    default:
      return GoogleFonts.balooBhai2TextTheme();
  }
});

/// Available font families with display names
const List<FontOption> availableFonts = [
  FontOption('Baloo Bhai 2', 'Baloo Bhai 2', 'Default • Rounded & Friendly'),
  FontOption('Baloo 2', 'Baloo 2', 'Rounded & Modern'),
  FontOption('Inter', 'Inter', 'Modern & Clean'),
  FontOption('Roboto', 'Roboto', 'Google Standard'),
  FontOption('Poppins', 'Poppins', 'Geometric & Friendly'),
  FontOption('Montserrat', 'Montserrat', 'Urban & Bold'),
  FontOption('Lato', 'Lato', 'Clear & Professional'),
  FontOption('Open Sans', 'Open Sans', 'Humanist & Optimized'),
  FontOption('Raleway', 'Raleway', 'Elegant & Stylish'),
  FontOption('Nunito', 'Nunito', 'Rounded & Friendly'),
  FontOption('Playfair Display', 'Playfair Display', 'Classic & Serif'),
  FontOption('Merriweather', 'Merriweather', 'Readable & Serif'),
  FontOption('Oswald', 'Oswald', 'Bold & Condensed'),
  FontOption('Ubuntu', 'Ubuntu', 'Modern & Friendly'),
  FontOption('Bebas Neue', 'Bebas Neue', 'Bold & Display'),
  FontOption('Dancing Script', 'Dancing Script', 'Elegant & Script'),
  FontOption('Pacifico', 'Pacifico', 'Casual & Rounded'),
];

/// Font option with display name and description
class FontOption {
  final String displayName;
  final String fontName;
  final String description;

  const FontOption(this.displayName, this.fontName, this.description);

  TextTheme getTextTheme() {
    switch (fontName) {
      case 'Baloo Bhai 2':
        return GoogleFonts.balooBhai2TextTheme();
      case 'Baloo 2':
        return GoogleFonts.baloo2TextTheme();
      case 'Roboto':
        return GoogleFonts.robotoTextTheme();
      case 'Poppins':
        return GoogleFonts.poppinsTextTheme();
      case 'Montserrat':
        return GoogleFonts.montserratTextTheme();
      case 'Lato':
        return GoogleFonts.latoTextTheme();
      case 'Open Sans':
        return GoogleFonts.openSansTextTheme();
      case 'Raleway':
        return GoogleFonts.ralewayTextTheme();
      case 'Nunito':
        return GoogleFonts.nunitoTextTheme();
      case 'Playfair Display':
        return GoogleFonts.playfairDisplayTextTheme();
      case 'Merriweather':
        return GoogleFonts.merriweatherTextTheme();
      case 'Oswald':
        return GoogleFonts.oswaldTextTheme();
      case 'Ubuntu':
        return GoogleFonts.ubuntuTextTheme();
      case 'Bebas Neue':
        return GoogleFonts.bebasNeueTextTheme();
      case 'Dancing Script':
        return GoogleFonts.dancingScriptTextTheme();
      case 'Pacifico':
        return GoogleFonts.pacificoTextTheme();
      case 'Inter':
        return GoogleFonts.interTextTheme();
      default:
        return GoogleFonts.balooBhai2TextTheme();
    }
  }
}
