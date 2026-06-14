import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_card.dart';

enum AppActionPillVariant { primary, secondary, destructive }

class AppActionPill extends StatelessWidget {
  const AppActionPill.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tooltip,
    this.isLoading = false,
  }) : variant = AppActionPillVariant.primary;

  const AppActionPill.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tooltip,
    this.isLoading = false,
  }) : variant = AppActionPillVariant.secondary;

  const AppActionPill.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tooltip,
    this.isLoading = false,
  }) : variant = AppActionPillVariant.destructive;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? tooltip;
  final bool isLoading;
  final AppActionPillVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semanticColors = theme.extension<AppSemanticColors>();
    final style = FilledButton.styleFrom(
      backgroundColor: switch (variant) {
        AppActionPillVariant.primary => AppThemeTokens.primary,
        AppActionPillVariant.secondary =>
          theme.colorScheme.surfaceContainerHigh,
        AppActionPillVariant.destructive =>
          semanticColors?.negative ?? theme.colorScheme.error,
      },
      foregroundColor: switch (variant) {
        AppActionPillVariant.primary => AppThemeTokens.onPrimary,
        AppActionPillVariant.secondary => theme.colorScheme.onSurface,
        AppActionPillVariant.destructive =>
          semanticColors?.onNegative ?? theme.colorScheme.onError,
      },
      disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
      disabledForegroundColor: theme.colorScheme.outline,
      minimumSize: const Size(64, 48),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppThemeTokens.buttonRadius),
      ),
      textStyle: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0),
    );
    final loadingIndicator = SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: switch (variant) {
          AppActionPillVariant.primary => AppThemeTokens.onPrimary,
          AppActionPillVariant.secondary => theme.colorScheme.onSurface,
          AppActionPillVariant.destructive =>
            semanticColors?.onNegative ?? theme.colorScheme.onError,
        },
      ),
    );
    final child = icon == null && !isLoading
        ? Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading) loadingIndicator else Icon(icon, size: 20),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
    final button = AppPressedScale(
      enabled: onPressed != null,
      child: FilledButton(onPressed: onPressed, style: style, child: child),
    );

    if (tooltip == null) return button;

    return Tooltip(message: tooltip, child: button);
  }
}
