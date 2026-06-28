import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/household_repository.dart';
import '../../shared/widgets/app_primitives.dart';

class MonthlyCapTransactionsScreen extends ConsumerStatefulWidget {
  const MonthlyCapTransactionsScreen({
    super.key,
    required this.monthlyCapId,
    required this.periodMonth,
  });

  static const routePath = '/dashboard/monthly-caps/:capId/transactions';
  static const _dashboardRoutePath = '/dashboard';

  final String monthlyCapId;
  final DateTime? periodMonth;

  static String location({
    required String monthlyCapId,
    required DateTime periodMonth,
  }) {
    return Uri(
      path:
          '/dashboard/monthly-caps/${Uri.encodeComponent(monthlyCapId)}/transactions',
      queryParameters: {'month': dateString(firstDayOfMonth(periodMonth))},
    ).toString();
  }

  static DateTime? periodMonthFromUri(Uri uri) {
    final rawMonth = uri.queryParameters['month'];
    if (rawMonth == null) return null;

    final parsed = DateTime.tryParse(rawMonth);
    if (parsed == null) return null;

    final normalized = DateTime(parsed.year, parsed.month, parsed.day);
    final firstDay = firstDayOfMonth(normalized);
    if (normalized != firstDay) return null;

    return firstDay;
  }

  @override
  ConsumerState<MonthlyCapTransactionsScreen> createState() =>
      _MonthlyCapTransactionsScreenState();
}

class _MonthlyCapTransactionsScreenState
    extends ConsumerState<MonthlyCapTransactionsScreen> {
  static const _pageLimit = 10;

  int _offset = 0;

  @override
  void didUpdateWidget(covariant MonthlyCapTransactionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.monthlyCapId != widget.monthlyCapId ||
        oldWidget.periodMonth != widget.periodMonth) {
      _offset = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final periodMonth = widget.periodMonth;
    if (periodMonth == null) {
      return _buildPage(
        title: 'Monthly cap transactions',
        subtitle: 'Dashboard drilldown',
        child: AppErrorState(
          title: 'Monthly cap link unavailable',
          message:
              'Open this view from a Dashboard monthly cap row, or use a first-day month link.',
          action: _BackToDashboardAction(),
        ),
      );
    }

    final householdContextState = ref.watch(householdContextProvider);
    final householdContext = householdContextState.value;
    if (householdContext == null) {
      if (householdContextState.hasError) {
        return _buildPage(
          title: 'Monthly cap transactions',
          subtitle: formatMonth(periodMonth),
          child: AppErrorState(
            title: 'Household unavailable',
            message: householdContextState.error.toString(),
            action: _BackToDashboardAction(),
          ),
        );
      }

      return _buildPage(
        title: 'Monthly cap transactions',
        subtitle: formatMonth(periodMonth),
        child: const AppLoadingState(
          title: 'Loading household context',
          message: 'Preparing this cap drilldown.',
        ),
      );
    }

    final snapshotRequest = FinanceMonthRequest(
      householdId: householdContext.household.id,
      month: periodMonth,
    );
    final snapshotState = ref.watch(dashboardSnapshotProvider(snapshotRequest));

    return switch (snapshotState) {
      AsyncValue(:final value?) => _buildLoadedPage(
        householdContext: householdContext,
        snapshot: value,
        periodMonth: periodMonth,
      ),
      AsyncValue(hasError: true, :final error) => _buildPage(
        title: 'Monthly cap transactions',
        subtitle: formatMonth(periodMonth),
        child: AppErrorState(
          title: 'Cap summary unavailable',
          message: error.toString(),
          action: AppActionPill.secondary(
            label: 'Try again',
            icon: Icons.refresh,
            onPressed: () =>
                ref.invalidate(dashboardSnapshotProvider(snapshotRequest)),
          ),
        ),
      ),
      _ => _buildPage(
        title: 'Monthly cap transactions',
        subtitle: formatMonth(periodMonth),
        child: const AppLoadingState(
          title: 'Loading cap summary',
          message: 'Checking the selected Dashboard month.',
        ),
      ),
    };
  }

  Widget _buildLoadedPage({
    required HouseholdContext householdContext,
    required DashboardSnapshot snapshot,
    required DateTime periodMonth,
  }) {
    final cap = _findCap(snapshot.monthlyCapProgress, widget.monthlyCapId);
    if (cap == null) {
      return _buildPage(
        title: 'Monthly cap transactions',
        subtitle: formatMonth(periodMonth),
        child: EmptyState(
          icon: Icons.speed_outlined,
          title: 'Cap unavailable',
          message:
              'This monthly cap is not active for ${formatMonth(periodMonth)}.',
          action: _BackToDashboardAction(),
        ),
      );
    }

    final request = MonthlyCapTransactionRequest(
      householdId: householdContext.household.id,
      monthlyCapId: cap.monthlyCapId,
      periodMonth: periodMonth,
      limit: _pageLimit,
      offset: _offset,
    );
    final pageState = ref.watch(monthlyCapTransactionsProvider(request));

    return _buildPage(
      title: '${cap.name} transactions',
      subtitle: '${formatMonth(periodMonth)} monthly cap drilldown',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CapSummaryCard(cap: cap, periodMonth: periodMonth),
          const SizedBox(height: 20),
          switch (pageState) {
            AsyncValue(:final value?) => _CapTransactionList(
              page: value,
              pageNumber: (_offset ~/ _pageLimit) + 1,
              onPreviousPage: _offset == 0
                  ? null
                  : () {
                      setState(() {
                        _offset = _offset - _pageLimit < 0
                            ? 0
                            : _offset - _pageLimit;
                      });
                    },
              onNextPage: value.hasMore
                  ? () {
                      setState(() {
                        _offset = value.nextOffset;
                      });
                    }
                  : null,
            ),
            AsyncValue(hasError: true, :final error) => AppErrorState(
              title: 'Transactions unavailable',
              message: error.toString(),
              action: AppActionPill.secondary(
                label: 'Try again',
                icon: Icons.refresh,
                onPressed: () =>
                    ref.invalidate(monthlyCapTransactionsProvider(request)),
              ),
            ),
            _ => const AppLoadingState(
              title: 'Loading transactions',
              message: 'Fetching cap matches from the monthly cap contract.',
            ),
          },
        ],
      ),
    );
  }

  Widget _buildPage({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return AppPage(
      title: title,
      subtitle: subtitle,
      stackActions: false,
      actions: const [_MonthlyCapBackButton()],
      child: child,
    );
  }
}

