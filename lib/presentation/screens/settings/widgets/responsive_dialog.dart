import 'package:curio/presentation/common/progress_indicators.dart';
import 'package:flutter/material.dart';

/// Enhanced dialog utility for perfectly sized and responsive dialogs
class ResponsiveDialog {
  /// Shows a responsive dialog that adapts to screen size and content
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    String? title,
    List<Widget>? actions,
    bool scrollable = true,
    double? maxWidth,
    double? maxHeight,
    EdgeInsets? contentPadding,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isDesktop = screenSize.width > 1200;

    // Calculate responsive dimensions
    final dialogMaxWidth =
        maxWidth ??
        (isDesktop
            ? 500
            : isTablet
            ? 400
            : screenSize.width * 0.9);
    final dialogMaxHeight = maxHeight ?? screenSize.height * 0.8;

    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final dialogWidth = constraints.maxWidth > dialogMaxWidth
              ? dialogMaxWidth
              : constraints.maxWidth;

          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: isDesktop
                  ? 24.0
                  : isTablet
                  ? 16.0
                  : 12.0,
              vertical: 24.0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogWidth,
                maxHeight: dialogMaxHeight,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null) ...[_buildHeader(context, title)],
                  Flexible(
                    child: scrollable
                        ? SingleChildScrollView(
                            padding:
                                contentPadding ??
                                _defaultContentPadding(isTablet, isDesktop),
                            child: builder(context),
                          )
                        : Padding(
                            padding:
                                contentPadding ??
                                _defaultContentPadding(isTablet, isDesktop),
                            child: builder(context),
                          ),
                  ),
                  if (actions != null && actions.isNotEmpty) ...[
                    _buildActions(context, actions),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Shows a responsive confirmation dialog
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
    IconData? icon,
  }) {
    return show<bool>(
      context: context,
      title: title,
      maxWidth: 400,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
          ],
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: confirmColor),
          child: Text(confirmText),
        ),
      ],
    );
  }

  /// Shows a responsive input dialog
  static Future<String?> showInput({
    required BuildContext context,
    required String title,
    String? initialValue,
    String? labelText,
    String? hintText,
    TextInputType? keyboardType,
    String? helperText,
    String confirmText = 'Save',
    String cancelText = 'Cancel',
    bool obscureText = false,
    IconData? prefixIcon,
    int? maxLines = 1,
  }) {
    final controller = TextEditingController(text: initialValue);

    return show<String>(
      context: context,
      title: title,
      maxWidth: 450,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (helperText != null) ...[
            Text(
              helperText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            maxLines: maxLines,
            decoration: InputDecoration(
              labelText: labelText,
              hintText: hintText,
              prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(cancelText),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(confirmText),
        ),
      ],
    );
  }

  /// Shows a responsive selection dialog
  static Future<T?> showSelection<T>({
    required BuildContext context,
    required String title,
    required List<T> items,
    required Widget Function(T) itemBuilder,
    T? initialValue,
    String confirmText = 'Select',
    String cancelText = 'Cancel',
  }) {
    T? selectedValue = initialValue;

    return show<T>(
      context: context,
      title: title,
      maxWidth: 400,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...items.map(
              (item) => RadioListTile<T>(
                title: itemBuilder(item),
                value: item,
                groupValue: selectedValue,
                onChanged: (value) {
                  setState(() => selectedValue = value);
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(cancelText),
        ),
        FilledButton(
          onPressed: selectedValue != null
              ? () => Navigator.pop(context, selectedValue)
              : null,
          child: Text(confirmText),
        ),
      ],
    );
  }

  /// Shows a responsive loading dialog
  static void showLoading({
    required BuildContext context,
    required String message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const M3CircularProgressIndicator(),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hides the current dialog
  static void hide(BuildContext context) {
    Navigator.pop(context);
  }

  static Widget _buildHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  static Widget _buildActions(BuildContext context, List<Widget> actions) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: actions.map((action) {
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: action,
          );
        }).toList(),
      ),
    );
  }

  static EdgeInsets _defaultContentPadding(bool isTablet, bool isDesktop) {
    return EdgeInsets.fromLTRB(
      24,
      8,
      24,
      isDesktop
          ? 24
          : isTablet
          ? 20
          : 16,
    );
  }
}

/// Extension for easier dialog usage
extension DialogExtensions on BuildContext {
  Future<T?> showResponsiveDialog<T>({
    required WidgetBuilder builder,
    String? title,
    List<Widget>? actions,
    bool scrollable = true,
    double? maxWidth,
    double? maxHeight,
  }) {
    return ResponsiveDialog.show<T>(
      context: this,
      builder: builder,
      title: title,
      actions: actions,
      scrollable: scrollable,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  Future<bool?> showConfirmationDialog({
    required String title,
    required String content,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
    IconData? icon,
    required Future<Null> Function() onConfirm,
  }) {
    return ResponsiveDialog.showConfirmation(
      context: this,
      title: title,
      content: content,
      confirmText: confirmText,
      cancelText: cancelText,
      confirmColor: confirmColor,
      icon: icon,
    );
  }

  Future<String?> showInputDialog({
    required String title,
    String? initialValue,
    String? labelText,
    String? hintText,
    TextInputType? keyboardType,
    String? helperText,
    String confirmText = 'Save',
    String cancelText = 'Cancel',
    bool obscureText = false,
    IconData? prefixIcon,
    int? maxLines = 1,
  }) {
    return ResponsiveDialog.showInput(
      context: this,
      title: title,
      initialValue: initialValue,
      labelText: labelText,
      hintText: hintText,
      keyboardType: keyboardType,
      helperText: helperText,
      confirmText: confirmText,
      cancelText: cancelText,
      obscureText: obscureText,
      prefixIcon: prefixIcon,
      maxLines: maxLines,
    );
  }

  Future<T?> showSelectionDialog<T>({
    required String title,
    required List<T> items,
    required Widget Function(T) itemBuilder,
    T? initialValue,
    String confirmText = 'Select',
    String cancelText = 'Cancel',
  }) {
    return ResponsiveDialog.showSelection<T>(
      context: this,
      title: title,
      items: items,
      itemBuilder: itemBuilder,
      initialValue: initialValue,
      confirmText: confirmText,
      cancelText: cancelText,
    );
  }

  void showLoadingDialog({required String message}) {
    ResponsiveDialog.showLoading(context: this, message: message);
  }

  void hideDialog() {
    ResponsiveDialog.hide(this);
  }
}
