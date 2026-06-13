import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendlens/src/core/theme/app_theme.dart';
import 'package:spendlens/src/shared/widgets/app_primitives.dart';

void main() {
  test('responsive breakpoints match the redesign plan', () {
    expect(
      AppResponsiveBreakpoints.classForWidth(767),
      AppWindowSizeClass.mobile,
    );
    expect(
      AppResponsiveBreakpoints.classForWidth(768),
      AppWindowSizeClass.tablet,
    );
    expect(
      AppResponsiveBreakpoints.classForWidth(1023),
      AppWindowSizeClass.tablet,
    );
    expect(
      AppResponsiveBreakpoints.classForWidth(1024),
      AppWindowSizeClass.desktop,
    );
  });

  testWidgets(
    'AppPage constrains content and reserves mobile bottom navigation space',
    (tester) async {
      const contentKey = Key('responsive-content');

      await _pumpAtSize(
        tester,
        const Size(390, 800),
        const AppPage(
          title: 'Dashboard',
          subtitle: 'Current household',
          child: SizedBox(key: contentKey, width: double.infinity, height: 24),
        ),
      );

      final mobilePadding =
          tester
                  .widget<SingleChildScrollView>(
                    find.byType(SingleChildScrollView),
                  )
                  .padding!
              as EdgeInsets;
      expect(mobilePadding.left, 20);
      expect(mobilePadding.right, 20);
      expect(mobilePadding.bottom, 96);
      expect(tester.getSize(find.byKey(contentKey)).width, 350);

      await _pumpAtSize(
        tester,
        const Size(1400, 900),
        const AppPage(
          title: 'Dashboard',
          subtitle: 'Current household',
          child: SizedBox(key: contentKey, width: double.infinity, height: 24),
        ),
      );

      final desktopPadding =
          tester
                  .widget<SingleChildScrollView>(
                    find.byType(SingleChildScrollView),
                  )
                  .padding!
              as EdgeInsets;
      expect(desktopPadding.left, 32);
      expect(desktopPadding.right, 32);
      expect(desktopPadding.bottom, 40);
      expect(tester.getSize(find.byKey(contentKey)).width, 1200);
    },
  );

  testWidgets('shared primitives render in light and dark themes', (
    tester,
  ) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final selectedValues = <bool>[];

      await _pumpAtSize(
        tester,
        const Size(820, 900),
        AppPage(
          title: 'Shared primitives',
          subtitle: 'Reusable UI kit',
          actions: [
            AppActionPill.secondary(
              label: 'Filters',
              icon: Icons.tune_outlined,
              onPressed: () {},
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionHeading(
                title: 'Overview',
                subtitle: 'Section heading rhythm',
                trailing: const StatusChip(
                  label: 'Ready',
                  tone: AppStatusTone.positive,
                ),
              ),
              const SizedBox(height: 16),
              const MetricCard(
                label: 'Net spend',
                value: 'INR 42,000',
                icon: Icons.payments_outlined,
                supportingText: '128 transactions',
                tone: MetricCardTone.positive,
              ),
              const SizedBox(height: 16),
              const AppContentCard(
                key: Key('content-card'),
                child: Text('White content card'),
              ),
              const SizedBox(height: 16),
              const SageFeatureCard(child: Text('Sage feature card')),
              const SizedBox(height: 16),
              const DarkFeatureCard(
                key: Key('dark-card'),
                child: Text('Dark feature card'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterPill(
                    label: 'Food',
                    selected: true,
                    icon: Icons.restaurant_outlined,
                    badgeCount: 3,
                    onSelected: selectedValues.add,
                  ),
                  const StatusChip(
                    label: 'Synced',
                    tone: AppStatusTone.neutral,
                  ),
                  const IconChip(icon: Icons.label_outline, label: 'Groceries'),
                ],
              ),
              const SizedBox(height: 16),
              const LargeAmountText('INR 9,99,999'),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: AppModalCardShell(
                  title: 'Edit cap',
                  subtitle: 'Bottom-sheet shell',
                  showDragHandle: false,
                  actions: [
                    AppActionPill.primary(
                      label: 'Save',
                      icon: Icons.check,
                      onPressed: () {},
                    ),
                    AppActionPill.destructive(
                      label: 'Delete',
                      icon: Icons.delete_outline,
                      onPressed: () {},
                    ),
                  ],
                  child: const Text('Sheet body'),
                ),
              ),
              const SizedBox(height: 16),
              EmptyState(
                icon: Icons.inbox_outlined,
                title: 'Nothing here',
                message: 'New items will appear here.',
                action: AppActionPill.primary(
                  label: 'Create',
                  onPressed: () {},
                ),
              ),
              const SizedBox(height: 16),
              const AppLoadingState(
                title: 'Loading caps',
                message: 'Checking this month.',
              ),
              const SizedBox(height: 16),
              AppErrorState(
                message: 'Try again.',
                action: AppActionPill.destructive(
                  label: 'Retry',
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
        theme: theme,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Shared primitives'), findsOneWidget);
      expect(find.text('White content card'), findsOneWidget);
      expect(find.text('Dark feature card'), findsOneWidget);
      expect(find.text('Loading caps'), findsOneWidget);

      await tester.tap(find.text('Food'));
      expect(selectedValues, [false]);

      final darkCardMaterial = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(const Key('dark-card')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(darkCardMaterial.color, AppThemeTokens.ink);
    }
  });
}

Future<void> _pumpAtSize(
  WidgetTester tester,
  Size size,
  Widget child, {
  ThemeData? theme,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}
