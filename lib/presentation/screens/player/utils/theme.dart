import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlayerTheme {
  static void setPlayerSystemUI(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  static void setFullscreenSystemUI() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  static void setPortraitSystemUI() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  static void resetSystemUI() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  static BoxDecoration getGradientDecoration(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                Colors.black.withOpacity(0.9),
                Colors.black.withOpacity(0.5),
                Colors.transparent,
              ]
            : [
                Colors.black.withOpacity(0.7),
                Colors.black.withOpacity(0.3),
                Colors.transparent,
              ],
      ),
    );
  }

  static BoxDecoration getControlDecoration({
    required BuildContext context,
    required double opacity,
    BoxShape shape = BoxShape.circle,
  }) {
    final theme = Theme.of(context);

    return BoxDecoration(color: Colors.transparent, shape: shape);
  }

  static TextStyle getButtonTextStyle({
    required BuildContext context,
    required double fontSize,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return TextStyle(
      color: Colors.white,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  static TextStyle getTitleTextStyle({
    required BuildContext context,
    required double fontSize,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return TextStyle(
      color: Colors.white,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  static TextStyle getSubtitleTextStyle({
    required BuildContext context,
    required double fontSize,
  }) {
    return TextStyle(color: Colors.white.withOpacity(0.8), fontSize: fontSize);
  }

  static SliderThemeData getSliderTheme(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return SliderThemeData(
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(
        enabledThumbRadius: 6,
        elevation: 1,
      ),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
      activeTrackColor: primaryColor,
      inactiveTrackColor: theme.colorScheme.onSurface.withOpacity(0.3),
      thumbColor: primaryColor,
    );
  }

  static EdgeInsets getResponsivePadding({
    required bool isCompact,
    double? horizontal,
    double? vertical,
  }) {
    final defaultHorizontal = isCompact ? 12.0 : 16.0;
    final defaultVertical = isCompact ? 8.0 : 12.0;

    return EdgeInsets.symmetric(
      horizontal: horizontal ?? defaultHorizontal,
      vertical: vertical ?? defaultVertical,
    );
  }

  static double getResponsiveSize({
    required bool isCompact,
    required double compactSize,
    required double normalSize,
  }) {
    return isCompact ? compactSize : normalSize;
  }

  static double getResponsiveFontSize({
    required bool isCompact,
    required double compactSize,
    required double normalSize,
  }) {
    return isCompact ? compactSize : normalSize;
  }

  static Color getIconColor(BuildContext context) {
    return Colors.white;
  }

  static Color getPrimaryColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.colorScheme.primary;
  }

  static Color getOnPrimaryColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.colorScheme.onPrimary;
  }

  static Color getSurfaceColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.colorScheme.surface;
  }

  static Color getOnSurfaceColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.colorScheme.onSurface;
  }
}
