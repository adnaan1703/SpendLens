import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendlens/src/app/spend_lens_app.dart';
import 'package:spendlens/src/core/bootstrap/app_bootstrap.dart';
import 'package:spendlens/src/core/config/app_config.dart';
import 'package:spendlens/src/core/theme/app_theme.dart';
import 'package:spendlens/src/core/theme/theme_mode_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('theme data uses centralized design tokens', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();

    expect(light.brightness, Brightness.light);
    expect(light.colorScheme.primary, AppThemeTokens.primary);
    expect(light.colorScheme.onPrimary, AppThemeTokens.onPrimary);
    expect(light.scaffoldBackgroundColor, AppThemeTokens.sageCanvas);
    expect(light.cardTheme.color, AppThemeTokens.card);

    final lightCardShape = light.cardTheme.shape as RoundedRectangleBorder;
    expect(
      lightCardShape.borderRadius,
      BorderRadius.circular(AppThemeTokens.cardRadius),
    );

    final lightSemantics = light.extension<AppSemanticColors>();
    expect(lightSemantics?.positive, AppThemeTokens.positive);
    expect(lightSemantics?.warning, AppThemeTokens.warning);
    expect(lightSemantics?.negative, AppThemeTokens.negative);

    expect(dark.brightness, Brightness.dark);
    expect(dark.colorScheme.primary, AppThemeTokens.primary);
    expect(dark.colorScheme.onPrimary, AppThemeTokens.onPrimary);
    expect(dark.scaffoldBackgroundColor, AppThemeTokens.darkCanvas);
    expect(dark.cardTheme.color, AppThemeTokens.darkCard);
    expect(
      dark.extension<AppSemanticColors>()?.negativeContainer,
      AppThemeTokens.negativeBackground,
    );
  });

  test('theme mode storage values parse to system light and dark only', () {
    expect(AppThemeMode.fromStorageValue(null), AppThemeMode.system);
    expect(AppThemeMode.fromStorageValue(''), AppThemeMode.system);
    expect(AppThemeMode.fromStorageValue('unknown'), AppThemeMode.system);
    expect(AppThemeMode.fromStorageValue('system'), AppThemeMode.system);
    expect(AppThemeMode.fromStorageValue('light'), AppThemeMode.light);
    expect(AppThemeMode.fromStorageValue('dark'), AppThemeMode.dark);
  });

  test(
    'shared preferences theme store saves and loads selected mode',
    () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesAppThemeModeStore.key: 'dark',
      });
      const store = SharedPreferencesAppThemeModeStore();

      expect(await store.load(), AppThemeMode.dark);

      await store.save(AppThemeMode.light);

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(SharedPreferencesAppThemeModeStore.key),
        'light',
      );
      expect(await store.load(), AppThemeMode.light);
    },
  );

  test('theme mode provider defaults to system then saves changes', () async {
    final store = _FakeThemeModeStore(initialMode: AppThemeMode.dark);
    final container = ProviderContainer(
      overrides: [appThemeModeStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);
    expect(
      await container.read(appThemeModeControllerProvider.future),
      AppThemeMode.dark,
    );
    expect(container.read(themeModeProvider), ThemeMode.dark);

    await container
        .read(appThemeModeControllerProvider.notifier)
        .setMode(AppThemeMode.light);

    expect(store.savedModes, [AppThemeMode.light]);
    expect(container.read(themeModeProvider), ThemeMode.light);
    expect(await store.load(), AppThemeMode.light);
  });

  testWidgets('SpendLensApp applies the loaded theme mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appThemeModeStoreProvider.overrideWithValue(
            _FakeThemeModeStore(initialMode: AppThemeMode.dark),
          ),
          appConfigProvider.overrideWithValue(
            AppConfig(
              environment: AppEnvironment.local,
              supabaseUrl: null,
              supabasePublishableKey: null,
              authRedirectUrl: AppConfig.defaultAuthRedirectUrl,
            ),
          ),
          appBootstrapProvider.overrideWithValue(
            const AppBootstrap(supabaseStatus: SupabaseStatus.notConfigured),
          ),
        ],
        child: const SpendLensApp(),
      ),
    );

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );

    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.theme?.colorScheme.primary, AppThemeTokens.primary);
    expect(app.darkTheme?.brightness, Brightness.dark);
    expect(app.themeMode, ThemeMode.dark);
  });
}

class _FakeThemeModeStore implements AppThemeModeStore {
  _FakeThemeModeStore({required AppThemeMode initialMode})
    : _storedMode = initialMode;

  AppThemeMode _storedMode;
  final savedModes = <AppThemeMode>[];

  @override
  Future<AppThemeMode> load() async {
    return _storedMode;
  }

  @override
  Future<void> save(AppThemeMode mode) async {
    savedModes.add(mode);
    _storedMode = mode;
  }
}
