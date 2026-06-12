import 'package:flutter/material.dart';
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
          onAddCap: householdContext == null
              ? null
              : () {
                  _showCapDialog(
                    context: context,
                    householdContext: householdContext,
                    snapshot: value,
                  );
                },
          onEditCap: householdContext == null
              ? null
              : (cap) {
                  _showCapDialog(
                    context: context,
                    householdContext: householdContext,
                    snapshot: value,
                    existingCap: cap,
                  );
                },
          onDeleteCap: householdContext == null
              ? null
              : (cap) {
                  _confirmDeleteCap(
                    context: context,
                    householdContext: householdContext,
                    snapshot: value,
                    cap: cap,
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
    MonthlyCapProgress? existingCap,
  }) async {
    final formValue = await showModalBottomSheet<_CapFormValue>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _CapFormSheet(
          categories: snapshot.categoryOptions,
          labels: snapshot.labelOptions,
          existingCap: existingCap,
        );
      },
    );

    if (formValue == null) return;

    await ref
        .read(financeRepositoryProvider)
        .upsertMonthlyCap(
          MonthlyCapUpsertRequest(
            householdId: householdContext.household.id,
            monthlyCapId: existingCap?.monthlyCapId,
            name: formValue.name,
            periodMonth: snapshot.selectedMonth,
            capAmount: formValue.amount,
            categoryIds: formValue.categoryIds,
            labelIds: formValue.labelIds,
          ),
        );

    _refreshDashboard(householdContext, snapshot.selectedMonth);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${formValue.name} cap saved')));
    }
  }

  Future<void> _confirmDeleteCap({
    required BuildContext context,
    required HouseholdContext householdContext,
    required DashboardSnapshot snapshot,
    required MonthlyCapProgress cap,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete ${cap.name}?'),
          content: const Text('This removes only the cap and its targets.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await ref
        .read(financeRepositoryProvider)
        .deleteMonthlyCap(
          MonthlyCapDeleteRequest(
            householdId: householdContext.household.id,
            monthlyCapId: cap.monthlyCapId,
          ),
        );

    _refreshDashboard(householdContext, snapshot.selectedMonth);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${cap.name} cap deleted')));
    }
  }

  void _refreshDashboard(HouseholdContext householdContext, DateTime month) {
    if (mounted) {
      setState(() {
        _selectedMonth = month;
      });
    }

    ref.invalidate(
      dashboardSnapshotProvider(
        FinanceMonthRequest(
          householdId: householdContext.household.id,
          month: month,
        ),
      ),
    );
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
    required this.onAddCap,
    required this.onEditCap,
    required this.onDeleteCap,
    required this.onOpenCategory,
    required this.onOpenMerchant,
  });

  final DashboardSnapshot snapshot;
  final String backendLabel;
  final bool isSupabaseReady;
  final VoidCallback? onAddCap;
  final ValueChanged<MonthlyCapProgress>? onEditCap;
  final ValueChanged<MonthlyCapProgress>? onDeleteCap;
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
        _BudgetSection(
          snapshot: snapshot,
          onAddCap: onAddCap,
          onEditCap: onEditCap,
          onDeleteCap: onDeleteCap,
        ),
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
  const _BudgetSection({
    required this.snapshot,
    required this.onAddCap,
    required this.onEditCap,
    required this.onDeleteCap,
  });

  final DashboardSnapshot snapshot;
  final VoidCallback? onAddCap;
  final ValueChanged<MonthlyCapProgress>? onEditCap;
  final ValueChanged<MonthlyCapProgress>? onDeleteCap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Monthly caps', style: theme.textTheme.titleLarge),
            ),
            FilledButton.icon(
              onPressed: onAddCap,
              icon: const Icon(Icons.add),
              label: const Text('Add cap'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (snapshot.monthlyCapProgress.isEmpty)
          const EmptyState(
            icon: Icons.speed_outlined,
            title: 'No caps set',
            message: 'Add a category or label cap for this month.',
          )
        else
          Column(
            children: [
              for (final cap in snapshot.monthlyCapProgress)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MonthlyCapProgressRow(
                    cap: cap,
                    onEdit: onEditCap == null ? null : () => onEditCap!(cap),
                    onDelete: onDeleteCap == null
                        ? null
                        : () => onDeleteCap!(cap),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _MonthlyCapProgressRow extends StatelessWidget {
  const _MonthlyCapProgressRow({
    required this.cap,
    required this.onEdit,
    required this.onDelete,
  });

  final MonthlyCapProgress cap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (cap.percentUsed ?? 0).clamp(0, 1).toDouble();
    final color = cap.isOverBudget
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final percentText = cap.percentUsed == null
        ? '0%'
        : formatPercent(cap.percentUsed!);

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
                    cap.name,
                    softWrap: true,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Edit cap',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete cap',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
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
                Text(percentText),
                Text('${cap.matchedTransactionCount} matched'),
              ],
            ),
            if (cap.categoryTargets.isNotEmpty ||
                cap.labelTargets.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in cap.categoryTargets)
                    _TargetChip(
                      icon: Icons.category_outlined,
                      label: category.name,
                    ),
                  for (final label in cap.labelTargets)
                    _TargetChip(icon: Icons.label_outline, label: label.name),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _CapFormValue {
  const _CapFormValue({
    required this.name,
    required this.amount,
    required this.categoryIds,
    required this.labelIds,
  });

  final String name;
  final double amount;
  final List<String> categoryIds;
  final List<String> labelIds;
}

class _CapFormSheet extends StatefulWidget {
  const _CapFormSheet({
    required this.categories,
    required this.labels,
    required this.existingCap,
  });

  final List<CategoryOption> categories;
  final List<LabelOption> labels;
  final MonthlyCapProgress? existingCap;

  @override
  State<_CapFormSheet> createState() => _CapFormSheetState();
}

class _CapFormSheetState extends State<_CapFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final Set<String> _selectedCategoryIds;
  late final Set<String> _selectedLabelIds;

  @override
  void initState() {
    super.initState();
    final existingCap = widget.existingCap;
    _nameController = TextEditingController(text: existingCap?.name ?? '');
    _amountController = TextEditingController(
      text: existingCap == null ? '' : _amountText(existingCap.capAmount),
    );
    _selectedCategoryIds = {
      for (final target in existingCap?.categoryTargets ?? const []) target.id,
    };
    _selectedLabelIds = {
      for (final target in existingCap?.labelTargets ?? const []) target.id,
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    final hasTargets =
        _selectedCategoryIds.isNotEmpty || _selectedLabelIds.isNotEmpty;
    final isValid =
        name.isNotEmpty && amount != null && amount >= 0 && hasTargets;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existingCap == null ? 'Add cap' : 'Edit cap',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('cap-name-field'),
                controller: _nameController,
                autofocus: widget.existingCap == null,
                decoration: InputDecoration(
                  labelText: 'Name',
                  errorText: name.isEmpty ? 'Name is required' : null,
                ),
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('cap-amount-field'),
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Monthly amount',
                  prefixText: 'INR ',
                  errorText: amount == null || amount < 0
                      ? 'Enter a valid amount'
                      : null,
                ),
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Text('Categories', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              _TargetSelector<CategoryOption>(
                options: widget.categories,
                selectedIds: _selectedCategoryIds,
                icon: Icons.category_outlined,
                nameFor: (category) => category.name,
                idFor: (category) => category.id,
                onToggle: (id) =>
                    setState(() => _toggle(_selectedCategoryIds, id)),
              ),
              const SizedBox(height: 16),
              Text('Labels', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              _TargetSelector<LabelOption>(
                options: widget.labels,
                selectedIds: _selectedLabelIds,
                icon: Icons.label_outline,
                nameFor: (label) => label.name,
                idFor: (label) => label.id,
                onToggle: (id) =>
                    setState(() => _toggle(_selectedLabelIds, id)),
              ),
              if (!hasTargets) ...[
                const SizedBox(height: 8),
                Text(
                  'Choose at least one target',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: isValid
                        ? () => Navigator.of(context).pop(
                            _CapFormValue(
                              name: name,
                              amount: amount,
                              categoryIds: _orderedSelectedIds(
                                widget.categories,
                                _selectedCategoryIds,
                                (category) => category.id,
                              ),
                              labelIds: _orderedSelectedIds(
                                widget.labels,
                                _selectedLabelIds,
                                (label) => label.id,
                              ),
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.check),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggle(Set<String> selectedIds, String id) {
    if (!selectedIds.add(id)) selectedIds.remove(id);
  }
}

class _TargetSelector<T> extends StatelessWidget {
  const _TargetSelector({
    required this.options,
    required this.selectedIds,
    required this.icon,
    required this.nameFor,
    required this.idFor,
    required this.onToggle,
  });

  final List<T> options;
  final Set<String> selectedIds;
  final IconData icon;
  final String Function(T option) nameFor;
  final String Function(T option) idFor;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const Text('None');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: FilterChip(
              avatar: Icon(icon, size: 18),
              label: Text(
                nameFor(option),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              selected: selectedIds.contains(idFor(option)),
              onSelected: (_) => onToggle(idFor(option)),
            ),
          ),
      ],
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Chip(
        avatar: Icon(icon, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

List<String> _orderedSelectedIds<T>(
  List<T> options,
  Set<String> selectedIds,
  String Function(T option) idFor,
) {
  return [
    for (final option in options)
      if (selectedIds.contains(idFor(option))) idFor(option),
  ];
}

String _amountText(double amount) {
  if (amount == amount.roundToDouble()) return amount.round().toString();

  return amount.toStringAsFixed(2);
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
