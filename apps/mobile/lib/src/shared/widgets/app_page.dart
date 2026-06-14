import 'package:flutter/material.dart';

import 'responsive.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.stackActions = true,
    this.maxContentWidth = AppResponsiveBreakpoints.maxContentWidth,
    this.reserveBottomNavigationSpace = true,
    this.bottomNavigationHeight,
    this.scrollController,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool stackActions;
  final double maxContentWidth;
  final bool reserveBottomNavigationSpace;
  final double? bottomNavigationHeight;
  final ScrollController? scrollController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppResponsiveBuilder(
      maxContentWidth: maxContentWidth,
      reserveBottomNavigationSpace: reserveBottomNavigationSpace,
      bottomNavigationHeight: bottomNavigationHeight,
      builder: (context, metrics) {
        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            controller: scrollController,
            padding: metrics.pagePadding,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: metrics.contentConstraints,
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PageHeader(
                      title: title,
                      subtitle: subtitle,
                      actions: actions,
                      stackActions: stackActions,
                    ),
                    SizedBox(height: metrics.sectionGap),
                    child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AppDisplayHeading extends StatelessWidget {
  const AppDisplayHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.textAlign,
    this.maxLines,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final sizeClass = AppResponsiveBreakpoints.classForWidth(width);
        final titleStyle = switch (sizeClass) {
          AppWindowSizeClass.mobile => textTheme.headlineLarge,
          AppWindowSizeClass.tablet => textTheme.displaySmall,
          AppWindowSizeClass.desktop => textTheme.displayMedium,
        }?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0);

        return Column(
          crossAxisAlignment: switch (textAlign) {
            TextAlign.center => CrossAxisAlignment.center,
            TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
            _ => CrossAxisAlignment.start,
          },
          children: [
            if (eyebrow != null) ...[
              Text(
                eyebrow!,
                textAlign: textAlign,
                style: textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              title,
              maxLines: maxLines,
              overflow: maxLines == null ? null : TextOverflow.ellipsis,
              textAlign: textAlign,
              style: titleStyle,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: textAlign,
                style: textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class AppSectionHeading extends StatelessWidget {
  const AppSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showDivider = true,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacksActions =
            constraints.hasBoundedWidth && constraints.maxWidth < 560;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 0),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: theme.textTheme.bodyMedium),
            ],
          ],
        );
        final heading = trailing == null
            ? text
            : stacksActions
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [text, const SizedBox(height: 12), trailing!],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: trailing,
                    ),
                  ),
                ],
              );

        if (!showDivider) return heading;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading,
            const SizedBox(height: 12),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ],
        );
      },
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.stackActions,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool stackActions;

  @override
  Widget build(BuildContext context) {
    final heading = AppDisplayHeading(title: title, subtitle: subtitle);
    final pageActions = actions;

    if (pageActions == null || pageActions.isEmpty) return heading;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacksActions = stackActions &&
            constraints.hasBoundedWidth &&
            constraints.maxWidth < 720;
        final actionBar = Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: pageActions,
        );

        if (stacksActions) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 16), actionBar],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 24),
            Flexible(
              child: Align(alignment: Alignment.topRight, child: actionBar),
            ),
          ],
        );
      },
    );
  }
}
