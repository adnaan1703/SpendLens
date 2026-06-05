import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../features/auth/data/auth_repository.dart';

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  if (authRepository is SupabaseAuthRepository) {
    return SupabaseHouseholdRepository(Supabase.instance.client);
  }

  return const DisabledHouseholdRepository();
});

final householdContextProvider = FutureProvider<HouseholdContext>((ref) async {
  final session = ref.watch(authSessionProvider).value;

  if (session == null) {
    throw const UnauthenticatedHouseholdException();
  }

  return ref
      .watch(householdRepositoryProvider)
      .loadOrCreateForUser(session.user);
});

final class UnauthenticatedHouseholdException implements Exception {
  const UnauthenticatedHouseholdException();

  @override
  String toString() => 'A signed-in user is required.';
}

final class HouseholdContext {
  const HouseholdContext({
    required this.profile,
    required this.household,
    required this.memberRole,
  });

  final AppProfile profile;
  final Household household;
  final String memberRole;
}

final class AppProfile {
  const AppProfile({
    required this.id,
    required this.authUserId,
    required this.displayName,
    required this.email,
  });

  final String id;
  final String authUserId;
  final String displayName;
  final String? email;

  factory AppProfile.fromJson(Map<String, dynamic> json) {
    return AppProfile(
      id: json['id'] as String,
      authUserId: json['auth_user_id'] as String,
      displayName: (json['display_name'] as String?) ?? 'SpendLens user',
      email: json['email'] as String?,
    );
  }
}

final class Household {
  const Household({
    required this.id,
    required this.name,
    required this.currencyCode,
  });

  final String id;
  final String name;
  final String currencyCode;

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      id: json['id'] as String,
      name: json['name'] as String,
      currencyCode: json['currency_code'] as String,
    );
  }
}

abstract interface class HouseholdRepository {
  Future<HouseholdContext> loadOrCreateForUser(User user);
}

final class SupabaseHouseholdRepository implements HouseholdRepository {
  SupabaseHouseholdRepository(this._client);

  final SupabaseClient _client;
  final Uuid _uuid = const Uuid();

  @override
  Future<HouseholdContext> loadOrCreateForUser(User user) async {
    final profile = await _loadOrCreateProfile(user);
    final existing = await _loadExistingContext(profile);

    if (existing != null) {
      return existing;
    }

    return _createDefaultHousehold(profile);
  }

  Future<AppProfile> _loadOrCreateProfile(User user) async {
    final existing = await _client
        .from('profiles')
        .select('id, auth_user_id, display_name, email')
        .eq('auth_user_id', user.id)
        .maybeSingle();

    if (existing != null) {
      return AppProfile.fromJson(existing);
    }

    final profileId = _uuid.v4();
    final displayName = _displayNameFor(user);
    final inserted = await _client
        .from('profiles')
        .insert({
          'id': profileId,
          'auth_user_id': user.id,
          'display_name': displayName,
          'email': user.email,
        })
        .select('id, auth_user_id, display_name, email')
        .single();

    return AppProfile.fromJson(inserted);
  }

  Future<HouseholdContext?> _loadExistingContext(AppProfile profile) async {
    final memberships = await _client
        .from('household_members')
        .select('role, household_id')
        .eq('profile_id', profile.id)
        .eq('is_active', true)
        .limit(1);

    if (memberships.isEmpty) {
      return null;
    }

    final membership = memberships.first;
    final household = await _client
        .from('households')
        .select('id, name, currency_code')
        .eq('id', membership['household_id'] as String)
        .single();

    return HouseholdContext(
      profile: profile,
      household: Household.fromJson(household),
      memberRole: membership['role'] as String,
    );
  }

  Future<HouseholdContext> _createDefaultHousehold(AppProfile profile) async {
    final household = Household(
      id: _uuid.v4(),
      name: '${_firstName(profile.displayName)} Household',
      currencyCode: 'INR',
    );

    await _client.from('households').insert({
      'id': household.id,
      'name': household.name,
      'currency_code': household.currencyCode,
      'created_by': profile.id,
    });

    await _client.from('household_members').insert({
      'id': _uuid.v4(),
      'household_id': household.id,
      'profile_id': profile.id,
      'role': 'owner',
      'is_active': true,
    });

    return HouseholdContext(
      profile: profile,
      household: household,
      memberRole: 'owner',
    );
  }

  String _displayNameFor(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final name =
        metadata['name'] ??
        metadata['full_name'] ??
        metadata['preferred_username'] ??
        user.email;

    final displayName = name?.toString().trim();
    return displayName == null || displayName.isEmpty
        ? 'SpendLens user'
        : displayName;
  }

  String _firstName(String displayName) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return 'My';

    return trimmed.split(RegExp(r'\s+')).first;
  }
}

final class DisabledHouseholdRepository implements HouseholdRepository {
  const DisabledHouseholdRepository();

  @override
  Future<HouseholdContext> loadOrCreateForUser(User user) {
    throw const SupabaseNotConfiguredException();
  }
}
