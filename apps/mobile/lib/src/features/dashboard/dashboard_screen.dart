import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/household_repository.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/metric_card.dart';
import '../transactions/transactions_screen.dart';

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
              : (category, existingCap) {
                  _showCapDialog(
                    context: context,
                    householdContext: householdContext,
                    snapshot: value,
                    category: category,
                    existingCap: existingCap,
                  );
                },
          onOpenCategory: (category) {
            _openTransactionsDrilldown(
              month: value.selectedMonth,
              categoryId: category.categoryId,
            );
          },
          onOpenMerchant: (merchant) {
            _openTransactionsDrilldown(
              month: value.selectedMonth,
              merchant: merchant.merchantName,
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
    required MonthlyCapProgress? existingCap,
  }) async {
    var amountText = existingCap == null
        ? ''
        : existingCap.capAmount.round().toString();

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
        .upsertMonthlyCap(
          MonthlyCapUpsertRequest(
            householdId: householdContext.household.id,
            monthlyCapId: existingCap?.monthlyCapId,
            name: category.name,
            periodMonth: snapshot.selectedMonth,
            capAmount: amount,
            categoryIds: [category.id],
          ),
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

  void _openTransactionsDrilldown({
    required DateTime month,
    String? categoryId,
    String? merchant,
  }) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;

    final startDate = firstDayOfMonth(month);
    final endDate = addMonths(startDate, 1).subtract(const Duration(days: 1));
    final queryParameters = <String, String>{
      'startDate': dateString(startDate),
      'endDate': dateString(endDate),
    };
    if (categoryId != null) queryParameters['categoryId'] = categoryId;
    if (merchant != null) queryParameters['merchant'] = merchant;

    router.go(
      Uri(
        path: TransactionsScreen.routePath,
        queryParameters: queryParameters,
      ).toString(),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.snapshot,
    required this.backendLabel,
    required this.isSupabaseReady,
    required this.onEditCap,
    required this.onOpenCategory,
    required this.onOpenMerchant,
  });

  final DashboardSnapshot snapshot;
  final String backendLabel;
  final bool isSupabaseReady;
  final void Function(CategoryOption category, MonthlyCapProgress? existingCap)?
  onEditCap;
  final ValueChanged<CategorySpend> onOpenCategory;
  final ValueChanged<MerchantSpend> onOpenMerchant;

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
        _SummaryGrid(
          snapshot: snapshot,
          onOpenCategory: onOpenCategory,
          onOpenMerchant: onOpenMerchant,
        ),
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
  final void Function(CategoryOption category, MonthlyCapProgress? existingCap)?
  onEditCap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Monthly caps', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (snapshot.monthlyCapProgress.isEmpty)
          const EmptyState(
            icon: Icons.speed_outlined,
            title: 'No caps set',
            message: 'Categories without caps are listed below.',
          )
        else
          Column(
            children: [
              for (final cap in snapshot.monthlyCapProgress)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MonthlyCapProgressRow(
                    cap: cap,
                    onEdit: onEditCap == null
                        ? null
                        : () {
                            final categoryTarget = cap.singleCategoryTarget;
                            if (categoryTarget == null) return;

                            onEditCap!(
                              CategoryOption(
                                id: categoryTarget.id,
                                name: categoryTarget.name,
                              ),
                              cap,
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

class _MonthlyCapProgressRow extends StatelessWidget {
  const _MonthlyCapProgressRow({required this.cap, required this.onEdit});

  final MonthlyCapProgress cap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (cap.percentUsed ?? 0).clamp(0, 1).toDouble();
    final color = cap.isOverBudget
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final categoryTarget = cap.singleCategoryTarget;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(cap.name, style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: 'Edit cap',
                  onPressed: categoryTarget == null ? null : onEdit,
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
                Text('Spent ${formatMoney(cap.spentAmount)}'),
                Text('Cap ${formatMoney(cap.capAmount)}'),
                Text(
                  cap.isOverBudget
                      ? 'Over ${formatMoney(cap.remainingAmount.abs())}'
                      : 'Left ${formatMoney(cap.remainingAmount)}',
                  style: TextStyle(
                    color: cap.isOverBudget ? theme.colorScheme.error : null,
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
  const _SummaryGrid({
    required this.snapshot,
    required this.onOpenCategory,
    required this.onOpenMerchant,
  });

  final DashboardSnapshot snapshot;
  final ValueChanged<CategorySpend> onOpenCategory;
  final ValueChanged<MerchantSpend> onOpenMerchant;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 860;

    final children = [
      _CategorySpendList(
        categories: snapshot.topCategories,
        onOpenCategory: onOpenCategory,
      ),
      _MerchantSpendList(
        merchants: snapshot.topMerchants,
        onOpenMerchant: onOpenMerchant,
      ),
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
  const _CategorySpendList({
    required this.categories,
    required this.onOpenCategory,
  });

  final List<CategorySpend> categories;
  final ValueChanged<CategorySpend> onOpenCategory;

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
              onTap: () => onOpenCategory(category),
            ),
      ],
    );
  }
}

class _MerchantSpendList extends StatelessWidget {
  const _MerchantSpendList({
    required this.merchants,
    required this.onOpenMerchant,
  });

  final List<MerchantSpend> merchants;
  final ValueChanged<MerchantSpend> onOpenMerchant;

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
              onTap: () => onOpenMerchant(merchant),
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
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String supportingText;
  final double progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: theme.colorScheme.outline,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: progress.clamp(0, 1).toDouble()),
            ],
          ),
        ),
      ),
    );
  }
}
