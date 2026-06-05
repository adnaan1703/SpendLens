import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../core/config/app_config.dart';
import '../../data/repositories/household_repository.dart';
import '../../shared/widgets/app_page.dart';
import '../auth/data/auth_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const routePath = '/settings';

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    try {
      await ref.read(authRepositoryProvider).signOut();
      ref.invalidate(householdContextProvider);
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final bootstrap = ref.watch(appBootstrapProvider);
    final householdContext = ref.watch(householdContextProvider).value;
    final session = ref.watch(authSessionProvider).value;

    return AppPage(
      title: 'Settings',
      subtitle: 'Account and runtime',
      actions: [
        FilledButton.tonalIcon(
          onPressed: _isSigningOut ? null : _signOut,
          icon: _isSigningOut
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout),
          label: Text(_isSigningOut ? 'Signing out...' : 'Sign out'),
        ),
      ],
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _SettingsRow(
                    label: 'Signed in as',
                    value:
                        householdContext?.profile.email ??
                        session?.user.email ??
                        'Unknown user',
                  ),
                  const Divider(height: 28),
                  _SettingsRow(
                    label: 'Household',
                    value: householdContext?.household.name ?? 'Loading',
                  ),
                  const Divider(height: 28),
                  _SettingsRow(
                    label: 'Role',
                    value: householdContext?.memberRole ?? 'Loading',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _SettingsRow(
                    label: 'Environment',
                    value: config.environment.label,
                  ),
                  const Divider(height: 28),
                  const _SettingsRow(
                    label: 'Android package',
                    value: AppConfig.androidPackageName,
                  ),
                  const Divider(height: 28),
                  _SettingsRow(
                    label: 'Auth redirect',
                    value: config.authRedirectUrl,
                  ),
                  const Divider(height: 28),
                  _SettingsRow(
                    label: 'Supabase',
                    value: switch (bootstrap.supabaseStatus) {
                      SupabaseStatus.ready => 'Ready',
                      SupabaseStatus.failed => 'Error',
                      SupabaseStatus.notConfigured => 'Not configured',
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(child: Text(label, style: textTheme.labelLarge)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
