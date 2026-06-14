import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spendlens/src/app/router.dart';
import 'package:spendlens/src/app/spend_lens_app.dart';
import 'package:spendlens/src/core/bootstrap/app_bootstrap.dart';
import 'package:spendlens/src/core/config/app_config.dart';
import 'package:spendlens/src/core/theme/app_theme.dart';
import 'package:spendlens/src/features/auth/data/auth_repository.dart';
import 'package:spendlens/src/features/auth/sign_in_screen.dart';

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

  testWidgets('auth entry and household gate states render in app themes', (
    tester,
  ) async {
    final scenarios = [
      _ThemeScenario(ThemeMode.light, Brightness.light),
      _ThemeScenario(ThemeMode.dark, Brightness.light),
      _ThemeScenario(ThemeMode.system, Brightness.dark),
    ];
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    for (final scenario in scenarios) {
      tester.platformDispatcher.platformBrightnessTestValue =
          scenario.platformBrightness;

      await tester.pumpWidget(
        _authGateTestApp(
          themeMode: scenario.themeMode,
          child: const SignInScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SpendLens'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Supabase setup required'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _authGateTestApp(
          themeMode: scenario.themeMode,
          child: const HouseholdLoadingScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Loading household context'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _authGateTestApp(
          themeMode: scenario.themeMode,
          authRepository: _FakeAuthRepository(),
          child: const HouseholdErrorScreen(
            message: 'Could not load household.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Household setup failed'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('sign-in button uses the configured auth repository', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository();

    await tester.pumpWidget(
      _authGateTestApp(
        bootstrap: const AppBootstrap(supabaseStatus: SupabaseStatus.ready),
        authRepository: authRepository,
        child: const SignInScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();

    expect(authRepository.signInRequests, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('household error keeps retry and sign-out actions wired', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository();

    await tester.pumpWidget(
      _authGateTestApp(
        authRepository: authRepository,
        child: const HouseholdErrorScreen(message: 'Could not load household.'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Sign out'));
    await tester.pump();

    expect(authRepository.signOutRequests, 1);
    expect(tester.takeException(), isNull);
  });
}

Widget _authGateTestApp({
  required Widget child,
  ThemeMode themeMode = ThemeMode.light,
  AppBootstrap bootstrap = const AppBootstrap(
    supabaseStatus: SupabaseStatus.notConfigured,
  ),
  AuthRepository? authRepository,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          environment: AppEnvironment.local,
          supabaseUrl: null,
          supabasePublishableKey: null,
          authRedirectUrl: AppConfig.defaultAuthRedirectUrl,
        ),
      ),
      appBootstrapProvider.overrideWithValue(bootstrap),
      authRepositoryProvider.overrideWithValue(
        authRepository ?? _FakeAuthRepository(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: child,
    ),
  );
}

final class _ThemeScenario {
  const _ThemeScenario(this.themeMode, this.platformBrightness);

  final ThemeMode themeMode;
  final Brightness platformBrightness;
}

final class _FakeAuthRepository implements AuthRepository {
  int signInRequests = 0;
  int signOutRequests = 0;

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<void> signInWithGoogle() async {
    signInRequests += 1;
  }

  @override
  Future<void> signOut() async {
    signOutRequests += 1;
  }
}
