import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/household_repository.dart';
import '../../shared/widgets/app_primitives.dart';
import '../activity/activity_screen.dart';
import '../settings/settings_screen.dart';

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
      stackActions: false,
      actions: [
        if (snapshotState.hasValue)
          IconButton(
            tooltip: 'Open settings',
            onPressed: () => context.go(SettingsScreen.routePath),
            icon: const Icon(Icons.settings_outlined),
          ),
      ],
      child: switch (snapshotState) {
        AsyncValue(:final value?) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IntrinsicWidth(
                child: _MonthSelector(
                  months: value.availableMonths,
                  selectedMonth: value.selectedMonth,
                  onChanged: (month) {
                    setState(() {
                      _selectedMonth = month;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            _DashboardContent(
              snapshot: value,
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
          ],
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

  Future<void> _showCapDialog({
    required BuildContext context,
    required HouseholdContext householdContext,
    required DashboardSnapshot snapshot,
    MonthlyCapProgress? existingCap,
  }) async {
    final formValue = await showModalBottomSheet<_CapFormValue>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CapFormSheet(
          categories: snapshot.categoryOptions,
          labels: snapshot.labelOptions,
          existingCap: existingCap,
          selectedMonth: snapshot.selectedMonth,
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
            carryForwardEnabled: formValue.carryForwardEnabled,
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
        return AppModalDialog(
          title: 'Stop ${cap.name}?',
          maxWidth: 520,
          actions: [
            AppActionPill.secondary(
              label: 'Cancel',
              onPressed: () => Navigator.of(context).pop(false),
            ),
            AppActionPill.destructive(
              label: 'Stop cap',
              icon: Icons.delete_outline,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
          child: Text(
            'This stops the cap from ${formatMonth(snapshot.selectedMonth)} onward. Earlier months stay visible, and transactions, categories, labels, merchant rules, and review rows stay unchanged.',
          ),
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
            periodMonth: snapshot.selectedMonth,
          ),
        );

    _refreshDashboard(householdContext, snapshot.selectedMonth);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${cap.name} cap stopped')));
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
        path: ActivityScreen.routePath,
        queryParameters: queryParameters,
      ).toString(),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.snapshot,
    required this.onAddCap,
    required this.onEditCap,
    required this.onDeleteCap,
    required this.onOpenCategory,
    required this.onOpenMerchant,
  });

  final DashboardSnapshot snapshot;
  final VoidCallback? onAddCap;
  final ValueChanged<MonthlyCapProgress>? onEditCap;
  final ValueChanged<MonthlyCapProgress>? onDeleteCap;
  final ValueChanged<CategorySpend> onOpenCategory;
  final ValueChanged<MerchantSpend> onOpenMerchant;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final sectionGap = width >= AppResponsiveBreakpoints.tabletMinWidth
            ? 36.0
            : 32.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SpendingSection(snapshot: snapshot),
            SizedBox(height: sectionGap),
            _ReviewSection(reviewQueueCount: snapshot.reviewQueueCount),
            SizedBox(height: sectionGap),
            _MonthlyCapsSection(
              snapshot: snapshot,
              onAddCap: onAddCap,
              onEditCap: onEditCap,
              onDeleteCap: onDeleteCap,
            ),
            SizedBox(height: sectionGap),
            _SummaryGrid(
              snapshot: snapshot,
              onOpenCategory: onOpenCategory,
              onOpenMerchant: onOpenMerchant,
            ),
          ],
        );
      },
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

    return PopupMenuButton<DateTime>(
      tooltip: 'Select reporting month',
      initialValue: selectedMonth,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final month in items)
          PopupMenuItem(value: month, child: Text(formatMonth(month))),
      ],
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: StadiumBorder(
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatMonth(selectedMonth),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.expand_more,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.title,
    this.trailing,
    required this.child,
  });

  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeading(title: title, trailing: trailing),
        const SizedBox(height: 24),
        child,
      ],
    );
  }
}

