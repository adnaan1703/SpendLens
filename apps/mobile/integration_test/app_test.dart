import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendlens/src/app/spend_lens_app.dart';
import 'package:spendlens/src/core/bootstrap/app_bootstrap.dart';
import 'package:spendlens/src/core/config/app_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app shell smoke test', (tester) async {
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
  });
}
