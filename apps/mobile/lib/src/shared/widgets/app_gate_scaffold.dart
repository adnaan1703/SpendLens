import 'package:flutter/material.dart';

import 'responsive.dart';

class AppGateScaffold extends StatelessWidget {
  const AppGateScaffold({
    super.key,
    required this.child,
    this.maxContentWidth = AppResponsiveBreakpoints.formMaxWidth,
  });

  final Widget child;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: AppResponsiveBuilder(
          maxContentWidth: maxContentWidth,
          builder: (context, metrics) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final minHeight = constraints.hasBoundedHeight
                    ? (constraints.maxHeight - metrics.pagePadding.vertical)
                          .clamp(0.0, double.infinity)
                          .toDouble()
                    : 0.0;

                return SingleChildScrollView(
                  padding: metrics.pagePadding,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minHeight),
                    child: Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: metrics.contentConstraints,
                        child: SizedBox(width: double.infinity, child: child),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
