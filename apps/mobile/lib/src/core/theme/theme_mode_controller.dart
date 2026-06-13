import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  system(ThemeMode.system),
  light(ThemeMode.light),
  dark(ThemeMode.dark);

  const AppThemeMode(this.materialThemeMode);

  final ThemeMode materialThemeMode;

  static AppThemeMode fromStorageValue(String? value) {
    for (final mode in values) {
      if (mode.name == value) {
        return mode;
      }
    }

    return AppThemeMode.system;
  }
}

abstract interface class AppThemeModeStore {
  Future<AppThemeMode> load();

  Future<void> save(AppThemeMode mode);
}

class SharedPreferencesAppThemeModeStore implements AppThemeModeStore {
  const SharedPreferencesAppThemeModeStore();

  static const key = 'spendlens.theme_mode';

  @override
  Future<AppThemeMode> load() async {
    final preferences = await SharedPreferences.getInstance();
    return AppThemeMode.fromStorageValue(preferences.getString(key));
  }

  @override
  Future<void> save(AppThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, mode.name);
  }
}

final appThemeModeStoreProvider = Provider<AppThemeModeStore>((ref) {
  return const SharedPreferencesAppThemeModeStore();
});

final appThemeModeControllerProvider =
    AsyncNotifierProvider<AppThemeModeController, AppThemeMode>(
      AppThemeModeController.new,
    );

final themeModeProvider = Provider<ThemeMode>((ref) {
  final selectedMode = ref.watch(appThemeModeControllerProvider);

  return selectedMode.maybeWhen(
    data: (mode) => mode.materialThemeMode,
    orElse: () => ThemeMode.system,
  );
});

class AppThemeModeController extends AsyncNotifier<AppThemeMode> {
  @override
  Future<AppThemeMode> build() {
    return ref.watch(appThemeModeStoreProvider).load();
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = AsyncData(mode);

    try {
      await ref.read(appThemeModeStoreProvider).save(mode);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
