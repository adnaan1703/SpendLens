import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'responsive.dart';

enum AppFeatureCardVariant { sage, green, dark }

class AppContentCard extends StatelessWidget {
  const AppContentCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.foregroundColor,
    this.borderSide,
    this.constraints,
    this.width,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final BorderSide? borderSide;
  final BoxConstraints? constraints;
  final double? width;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppThemeTokens.cardRadius);
    final effectiveBackground = backgroundColor ?? theme.cardColor;
    final effectiveForeground = foregroundColor ?? theme.colorScheme.onSurface;
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: borderSide ?? BorderSide.none,
    );
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(24),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: effectiveForeground),
        child: IconTheme.merge(
          data: IconThemeData(color: effectiveForeground),
          child: child,
        ),
      ),
    );
    final material = Material(
      color: effectiveBackground,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, borderRadius: radius, child: content),
    );
    final labeled = semanticLabel == null
        ? material
        : Semantics(label: semanticLabel, child: material);
    final constrained = constraints == null
        ? labeled
        : ConstrainedBox(constraints: constraints!, child: labeled);

    if (width == null) return constrained;

    return SizedBox(width: width, child: constrained);
  }
}

class AppFeatureCard extends StatelessWidget {
  const AppFeatureCard({
    super.key,
    required this.child,
    this.variant = AppFeatureCardVariant.sage,
    this.padding,
    this.onTap,
    this.semanticLabel,
  });

  const AppFeatureCard.sage({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.semanticLabel,
  }) : variant = AppFeatureCardVariant.sage;

  const AppFeatureCard.green({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.semanticLabel,
  }) : variant = AppFeatureCardVariant.green;

  const AppFeatureCard.dark({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.semanticLabel,
  }) : variant = AppFeatureCardVariant.dark;

  final Widget child;
  final AppFeatureCardVariant variant;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = switch (variant) {
      AppFeatureCardVariant.sage => (
        theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainerHigh
            : AppThemeTokens.sageCanvas,
        theme.colorScheme.onSurface,
      ),
      AppFeatureCardVariant.green => (
        theme.brightness == Brightness.dark
            ? theme.colorScheme.primaryContainer
            : AppThemeTokens.primaryPale,
        theme.colorScheme.onPrimaryContainer,
      ),
      AppFeatureCardVariant.dark => (
        AppThemeTokens.ink,
        AppThemeTokens.primary,
      ),
    };

    return AppContentCard(
      padding: padding,
      backgroundColor: background,
      foregroundColor: foreground,
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: child,
    );
  }
}

class SageFeatureCard extends StatelessWidget {
  const SageFeatureCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return AppFeatureCard.sage(
      padding: padding,
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: child,
    );
  }
}

class DarkFeatureCard extends StatelessWidget {
  const DarkFeatureCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return AppFeatureCard.dark(
      padding: padding,
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: child,
    );
  }
}

class AppModalCardShell extends StatelessWidget {
  const AppModalCardShell({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.padding,
    this.maxWidth = AppResponsiveBreakpoints.modalMaxWidth,
    this.scrollable = true,
    this.showDragHandle = true,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;
  final bool scrollable;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final theme = Theme.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDragHandle) ...[
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: ShapeDecoration(
                color: theme.colorScheme.outlineVariant,
                shape: const StadiumBorder(),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (title != null || subtitle != null) ...[
          _ModalHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 20),
        ],
        child,
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Wrap(spacing: 12, runSpacing: 12, children: actions),
        ],
      ],
    );
    final shell = AppEntranceMotion(
      slideOffset: const Offset(0, 12),
      child: AppContentCard(
        padding: padding ?? const EdgeInsets.all(24),
        child: scrollable ? SingleChildScrollView(child: content) : content,
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: shell,
          ),
        ),
      ),
    );
  }
}

class AppModalDialog extends StatelessWidget {
  const AppModalDialog({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.padding,
    this.maxWidth = AppResponsiveBreakpoints.modalMaxWidth,
    this.scrollable = true,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final availableHeight = screenHeight - viewInsets.bottom - 48;
    final maxDialogHeight = availableHeight < 240
        ? screenHeight
        : availableHeight;
    final body = scrollable
        ? Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(child: child),
          )
        : child;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null || subtitle != null) ...[
          _ModalHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 20),
        ],
        body,
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(spacing: 12, runSpacing: 12, children: actions),
          ),
        ],
      ],
    );

    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: AppEntranceMotion(
        slideOffset: const Offset(0, 10),
        child: Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxDialogHeight,
              ),
              child: AppContentCard(
                padding: padding ?? const EdgeInsets.all(24),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppEntranceMotion extends StatelessWidget {
  const AppEntranceMotion({
    super.key,
    required this.child,
    this.slideOffset = const Offset(0, 8),
    this.duration = const Duration(milliseconds: 180),
  });

  final Widget child;
  final Offset slideOffset;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery?.accessibleNavigation ?? false) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              slideOffset.dx * (1 - value),
              slideOffset.dy * (1 - value),
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class AppPressedScale extends StatefulWidget {
  const AppPressedScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.98,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;

  @override
  State<AppPressedScale> createState() => _AppPressedScaleState();
}

class _AppPressedScaleState extends State<AppPressedScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final reduceMotion = mediaQuery?.accessibleNavigation ?? false;
    if (!widget.enabled || reduceMotion) return widget.child;

    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _ModalHeader extends StatelessWidget {
  const _ModalHeader({required this.title, required this.subtitle});

  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Text(
            title!,
            style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 0),
          ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}
