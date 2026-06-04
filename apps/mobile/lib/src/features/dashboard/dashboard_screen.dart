import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/metric_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const routePath = '/dashboard';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(appBootstrapProvider);
    final backendLabel = switch (bootstrap.supabaseStatus) {
      SupabaseStatus.ready => 'Ready',
      SupabaseStatus.failed => 'Error',
      SupabaseStatus.notConfigured => 'Local',
    };

    return AppPage(
      title: 'Dashboard',
      subtitle: 'Current household',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              const MetricCard(
                label: 'Current month net',
                value: 'INR 0',
                icon: Icons.payments_outlined,
                supportingText: 'No imported spend',
              ),
              const MetricCard(
                label: 'Review queue',
                value: '0',
                icon: Icons.rule_folder_outlined,
                supportingText: 'No open items',
              ),
              const MetricCard(
                label: 'Monthly caps',
                value: '0',
                icon: Icons.speed_outlined,
                supportingText: 'No caps configured',
              ),
              MetricCard(
                label: 'Backend',
                value: backendLabel,
                icon: Icons.storage_outlined,
                supportingText: bootstrap.isSupabaseReady
                    ? 'Supabase connected'
                    : 'Supabase deferred',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const EmptyState(
            icon: Icons.insights_outlined,
            title: 'Historical workbook pending',
            message: 'Dashboard summaries will appear after the import milestone.',
          ),
        ],
      ),
    );
  }
}
