import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/household_repository.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/metric_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  static const routePath = '/dashboard';

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime? _selectedMonth;

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(appBootstrapProvider);
    final householdContext = ref.watch(householdContextProvider).value;
    final householdId = householdContext?.household.id;
    final snapshotState = householdId == null
        ? const AsyncValue<DashboardSnapshot>.loading()
        : ref.watch(
            dashboardSnapshotProvider(
              FinanceMonthRequest(
                householdId: householdId,
                month: _selectedMonth,
              ),
            ),
          );

    return AppPage(
      title: 'Dashboard',
      subtitle: householdContext?.household.name ?? 'Current household',
      actions: [
        if (snapshotState.hasValue)
          _MonthSelector(
            months: snapshotState.value!.availableMonths,
            selectedMonth: snapshotState.value!.selectedMonth,
            onChanged: (month) {
              setState(() {
                _selectedMonth = month;
              });
            },
          ),
      ],
      child: switch (snapshotState) {
        AsyncValue(:final value?) => _DashboardContent(
          snapshot: value,
          backendLabel: _backendLabel(bootstrap.supabaseStatus),
          isSupabaseReady: bootstrap.isSupabaseReady,
          onEditCap: householdContext == null
              ? null
              : (category, existingAmount) {
                  _showCapDialog(
                    context: context,
                    householdContext: householdContext,
                    snapshot: value,
                    category: category,
                    existingAmount: existingAmount,
                  );
                },
        ),
        AsyncValue(hasError: true, :final error) => EmptyState(
          icon: Icons.error_outline,
          title: 'Dashboard unavailable',
          message: error.toString(),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  String _backendLabel(SupabaseStatus status) {
    return switch (status) {
      SupabaseStatus.ready => 'Ready',
      SupabaseStatus.failed => 'Error',
      SupabaseStatus.notConfigured => 'Local',
    };
  }

  Future<void> _showCapDialog({
    required BuildContext context,
    required HouseholdContext householdContext,
    required DashboardSnapshot snapshot,
    required CategoryOption category,
    required double? existingAmount,
  }) async {
    var amountText = existingAmount == null
        ? ''
        : existingAmount.round().toString();

    final amount = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${category.name} cap'),
          content: TextFormField(
            initialValue: amountText,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: (value) {
              amountText = value;
            },
            decoration: const InputDecoration(
              labelText: 'Monthly cap',
              prefixText: 'INR ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                final parsed = double.tryParse(amountText.trim());
                if (parsed == null || parsed < 0) return;

                Navigator.of(context).pop(parsed);
              },
              icon: const Icon(Icons.check),
              label: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (amount == null) return;

    await ref
        .read(financeRepositoryProvider)
        .saveCategoryCap(
          householdId: householdContext.household.id,
          profileId: householdContext.profile.id,
          categoryId: category.id,
          periodMonth: snapshot.selectedMonth,
          capAmount: amount,
        );

    if (mounted) {
      setState(() {
        _selectedMonth = snapshot.selectedMonth;
      });
    }

    ref.invalidate(
      dashboardSnapshotProvider(
        FinanceMonthRequest(
          householdId: householdContext.household.id,
          month: snapshot.selectedMonth,
        ),
      ),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${category.name} cap saved')));
    }
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.snapshot,
    required this.backendLabel,
    required this.isSupabaseReady,
    required this.onEditCap,
  });

  final DashboardSnapshot snapshot;
  final String backendLabel;
  final bool isSupabaseReady;
  final void Function(CategoryOption category, double? existingAmount)?
  onEditCap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            MetricCard(
              label: '${formatMonth(snapshot.selectedMonth)} net',
              value: formatMoney(snapshot.monthlySpend.netSpend),
              icon: Icons.payments_outlined,
              supportingText:
                  '${snapshot.monthlySpend.transactionCount} transactions',
            ),
            MetricCard(
              label: 'Month change',
              value: formatSignedMoney(snapshot.monthOverMonthChange),
              icon: Icons.trending_up,
              supportingText: snapshot.monthOverMonthPercent == null
                  ? 'No previous month'
                  : formatPercent(snapshot.monthOverMonthPercent!),
            ),
            MetricCard(
              label: 'Review queue',
              value: snapshot.reviewQueueCount.toString(),
              icon: Icons.rule_folder_outlined,
              supportingText: snapshot.reviewQueueCount == 1
                  ? 'Open item'
                  : 'Open items',
            ),
            MetricCard(
              label: 'Monthly caps',
              value: snapshot.cappedCategoryCount.toString(),
              icon: Icons.speed_outlined,
              supportingText: snapshot.uncappedCategories.isEmpty
                  ? 'All categories capped'
                  : '${snapshot.uncappedCategories.length} uncapped',
            ),
            MetricCard(
              label: 'Backend',
              value: backendLabel,
              icon: Icons.storage_outlined,
              supportingText: isSupabaseReady
                  ? 'Supabase connected'
                  : 'Supabase deferred',
            ),
          ],
        ),
        const SizedBox(height: 28),
        _BudgetSection(snapshot: snapshot, onEditCap: onEditCap),
        const SizedBox(height: 28),
        _SummaryGrid(snapshot: snapshot),
      ],
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.months,
    required this.selectedMonth,
    required this.onChanged,
  });

  final List<DateTime> months;
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasSelected = months.any(
      (month) => isSameMonth(month, selectedMonth),
    );
    final items = hasSelected ? months : [selectedMonth, ...months];

    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<DateTime>(
        isExpanded: true,
        initialValue: selectedMonth,
        decoration: const InputDecoration(
          labelText: 'Month',
          prefixIcon: Icon(Icons.calendar_month_outlined),
        ),
        items: [
          for (final month in items)
            DropdownMenuItem(value: month, child: Text(formatMonth(month))),
        ],
        onChanged: (month) {
          if (month != null) onChanged(month);
        },
      ),
    );
  }
}