class _SpendingSection extends StatelessWidget {
  const _SpendingSection({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _DashboardSection(
      title: 'Spending',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final isWide = width >= AppResponsiveBreakpoints.tabletMinWidth;
          final netCard = _NetSpendCard(snapshot: snapshot);
          final changeCard = _MonthChangeCard(snapshot: snapshot);

          if (!isWide) {
            return Column(
              children: [netCard, const SizedBox(height: 16), changeCard],
            );
          }

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: netCard),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: changeCard),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NetSpendCard extends StatelessWidget {
  const _NetSpendCard({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountColor = theme.brightness == Brightness.dark
        ? AppThemeTokens.primaryActive
        : AppThemeTokens.inkDeep;

    return AppContentCard(
      padding: const EdgeInsets.all(24),
      borderSide: BorderSide(color: theme.colorScheme.surfaceContainer),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatMonth(snapshot.selectedMonth)} net',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 16),
          LargeAmountText(
            formatMoney(snapshot.monthlySpend.netSpend),
            style: theme.textTheme.displaySmall?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${snapshot.monthlySpend.transactionCount} transactions',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _MonthChangeCard extends StatelessWidget {
  const _MonthChangeCard({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semanticColors = theme.extension<AppSemanticColors>();
    final change = snapshot.monthOverMonthChange;
    final isPositive = change > 0;
    final isNegative = change < 0;
    final tone = isNegative
        ? AppStatusTone.negative
        : isPositive
        ? AppStatusTone.positive
        : AppStatusTone.neutral;
    final trendColor = isNegative
        ? theme.colorScheme.error
        : isPositive
        ? semanticColors?.positive ?? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final percentText = snapshot.monthOverMonthPercent == null
        ? 'No previous month'
        : _formatSignedPercent(snapshot.monthOverMonthPercent!);

    return AppContentCard(
      padding: const EdgeInsets.all(24),
      borderSide: BorderSide(color: theme.colorScheme.surfaceContainer),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Month Change',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                isNegative
                    ? Icons.trending_down
                    : isPositive
                    ? Icons.trending_up
                    : Icons.trending_flat,
                color: trendColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LargeAmountText(
                  formatSignedMoney(change),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StatusChip(label: percentText, tone: tone),
        ],
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.reviewQueueCount});

  final int reviewQueueCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semanticColors = theme.extension<AppSemanticColors>();
    final itemLabel = reviewQueueCount == 1
        ? '1 Item'
        : '$reviewQueueCount Items';

    return _DashboardSection(
      title: 'Review',
      child: AppContentCard(
        padding: const EdgeInsets.all(24),
        backgroundColor: theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainerHigh
            : AppThemeTokens.primaryPale,
        foregroundColor: theme.colorScheme.onSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review Queue',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.pending_actions_outlined,
                  color: semanticColors?.warning ?? AppThemeTokens.warningDeep,
                ),
                const SizedBox(width: 10),
                Text(
                  itemLabel,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
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

class _MonthlyCapsSection extends StatelessWidget {
  const _MonthlyCapsSection({
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
    return _DashboardSection(
      title: 'Monthly caps',
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusChip(
            label: snapshot.uncappedTargetCount == 0
                ? 'All cap targets covered'
                : '${snapshot.uncappedTargetCount} targets without caps',
            icon: Icons.speed_outlined,
          ),
          AppActionPill.primary(
            label: 'Add cap',
            icon: Icons.add,
            tooltip: 'Add monthly cap',
            onPressed: onAddCap,
          ),
        ],
      ),
      child: snapshot.monthlyCapProgress.isEmpty
          ? const EmptyState(
              icon: Icons.speed_outlined,
              title: 'No caps set',
              message:
                  'Add a recurring category or label cap starting this month.',
            )
          : Column(
              children: [
                for (final cap in snapshot.monthlyCapProgress)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 22),
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
    final semanticColors = theme.extension<AppSemanticColors>();
    final color = cap.isOverBudget
        ? theme.colorScheme.error
        : progress >= 0.85
        ? semanticColors?.warning ?? AppThemeTokens.warning
        : theme.colorScheme.primary;
    final percentText = cap.percentUsed == null
        ? '0%'
        : formatPercent(cap.percentUsed!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                cap.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Edit cap',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Stop cap',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: progress,
            color: color,
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _CapDetailText('Spent ${formatMoney(cap.spentAmount)}'),
            _CapDetailText('Base ${formatMoney(cap.baseCapAmount)}'),
            if (cap.carryForwardAmount != 0)
              _CapDetailText(
                'Carried ${formatSignedMoney(cap.carryForwardAmount)}',
                color: cap.carryForwardAmount < 0
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            _CapDetailText(
              'Available ${formatMoney(cap.effectiveCapAmount)}',
              color: cap.effectiveCapAmount <= 0
                  ? theme.colorScheme.error
                  : null,
            ),
            _CapDetailText(
              cap.isOverBudget
                  ? 'Over ${formatMoney(cap.remainingAmount.abs())}'
                  : 'Left ${formatMoney(cap.remainingAmount)}',
              color: cap.isOverBudget ? theme.colorScheme.error : null,
            ),
            _CapDetailText(percentText),
            _CapDetailText('${cap.matchedTransactionCount} matched'),
          ],
        ),
        if (cap.categoryTargets.isNotEmpty || cap.labelTargets.isNotEmpty) ...[
          const SizedBox(height: 12),
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
    );
  }
}

class _CapDetailText extends StatelessWidget {
  const _CapDetailText(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
    );
  }
}

final class _CapFormValue {
  const _CapFormValue({
    required this.name,
    required this.amount,
    required this.carryForwardEnabled,
    required this.categoryIds,
    required this.labelIds,
  });

  final String name;
  final double amount;
  final bool carryForwardEnabled;
  final List<String> categoryIds;
  final List<String> labelIds;
}

class _CapFormSheet extends StatefulWidget {
  const _CapFormSheet({
    required this.categories,
    required this.labels,
    required this.existingCap,
    required this.selectedMonth,
  });

  final List<CategoryOption> categories;
  final List<LabelOption> labels;
  final MonthlyCapProgress? existingCap;
  final DateTime selectedMonth;

  @override
  State<_CapFormSheet> createState() => _CapFormSheetState();
}

class _CapFormSheetState extends State<_CapFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final Set<String> _selectedCategoryIds;
  late final Set<String> _selectedLabelIds;
  late bool _carryForwardEnabled;

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
    _carryForwardEnabled = existingCap?.carryForwardEnabled ?? false;
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
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    final hasTargets =
        _selectedCategoryIds.isNotEmpty || _selectedLabelIds.isNotEmpty;
    final isValid =
        name.isNotEmpty && amount != null && amount >= 0 && hasTargets;

    return AppModalCardShell(
      title: widget.existingCap == null ? 'Add cap' : 'Edit cap',
      subtitle: widget.existingCap == null
          ? 'Starts in ${formatMonth(widget.selectedMonth)} and repeats until stopped.'
          : 'Saves from ${formatMonth(widget.selectedMonth)} onward.',
      maxWidth: 560,
      actions: [
        AppActionPill.secondary(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppActionPill.primary(
          label: 'Save',
          icon: Icons.check,
          onPressed: isValid
              ? () => Navigator.of(context).pop(
                  _CapFormValue(
                    name: name,
                    amount: amount,
                    carryForwardEnabled: _carryForwardEnabled,
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
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            key: const ValueKey('cap-carry-forward-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Carry forward remainder'),
            value: _carryForwardEnabled,
            onChanged: (value) => setState(() => _carryForwardEnabled = value),
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
            onToggle: (id) => setState(() => _toggle(_selectedCategoryIds, id)),
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
            onToggle: (id) => setState(() => _toggle(_selectedLabelIds, id)),
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
        ],
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final isWide = width >= 860;
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
            children: [children[0], const SizedBox(height: 32), children[1]],
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
      },
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
    return _DashboardSection(
      title: 'Top categories',
      child: categories.isEmpty
          ? const EmptyState(
              icon: Icons.category_outlined,
              title: 'No category spend',
              message: 'No category totals for this month.',
            )
          : Column(
              children: [
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SpendListItem(
                      icon: Icons.category_outlined,
                      title: category.categoryName,
                      value: formatMoney(category.netSpend),
                      supportingText:
                          '${category.transactionCount} transactions',
                      onTap: () => onOpenCategory(category),
                    ),
                  ),
              ],
            ),
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
    return _DashboardSection(
      title: 'Top merchants',
      child: merchants.isEmpty
          ? const EmptyState(
              icon: Icons.storefront_outlined,
              title: 'No merchant spend',
              message: 'No merchant totals for this month.',
            )
          : Column(
              children: [
                for (final merchant in merchants)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SpendListItem(
                      icon: Icons.storefront_outlined,
                      title: merchant.merchantName,
                      value: formatMoney(merchant.netSpend),
                      supportingText:
                          '${merchant.transactionCount} transactions',
                      onTap: () => onOpenMerchant(merchant),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SpendListItem extends StatelessWidget {
  const _SpendListItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.supportingText,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String supportingText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppContentCard(
      padding: const EdgeInsets.all(16),
      borderSide: BorderSide(color: theme.colorScheme.surfaceContainer),
      onTap: onTap,
      semanticLabel: '$title, $supportingText, $value',
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: ShapeDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              shape: const OvalBorder(),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
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
                const SizedBox(height: 2),
                Text(
                  supportingText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 112),
            child: LargeAmountText(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
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
    );
  }
}

String _formatSignedPercent(double value) {
  if (value == 0) return formatPercent(0);

  final sign = value > 0 ? '+' : '-';
  return '$sign${formatPercent(value.abs())}';
}
