import 'package:flutter/material.dart';

enum AppWindowSizeClass { mobile, tablet, desktop }

class AppResponsiveBreakpoints {
  const AppResponsiveBreakpoints._();

  static const tabletMinWidth = 768.0;
  static const desktopMinWidth = 1024.0;
  static const maxContentWidth = 1200.0;
  static const modalMaxWidth = 640.0;
  static const formMaxWidth = 760.0;

  static AppWindowSizeClass classForWidth(double width) {
    if (width >= desktopMinWidth) return AppWindowSizeClass.desktop;
    if (width >= tabletMinWidth) return AppWindowSizeClass.tablet;

    return AppWindowSizeClass.mobile;
  }
}

@immutable
class AppResponsiveMetrics {
  const AppResponsiveMetrics({
    required this.windowSize,
    required this.layoutWidth,
    required this.sizeClass,
    required this.maxContentWidth,
    required this.horizontalPagePadding,
    required this.topPagePadding,
    required this.bottomPagePadding,
    required this.cardPadding,
    required this.sectionGap,
  });

  factory AppResponsiveMetrics.fromConstraints(
    BuildContext context,
    BoxConstraints constraints, {
    double maxContentWidth = AppResponsiveBreakpoints.maxContentWidth,
    bool reserveBottomNavigationSpace = false,
    double? bottomNavigationHeight,
  }) {
    final windowSize = MediaQuery.sizeOf(context);
    final layoutWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : windowSize.width;
    final sizeClass = AppResponsiveBreakpoints.classForWidth(layoutWidth);
    final viewPadding = MediaQuery.of(context).viewPadding;
    final theme = Theme.of(context);
    final navigationHeight =
        bottomNavigationHeight ?? theme.navigationBarTheme.height ?? 72;
    final reservesNavigation =
        reserveBottomNavigationSpace && sizeClass == AppWindowSizeClass.mobile;

    return AppResponsiveMetrics(
      windowSize: windowSize,
      layoutWidth: layoutWidth,
      sizeClass: sizeClass,
      maxContentWidth: maxContentWidth,
      horizontalPagePadding: switch (sizeClass) {
        AppWindowSizeClass.mobile => 20,
        AppWindowSizeClass.tablet => 28,
        AppWindowSizeClass.desktop => 32,
      },
      topPagePadding: switch (sizeClass) {
        AppWindowSizeClass.mobile => 20,
        AppWindowSizeClass.tablet => 28,
        AppWindowSizeClass.desktop => 32,
      },
      bottomPagePadding:
          switch (sizeClass) {
            AppWindowSizeClass.mobile => 24,
            AppWindowSizeClass.tablet => 32,
            AppWindowSizeClass.desktop => 40,
          } +
          viewPadding.bottom +
          (reservesNavigation ? navigationHeight : 0),
      cardPadding: switch (sizeClass) {
        AppWindowSizeClass.mobile => 20,
        AppWindowSizeClass.tablet => 24,
        AppWindowSizeClass.desktop => 24,
      },
      sectionGap: switch (sizeClass) {
        AppWindowSizeClass.mobile => 20,
        AppWindowSizeClass.tablet => 24,
        AppWindowSizeClass.desktop => 28,
      },
    );
  }

  final Size windowSize;
  final double layoutWidth;
  final AppWindowSizeClass sizeClass;
  final double maxContentWidth;
  final double horizontalPagePadding;
  final double topPagePadding;
  final double bottomPagePadding;
  final double cardPadding;
  final double sectionGap;

  bool get isMobile => sizeClass == AppWindowSizeClass.mobile;
  bool get isTablet => sizeClass == AppWindowSizeClass.tablet;
  bool get isDesktop => sizeClass == AppWindowSizeClass.desktop;

  EdgeInsets get pagePadding => EdgeInsets.fromLTRB(
    horizontalPagePadding,
    topPagePadding,
    horizontalPagePadding,
    bottomPagePadding,
  );

  BoxConstraints get contentConstraints =>
      BoxConstraints(maxWidth: maxContentWidth);
}

class AppResponsiveBuilder extends StatelessWidget {
  const AppResponsiveBuilder({
    super.key,
    required this.builder,
    this.maxContentWidth = AppResponsiveBreakpoints.maxContentWidth,
    this.reserveBottomNavigationSpace = false,
    this.bottomNavigationHeight,
  });

  final Widget Function(BuildContext context, AppResponsiveMetrics metrics)
  builder;
  final double maxContentWidth;
  final bool reserveBottomNavigationSpace;
  final double? bottomNavigationHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = AppResponsiveMetrics.fromConstraints(
          context,
          constraints,
          maxContentWidth: maxContentWidth,
          reserveBottomNavigationSpace: reserveBottomNavigationSpace,
          bottomNavigationHeight: bottomNavigationHeight,
        );

        return builder(context, metrics);
      },
    );
  }
}