class _BudgetSection extends StatelessWidget {
  const _BudgetSection({required this.snapshot, required this.onEditCap});

  final DashboardSnapshot snapshot;
  final void Function(CategoryOption category, double? existingAmount)?
  onEditCap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Monthly caps', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (snapshot.budgetProgress.isEmpty)
          const EmptyState(
            icon: Icons.speed_outlined,
            title: 'No caps set',
            message: 'Categories without caps are listed below.',
          )
        else
          Column(
            children: [
              for (final budget in snapshot.budgetProgress)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _BudgetProgressRow(
                    budget: budget,
                    onEdit: onEditCap == null
                        ? null
                        : () {
                            onEditCap!(
                              CategoryOption(
                                id: budget.categoryId,
                                name: budget.categoryName,
                              ),
                              budget.capAmount,
                            );
                          },
                  ),
                ),
            ],
          ),
        if (snapshot.uncappedCategories.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in snapshot.uncappedCategories.take(10))
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(category.name),
                  onPressed: onEditCap == null
                      ? null
                      : () => onEditCap!(category, null),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BudgetProgressRow extends StatelessWidget {
  const _BudgetProgressRow({required this.budget, required this.onEdit});

  final BudgetProgress budget;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (budget.percentUsed ?? 0).clamp(0, 1).toDouble();
    final color = budget.isOverBudget
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    budget.categoryName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Edit cap',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress, color: color),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text('Spent ${formatMoney(budget.spentAmount)}'),
                Text('Cap ${formatMoney(budget.capAmount)}'),
                Text(
                  budget.isOverBudget
                      ? 'Over ${formatMoney(budget.remainingAmount.abs())}'
                      : 'Left ${formatMoney(budget.remainingAmount)}',
                  style: TextStyle(
                    color: budget.isOverBudget ? theme.colorScheme.error : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 860;

    final children = [
      _CategorySpendList(categories: snapshot.topCategories),
      _MerchantSpendList(merchants: snapshot.topMerchants),
    ];

    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [children[0], const SizedBox(height: 28), children[1]],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: children[0]),
        const SizedBox(width: 24),
        Expanded(child: children[1]),
      ],
    );
  }
}

class _CategorySpendList extends StatelessWidget {
  const _CategorySpendList({required this.categories});

  final List<CategorySpend> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxSpend = categories.isEmpty
        ? 0.0
        : categories
              .map((category) => category.netSpend)
              .reduce((value, element) => value > element ? value : element);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top categories', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          const EmptyState(
            icon: Icons.category_outlined,
            title: 'No category spend',
            message: 'No category totals for this month.',
          )
        else
          for (final category in categories)
            _SpendListItem(
              icon: Icons.category_outlined,
              title: category.categoryName,
              value: formatMoney(category.netSpend),
              supportingText: '${category.transactionCount} transactions',
              progress: maxSpend == 0 ? 0 : category.netSpend / maxSpend,
            ),
      ],
    );
  }
}

class _MerchantSpendList extends StatelessWidget {
  const _MerchantSpendList({required this.merchants});

  final List<MerchantSpend> merchants;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxSpend = merchants.isEmpty
        ? 0.0
        : merchants
              .map((merchant) => merchant.netSpend)
              .reduce((value, element) => value > element ? value : element);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top merchants', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (merchants.isEmpty)
          const EmptyState(
            icon: Icons.storefront_outlined,
            title: 'No merchant spend',
            message: 'No merchant totals for this month.',
          )
        else
          for (final merchant in merchants)
            _SpendListItem(
              icon: Icons.storefront_outlined,
              title: merchant.merchantName,
              value: formatMoney(merchant.netSpend),
              supportingText: '${merchant.transactionCount} transactions',
              progress: maxSpend == 0 ? 0 : merchant.netSpend / maxSpend,
            ),
      ],
    );
  }
}

class _SpendListItem extends StatelessWidget {
  const _SpendListItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.supportingText,
    required this.progress,
  });

  final IconData icon;
  final String title;
  final String value;
  final String supportingText;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(supportingText, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(value, style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress.clamp(0, 1).toDouble()),
          ],
        ),
      ),
    );
  }
}
