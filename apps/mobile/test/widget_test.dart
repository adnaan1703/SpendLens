import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendlens/src/app/spend_lens_app.dart';
import 'package:spendlens/src/core/bootstrap/app_bootstrap.dart';
import 'package:spendlens/src/core/config/app_config.dart';

void main() {
  testWidgets('shows the SpendLens dashboard shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig(
              environment: AppEnvironment.local,
              supabaseUrl: null,
              supabasePublishableKey: null,
            ),
          ),
          appBootstrapProvider.overrideWithValue(
            AppBootstrap(supabaseStatus: SupabaseStatus.notConfigured),
          ),
        ],
        child: const SpendLensApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Current month net'), findsOneWidget);
    expect(find.text('Transactions'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('navigates between shell destinations', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig(
              environment: AppEnvironment.local,
              supabaseUrl: null,
              supabasePublishableKey: null,
            ),
          ),
          appBootstrapProvider.overrideWithValue(
            AppBootstrap(supabaseStatus: SupabaseStatus.notConfigured),
          ),
        ],
        child: const SpendLensApp(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    expect(find.text('Runtime'), findsOneWidget);
    expect(find.text(AppConfig.androidPackageName), findsOneWidget);
  });
}
