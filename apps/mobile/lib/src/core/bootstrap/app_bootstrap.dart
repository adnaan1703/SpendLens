import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

final appBootstrapProvider = Provider<AppBootstrap>((ref) {
  throw UnimplementedError('AppBootstrap is provided during app startup.');
});

class AppBootstrap {
  const AppBootstrap({
    required this.supabaseStatus,
    this.startupError,
  });

  final SupabaseStatus supabaseStatus;
  final Object? startupError;

  bool get isSupabaseReady => supabaseStatus == SupabaseStatus.ready;

  static Future<AppBootstrap> initialize(AppConfig config) async {
    if (!config.hasSupabaseConfig) {
      return const AppBootstrap(supabaseStatus: SupabaseStatus.notConfigured);
    }

    try {
      await Supabase.initialize(
        url: config.supabaseUrl!,
        publishableKey: config.supabasePublishableKey!,
      );

      return const AppBootstrap(supabaseStatus: SupabaseStatus.ready);
    } catch (error) {
      return AppBootstrap(
        supabaseStatus: SupabaseStatus.failed,
        startupError: error,
      );
    }
  }
}

enum SupabaseStatus {
  notConfigured,
  ready,
  failed,
}