class _MonthlyCapBackButton extends StatelessWidget {
  const _MonthlyCapBackButton();

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.maybeOf(context);

    return TextButton.icon(
      onPressed: router == null
          ? null
          : () {
              if (router.canPop()) {
                router.pop();
                return;
              }

              router.go(MonthlyCapTransactionsScreen._dashboardRoutePath);
            },
      icon: const Icon(Icons.arrow_back),
      label: const Text('Back'),
    );
  }
}

class _BackToDashboardAction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final router = GoRouter.maybeOf(context);

    return AppActionPill.secondary(
      label: 'Back to Dashboard',
      icon: Icons.dashboard_outlined,
      onPressed: router == null
          ? null
          : () => router.go(MonthlyCapTransactionsScreen._dashboardRoutePath),
    );
  }
}

class _CapSummaryCard extends StatelessWidget {
  const _CapSummaryCard({required this.cap, required this.periodMonth});

  final MonthlyCapProgress cap;
  final DateTime periodMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semanticColors = theme.extension<AppSemanticColors>();
    final summaryTone = cap.isOverBudget
        ? AppStatusTone.negative
        : AppStatusTone.positive;
    final progressLabel = cap.percentUsed == null
        ? 'No spend yet'
        : formatPercent(cap.percentUsed!);
    final balanceLabel = cap.isOverBudget ? 'Over' : 'Left';
    final balanceAmount = cap.isOverBudget
        ? cap.remainingAmount.abs()
        : cap.remainingAmount;

    return AppContentCard(
      padding: const EdgeInsets.all(24),
      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final amountBlock = Column(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              Text(
                balanceLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              LargeAmountText(
                formatMoney(balanceAmount),
                textAlign: compact ? TextAlign.start : TextAlign.end,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: cap.isOverBudget
                      ? theme.colorScheme.error
                      : semanticColors?.positive ?? theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  height: 1,
                ),
              ),
              const SizedBox(height: 10),
              StatusChip(
                label: progressLabel,
                tone: summaryTone,
                icon: cap.isOverBudget
                    ? Icons.warning_amber_outlined
                    : Icons.check_circle_outline,
              ),
            ],
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatMonth(periodMonth)} summary',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                cap.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _SummaryMetric(
                    label: 'Spent',
                    value: formatMoney(cap.spentAmount),
                  ),
                  _SummaryMetric(
                    label: 'Base',
                    value: formatMoney(cap.baseCapAmount),
                  ),
                  _SummaryMetric(
                    label: 'Available',
                    value: formatMoney(cap.effectiveCapAmount),
                  ),
                  if (cap.carryForwardAmount != 0)
                    _SummaryMetric(
                      label: 'Carried',
                      value: formatSignedMoney(cap.carryForwardAmount),
                    ),
                  _SummaryMetric(
                    label: 'Matched',
                    value:
                        '${cap.matchedTransactionCount} transaction${cap.matchedTransactionCount == 1 ? '' : 's'}',
                  ),
                ],
              ),
              if (cap.categoryTargets.isNotEmpty ||
                  cap.labelTargets.isNotEmpty) ...[
                const SizedBox(height: 16),
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

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [details, const SizedBox(height: 20), amountBlock],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: amountBlock,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CapTransactionList extends StatelessWidget {
  const _CapTransactionList({
    required this.page,
    required this.pageNumber,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final MonthlyCapTransactionPage page;
  final int pageNumber;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    if (page.items.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No cap transactions',
        message: page.offset == 0
            ? 'No transactions matched this cap for the selected month.'
            : 'There are no more transactions on this page.',
        action: page.offset == 0
            ? null
            : AppActionPill.secondary(
                label: 'Previous page',
                icon: Icons.chevron_left,
                onPressed: onPreviousPage,
              ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final transaction in page.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _CapTransactionCard(transaction: transaction),
          ),
        const SizedBox(height: 8),
        _PaginationControls(
          pageNumber: pageNumber,
          onPreviousPage: onPreviousPage,
          onNextPage: onNextPage,
        ),
      ],
    );
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.pageNumber,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final int pageNumber;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Page $pageNumber',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        AppActionPill.secondary(
          label: 'Previous',
          icon: Icons.chevron_left,
          onPressed: onPreviousPage,
        ),
        AppActionPill.primary(
          label: 'Next page',
          icon: Icons.chevron_right,
          onPressed: onNextPage,
        ),
      ],
    );
  }
}

