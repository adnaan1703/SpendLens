import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../core/config/app_config.dart';
import '../../shared/widgets/app_page.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const routePath = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final bootstrap = ref.watch(appBootstrapProvider);

    return AppPage(
      title: 'Settings',
      subtitle: 'Runtime',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _SettingsRow(label: 'Environment', value: config.environment.label),
              const Divider(height: 28),
              const _SettingsRow(
                label: 'Android package',
                value: AppConfig.androidPackageName,
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
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    required this.value,
  });

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
