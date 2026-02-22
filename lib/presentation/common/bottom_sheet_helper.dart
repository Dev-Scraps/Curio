import 'dart:ui';
import 'package:flutter/material.dart';

class BottomSheetHelper {
  /// Shows a bottom sheet with rounded corners and smooth animation
  static Future<T?> show<T>({
    required BuildContext context,
    Widget? child,
    Widget Function(BuildContext, ScrollController)? builder,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    String? title,
    ScrollController? scrollController,
    double initialChildSize = 0.5,
    double minChildSize = 0.3,
    double maxChildSize = 0.65,
  }) {
    assert(
      child != null || builder != null,
      'Either child or builder must be provided',
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (context) {
        final isLandscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;

        return DraggableScrollableSheet(
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          builder: (context, currentScrollController) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.95),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                      spreadRadius: -5,
                    ),
                  ],
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom,
                  left: isLandscape
                      ? MediaQuery.sizeOf(context).width * 0.2
                      : 0,
                  right: isLandscape
                      ? MediaQuery.sizeOf(context).width * 0.2
                      : 0,
                ),
                child: Column(
                  children: [
                    if (enableDrag)
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    if (title != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          title,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.75,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Builder(
                        builder: (innerContext) {
                          if (builder != null) {
                            return builder(
                              innerContext,
                              currentScrollController,
                            );
                          }
                          return child is Scrollable
                              ? child
                              : SingleChildScrollView(
                                  controller:
                                      scrollController ??
                                      currentScrollController,
                                  child: child,
                                );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Shows a confirmation bottom sheet
  static Future<bool> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final theme = Theme.of(context);
    final result = await show<bool>(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(cancelText),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: isDestructive
                        ? FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                          )
                        : null,
                    child: Text(confirmText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }
}
