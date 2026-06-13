import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum AppStatusTone { neutral, positive, warning, negative }

class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.icon,
    this.badgeCount,
    this.tooltip,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;
  final int? badgeCount;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = selected
        ? AppThemeTokens.primary
        : theme.colorScheme.surface;
    final foreground = selected
        ? AppThemeTokens.onPrimary
        : theme.colorScheme.onSurface;
    final borderColor = selected
        ? AppThemeTokens.primary
        : theme.colorScheme.outlineVariant;
    final pill = Semantics(
      button: true,
      selected: selected,
      enabled: onSelected != null,
      child: Material(
        color: background,
        shape: StadiumBorder(side: BorderSide(color: borderColor)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelected == null ? null : () => onSelected!(!selected),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: foreground),
                    const SizedBox(width: 8),
                  ],
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  if (badgeCount != null) ...[
                    const SizedBox(width: 8),
                    _PillBadge(
                      label: badgeCount!.toString(),
                      foreground: foreground,
                      background: selected
                          ? AppThemeTokens.primaryActive
                          : theme.colorScheme.surfaceContainerHigh,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltip == null) return pill;

    return Tooltip(message: tooltip, child: pill);
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = AppStatusTone.neutral,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final AppStatusTone tone;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semanticColors = theme.extension<AppSemanticColors>();
    final (background, foreground) = switch (tone) {
      AppStatusTone.neutral => (
        theme.colorScheme.surfaceContainerHigh,
        theme.colorScheme.onSurface,
      ),
      AppStatusTone.positive => (
        semanticColors?.positiveContainer ?? theme.colorScheme.primaryContainer,
        semanticColors?.positive ?? theme.colorScheme.primary,
      ),
      AppStatusTone.warning => (
        semanticColors?.warningContainer ?? theme.colorScheme.tertiaryContainer,
        semanticColors?.onWarning ?? theme.colorScheme.onTertiaryContainer,
      ),
      AppStatusTone.negative => (
        semanticColors?.negativeContainer ?? theme.colorScheme.errorContainer,
        semanticColors?.negative ?? theme.colorScheme.error,
      ),
    };

    return Semantics(
      label: semanticLabel ?? label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: background,
            shape: const StadiumBorder(),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: foreground),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.icon,
    required this.label,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = foregroundColor ?? theme.colorScheme.onSurface;
    final chip = Semantics(
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: backgroundColor ?? theme.colorScheme.surfaceContainerLow,
            shape: const StadiumBorder(),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (tooltip == null) return chip;

    return Tooltip(message: tooltip, child: chip);
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: foreground, letterSpacing: 0),
        ),
      ),
    );
  }
}
