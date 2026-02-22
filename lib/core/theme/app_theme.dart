import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // -------------------------------
  // LIGHT THEME
  // -------------------------------
  static ThemeData lightTheme(
    TextTheme textTheme, {
    int? seedColor,
    ColorScheme? dynamicColorScheme,
  }) {
    final fallbackSeed = seedColor != null
        ? Color(seedColor)
        : const Color(0xFF476810); // Green seed color from palette
    final seed = fallbackSeed;

    final baseColorScheme =
        dynamicColorScheme ??
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: baseColorScheme.surfaceContainer,
      primaryColor: baseColorScheme.primary,
      colorScheme: baseColorScheme,

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return baseColorScheme.onPrimary;
          }
          return baseColorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return baseColorScheme.primary;
          }
          return baseColorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return baseColorScheme.primary;
          }
          return baseColorScheme.outline;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return baseColorScheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(baseColorScheme.onPrimary),
        side: BorderSide(color: baseColorScheme.outline),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return baseColorScheme.primary;
          }
          return baseColorScheme.outline;
        }),
      ),

      // Global Material Symbols Rounded font for all icons
      iconTheme: const IconThemeData(size: 24),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // ✅ TEXT — Proper contrast colors
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: textTheme.displayMedium?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: textTheme.headlineLarge?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: textTheme.titleSmall?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: baseColorScheme.onSurface,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: baseColorScheme.onSurface,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: baseColorScheme.onSurfaceVariant,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: textTheme.labelMedium?.copyWith(
          color: baseColorScheme.onSurfaceVariant,
        ),
        labelSmall: textTheme.labelSmall?.copyWith(
          color: baseColorScheme.onSurfaceVariant,
        ),
      ),

      // ✅ APP BAR — Vibrant with proper contrast
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: baseColorScheme.onSurface, size: 24),
        titleTextStyle: (textTheme.headlineSmall ?? const TextStyle()).copyWith(
          color: baseColorScheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),

      // ✅ CARDS
      cardTheme: CardThemeData(
        color: baseColorScheme.surface,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ✅ BUTTONS — Gradient style with dynamic color
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: baseColorScheme.primary,
          foregroundColor: baseColorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          elevation: 0,
        ),
      ),

      // ✅ INPUT FIELDS — Modern with accent
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: baseColorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: baseColorScheme.primary, width: 2),
        ),
        hintStyle: TextStyle(color: baseColorScheme.onSurfaceVariant),
        labelStyle: TextStyle(color: baseColorScheme.onSurface),
      ),
      dividerTheme: DividerThemeData(
        color: baseColorScheme.onSurfaceVariant.withOpacity(0.2),
      ),

      hintColor: baseColorScheme.onSurfaceVariant,

      // ✅ NAVIGATION BAR — Modern with accent using dynamic color
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: baseColorScheme.secondaryContainer,
        elevation: 0,
        height: 70,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: baseColorScheme.primary, size: 28);
          }
          return IconThemeData(
            color: baseColorScheme.onSurfaceVariant,
            size: 26,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return (textTheme.labelSmall ?? const TextStyle()).copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: baseColorScheme.primary,
            );
          }
          return (textTheme.labelSmall ?? const TextStyle()).copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: baseColorScheme.onSurfaceVariant,
          );
        }),
      ),

      // ✅ SNACKBAR — Vibrant
      snackBarTheme: SnackBarThemeData(
        backgroundColor: baseColorScheme.inverseSurface,
        contentTextStyle: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
          color: baseColorScheme.onInverseSurface,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: baseColorScheme.primary,
        linearTrackColor: baseColorScheme.surfaceContainerHighest,
        circularTrackColor: baseColorScheme.surfaceContainerHighest,
      ),

      // ✅ DIALOG THEME — Proper text colors
      dialogTheme: DialogThemeData(
        backgroundColor: baseColorScheme.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: (textTheme.titleLarge ?? const TextStyle()).copyWith(
          color: baseColorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
          color: baseColorScheme.onSurface,
          fontSize: 16,
        ),
      ),
    );
  }

  // -------------------------------
  // DARK THEME
  // -------------------------------
  static ThemeData darkTheme(
    TextTheme textTheme, {
    int? seedColor,
    ColorScheme? dynamicColorScheme,
  }) {
    final fallbackSeed = seedColor != null
        ? Color(seedColor)
        : const Color(0xFF476810); // Green seed color from palette
    final seed = fallbackSeed;

    final baseColorScheme =
        dynamicColorScheme ??
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: baseColorScheme.surfaceContainer,
      primaryColor: baseColorScheme.primary,
      colorScheme: baseColorScheme,

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return baseColorScheme.onPrimary;
          }
          return baseColorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return baseColorScheme.primary;
          }
          return baseColorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return baseColorScheme.primary;
          }
          return baseColorScheme.outline;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return baseColorScheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(baseColorScheme.onPrimary),
        side: BorderSide(color: baseColorScheme.outline),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return baseColorScheme.primary;
          }
          return baseColorScheme.outline;
        }),
      ),

      // Global Material Symbols Rounded font for all icons
      iconTheme: const IconThemeData(size: 24),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // ✅ TEXT — Bright white for visibility
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: textTheme.displayMedium?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: textTheme.headlineLarge?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: textTheme.titleSmall?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: baseColorScheme.onSurface,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: baseColorScheme.onSurface,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: baseColorScheme.onSurfaceVariant,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: textTheme.labelMedium?.copyWith(
          color: baseColorScheme.onSurfaceVariant,
        ),
        labelSmall: textTheme.labelSmall?.copyWith(
          color: baseColorScheme.onSurfaceVariant,
        ),
      ),

      // ✅ APP BAR — Bright white text and icons
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: baseColorScheme.onSurface, size: 24),
        titleTextStyle: (textTheme.headlineSmall ?? const TextStyle()).copyWith(
          color: baseColorScheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),

      // ✅ CARDS
      cardTheme: CardThemeData(
        color: baseColorScheme.surface,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ✅ BUTTONS — Vibrant gradient style with dynamic color
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: baseColorScheme.primary,
          foregroundColor: baseColorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          elevation: 0,
        ),
      ),

      // ✅ INPUT FIELDS — Proper contrast
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: baseColorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: baseColorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: baseColorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: baseColorScheme.primary, width: 2),
        ),
        hintStyle: TextStyle(color: baseColorScheme.onSurfaceVariant),
        labelStyle: TextStyle(color: baseColorScheme.onSurface),
      ),

      dividerTheme: DividerThemeData(
        color: baseColorScheme.onSurfaceVariant.withOpacity(0.2),
      ),

      hintColor: baseColorScheme.onSurfaceVariant,

      // ✅ NAVIGATION BAR — Vibrant with accent using dynamic color
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: baseColorScheme.secondaryContainer,
        elevation: 0,
        height: 70,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: baseColorScheme.primary, size: 28);
          }
          return IconThemeData(
            color: baseColorScheme.onSurfaceVariant,
            size: 26,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return (textTheme.labelSmall ?? const TextStyle()).copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: baseColorScheme.primary,
            );
          }
          return (textTheme.labelSmall ?? const TextStyle()).copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: baseColorScheme.onSurfaceVariant,
          );
        }),
      ),

      // ✅ SNACKBAR — Vibrant
      snackBarTheme: SnackBarThemeData(
        backgroundColor: baseColorScheme.surfaceContainerHighest,
        contentTextStyle: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: baseColorScheme.primary,
        linearTrackColor: baseColorScheme.surface,
        circularTrackColor: baseColorScheme.surface,
      ),

      // ✅ DIALOG THEME — Bright white text for visibility
      dialogTheme: DialogThemeData(
        backgroundColor: baseColorScheme.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: (textTheme.titleLarge ?? const TextStyle()).copyWith(
          color: baseColorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
          color: baseColorScheme.onSurface,
          fontSize: 16,
        ),
      ),
    );
  }
}