class _CapTransactionCard extends StatelessWidget {
  const _CapTransactionCard({required this.transaction});

  final MonthlyCapTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semanticColors = theme.extension<AppSemanticColors>();
    final amountColor = transaction.netExpense < 0
        ? theme.colorScheme.tertiary
        : transaction.isBillPayment
        ? theme.colorScheme.outline
        : theme.colorScheme.primary;
    final reviewColor = semanticColors?.warning ?? theme.colorScheme.tertiary;
    final title = _titleFor(transaction);
    final subtitle = _subtitleFor(transaction, title);

    return AppContentCard(
      padding: const EdgeInsets.all(20),
      borderSide: BorderSide(
        color: transaction.isUnderReview
            ? reviewColor
            : theme.colorScheme.outlineVariant,
        width: transaction.isUnderReview ? 2 : 1,
      ),
      semanticLabel: '$title, ${formatMoney(transaction.netExpense)}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final iconChip = _TransactionIconChip(
            icon: _iconFor(transaction),
            color: amountColor,
          );
          final details = _TransactionDetails(
            title: title,
            subtitle: subtitle,
            labels: transaction.labels,
            notes: transaction.notes,
            isUnderReview: transaction.isUnderReview,
          );
          final amount = Text(
            formatMoney(transaction.netExpense),
            textAlign: compact ? TextAlign.start : TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          );

          if (compact) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconChip,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [details, const SizedBox(height: 12), amount],
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              iconChip,
              const SizedBox(width: 16),
              Expanded(child: details),
              const SizedBox(width: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: amount,
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _iconFor(MonthlyCapTransaction transaction) {
    if (transaction.isRefund) return Icons.keyboard_return_outlined;
    if (transaction.isBillPayment) return Icons.account_balance_wallet_outlined;

    return Icons.receipt_long_outlined;
  }

  String _titleFor(MonthlyCapTransaction transaction) {
    final merchantName = transaction.merchantName?.trim();
    if (merchantName != null && merchantName.isNotEmpty) {
      return merchantName;
    }

    return transaction.statementMerchant;
  }

  String _subtitleFor(MonthlyCapTransaction transaction, String title) {
    final statementMerchant = transaction.statementMerchant.trim();
    final pieces = [
      dateString(transaction.transactionDate),
      if (statementMerchant.isNotEmpty && statementMerchant != title)
        statementMerchant,
      if (transaction.categoryName != null) transaction.categoryName!,
      if (transaction.subcategoryName != null) transaction.subcategoryName!,
      _titleCase(transaction.transactionType),
      if (transaction.cardholderName != null) transaction.cardholderName!,
    ];

    return pieces.join(' - ');
  }
}

class _TransactionDetails extends StatelessWidget {
  const _TransactionDetails({
    required this.title,
    required this.subtitle,
    required this.labels,
    required this.notes,
    required this.isUnderReview,
  });

  final String title;
  final String subtitle;
  final List<LabelOption> labels;
  final String? notes;
  final bool isUnderReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmedNotes = notes?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        if (isUnderReview) ...[
          const SizedBox(height: 8),
          const StatusChip(
            label: 'Under review',
            tone: AppStatusTone.warning,
            icon: Icons.warning_amber_outlined,
          ),
        ],
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (labels.isNotEmpty) ...[
          const SizedBox(height: 10),
          _LabelChips(labels: labels),
        ],
        if (trimmedNotes != null && trimmedNotes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            trimmedNotes,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _TransactionIconChip extends StatelessWidget {
  const _TransactionIconChip({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.14),
        shape: const OvalBorder(),
      ),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

class _LabelChips extends StatelessWidget {
  const _LabelChips({required this.labels});

  final List<LabelOption> labels;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final label in labels)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Chip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
              avatar: const Icon(Icons.label_outline, size: 16),
              label: Text(
                label.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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

MonthlyCapProgress? _findCap(List<MonthlyCapProgress> caps, String capId) {
  for (final cap in caps) {
    if (cap.monthlyCapId == capId) return cap;
  }

  return null;
}

String _titleCase(String value) {
  final words = value
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.trim().isNotEmpty);
  if (words.isEmpty) return value;

  return words
      .map((word) {
        final lower = word.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}
