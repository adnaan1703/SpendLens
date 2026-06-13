import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'amount_text.dart';
import 'app_card.dart';

enum MetricCardTone { neutral, positive, warning, negative }

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.supportingText,
    this.tone = MetricCardTone.neutral,
    this.width = 252,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? supportingText;
  final MetricCardTone tone;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semanticColors = theme.extension<AppSemanticColors>();
    final (iconBackground, iconForeground) = switch (tone) {
      MetricCardTone.neutral => (
        theme.colorScheme.surfaceContainerHigh,
        theme.colorScheme.onSurface,
      ),
      MetricCardTone.positive => (
        semanticColors?.positiveContainer ?? theme.colorScheme.primaryContainer,
        semanticColors?.positive ?? theme.colorScheme.primary,
      ),
      MetricCardTone.warning => (
        semanticColors?.warningContainer ?? theme.colorScheme.tertiaryContainer,
        semanticColors?.onWarning ?? theme.colorScheme.onTertiaryContainer,
      ),
      MetricCardTone.negative => (
        semanticColors?.negativeContainer ?? theme.colorScheme.errorContainer,
        semanticColors?.negative ?? theme.colorScheme.error,
      ),
    };

    return AppContentCard(
      width: width,
      padding: const EdgeInsets.all(20),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: ShapeDecoration(
                  color: iconBackground,
                  shape: const OvalBorder(),
                ),
                child: Icon(icon, color: iconForeground, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LargeAmountText(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              height: 1,
            ),
          ),
          if (supportingText != null) ...[
            const SizedBox(height: 10),
            Text(
              supportingText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class MetricCardGrid extends StatelessWidget {
  const MetricCardGrid({
    super.key,
    required this.children,
    this.minTileWidth = 220,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final columns = (availableWidth / minTileWidth).floor().clamp(1, 4);
        final tileWidth =
            (availableWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}
