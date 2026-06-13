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
              authRedirectUrl: AppConfig.defaultAuthRedirectUrl,
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

    expect(find.text('SpendLens'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Supabase setup required'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('blocks protected routes when unauthenticated', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig(
              environment: AppEnvironment.local,
              supabaseUrl: null,
              supabasePublishableKey: null,
              authRedirectUrl: AppConfig.defaultAuthRedirectUrl,
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

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Activity'), findsNothing);
  });
}
