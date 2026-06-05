import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/bootstrap/app_bootstrap.dart';
import '../../../core/config/app_config.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final bootstrap = ref.watch(appBootstrapProvider);
  final config = ref.watch(appConfigProvider);

  if (!bootstrap.isSupabaseReady) {
    return DisabledAuthRepository(bootstrap.supabaseStatus);
  }

  return SupabaseAuthRepository(Supabase.instance.client, config);
});

final authSessionProvider = StreamProvider<Session?>((ref) async* {
  final repository = ref.watch(authRepositoryProvider);

  yield repository.currentSession;
  yield* repository.authStateChanges.map((state) => state.session);
});

sealed class AuthUnavailableException implements Exception {
  const AuthUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class SupabaseNotConfiguredException extends AuthUnavailableException {
  const SupabaseNotConfiguredException()
    : super('Supabase is not configured for this build.');
}

final class SupabaseStartupFailedException extends AuthUnavailableException {
  const SupabaseStartupFailedException()
    : super('Supabase failed to initialize for this build.');
}

abstract interface class AuthRepository {
  Session? get currentSession;

  User? get currentUser;

  Stream<AuthState> get authStateChanges;

  Future<void> signInWithGoogle();

  Future<void> signOut();
}

final class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client, this._config);

  final SupabaseClient _client;
  final AppConfig _config;

  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _config.authRedirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

final class DisabledAuthRepository implements AuthRepository {
  DisabledAuthRepository(this._status);

  final SupabaseStatus _status;

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<void> signInWithGoogle() {
    throw _exception;
  }

  @override
  Future<void> signOut() async {}

  AuthUnavailableException get _exception {
    return switch (_status) {
      SupabaseStatus.failed => const SupabaseStartupFailedException(),
      SupabaseStatus.notConfigured => const SupabaseNotConfiguredException(),
      SupabaseStatus.ready => const SupabaseStartupFailedException(),
    };
  }
}
