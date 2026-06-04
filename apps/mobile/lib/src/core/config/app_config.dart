import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  static const appName = 'SpendLens';
  static const androidPackageName = 'com.olympus.spendlens';

  final AppEnvironment environment;
  final String? supabaseUrl;
  final String? supabasePublishableKey;

  bool get hasSupabaseConfig {
    return supabaseUrl != null &&
        supabaseUrl!.isNotEmpty &&
        supabasePublishableKey != null &&
        supabasePublishableKey!.isNotEmpty;
  }

  factory AppConfig.fromEnvironment() {
    const environmentName = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'local',
    );
    const rawSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const rawSupabasePublishableKey =
        String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const rawSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    return AppConfig(
      environment: AppEnvironment.fromName(environmentName),
      supabaseUrl: _cleanValue(rawSupabaseUrl),
      supabasePublishableKey: _cleanValue(rawSupabasePublishableKey) ??
          _cleanValue(rawSupabaseAnonKey),
    );
  }

  static String? _cleanValue(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

enum AppEnvironment {
  local,
  staging,
  production;

  static AppEnvironment fromName(String name) {
    return switch (name.trim().toLowerCase()) {
      'production' || 'prod' => AppEnvironment.production,
      'staging' || 'stage' => AppEnvironment.staging,
      _ => AppEnvironment.local,
    };
  }

  String get label {
    return switch (this) {
      AppEnvironment.local => 'Local',
      AppEnvironment.staging => 'Staging',
      AppEnvironment.production => 'Production',
    };
  }
}
