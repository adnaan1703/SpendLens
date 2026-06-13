import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/household_repository.dart';
import '../../shared/widgets/action_pill.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/metric_card.dart';
import '../../shared/widgets/period_filter_dropdown.dart';

class ActivityChartsPane extends ConsumerStatefulWidget {
  const ActivityChartsPane({super.key});

  @override
  ConsumerState<ActivityChartsPane> createState() => _ActivityChartsPaneState();
}

class _ActivityChartsPaneState extends ConsumerState<ActivityChartsPane> {
  String? _categoryId;
  String? _sourceAccountType;
  String? _sourceAccountId;
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final householdContext = ref.watch(householdContextProvider).value;
    final householdId = householdContext?.household.id;
    final categories = householdId == null
        ? const AsyncValue<List<CategoryOption>>.loading()
        : ref.watch(transactionCategoriesProvider(householdId));
    final sourceAccounts = householdId == null
        ? const AsyncValue<List<SourceAccountOption>>.loading()
        : ref.watch(transactionSourceAccountsProvider(householdId));
    final availableMonths = householdId == null
        ? const AsyncValue<List<DateTime>>.loading()
        : ref.watch(availableMonthsProvider(householdId));
    final query = householdId == null
        ? null
        : TrendQuery(
            householdId: householdId,
            categoryId: _categoryId,
            sourceAccountType: _sourceAccountType,
            sourceAccountId: _sourceAccountId,
            startDate: _dateRange?.start,
            endDate: _dateRange?.end,
          );
    final report = query == null
        ? const AsyncValue<TrendReport>.loading()
        : ref.watch(trendReportProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TrendFilters(
          categories: categories.value ?? const [],
          selectedCategoryId: _categoryId,
          sourceAccounts: sourceAccounts.value ?? const [],
          selectedSourceAccountType: _sourceAccountType,
          selectedSourceAccountId: _sourceAccountId,
          availableMonths: availableMonths.value ?? const [],
          dateRange: _dateRange,
          report: report.value,
          onCategoryChanged: (value) {
            setState(() {
              _categoryId = value;
            });
          },
          onSourceAccountTypeChanged: (value) {
            setState(() {
              _sourceAccountType = value;
              if (value != null &&
                  _sourceAccountId != null &&
                  !(sourceAccounts.value ?? const []).any(
                    (source) =>
                        source.id == _sourceAccountId && source.type == value,
                  )) {
                _sourceAccountId = null;
              }
            });
          },
          onSourceAccountChanged: (value) {
            setState(() {
              _sourceAccountId = value;
            });
          },
          onPeriodChanged: _handlePeriodChanged,
          onClear: _clearFilters,
          onCopyCsv: _copyCsv,
        ),
        const SizedBox(height: 20),
        switch (report) {
          AsyncValue(:final value?) => _TrendReportView(report: value),
          AsyncValue(hasError: true, :final error) => EmptyState(
            icon: Icons.error_outline,
            title: 'Charts unavailable',
            message: error.toString(),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ],
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _dateRange,
    );

    if (range == null) return;

    setState(() {
      _dateRange = range;
    });
  }

  void _handlePeriodChanged(PeriodFilterSelection selection) {
    switch (selection.type) {
      case PeriodFilterSelectionType.allDates:
        setState(() {
          _dateRange = null;
        });
      case PeriodFilterSelectionType.month:
        setState(() {
          _dateRange = selection.dateRange;
        });
      case PeriodFilterSelectionType.customDateRange:
        _pickDateRange();
    }
  }

  void _clearFilters() {
    setState(() {
      _categoryId = null;
      _sourceAccountType = null;
      _sourceAccountId = null;
      _dateRange = null;
    });
  }

  Future<void> _copyCsv(TrendReport report) async {
    await Clipboard.setData(ClipboardData(text: report.toTransactionsCsv()));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('CSV copied for ${report.transactionCount} transactions'),
      ),
    );
  }
}

class _TrendFilters extends StatelessWidget {
  const _TrendFilters({
    required this.categories,
    required this.selectedCategoryId,
    required this.sourceAccounts,
    required this.selectedSourceAccountType,
    required this.selectedSourceAccountId,
    required this.availableMonths,
    required this.dateRange,
    required this.report,
    required this.onCategoryChanged,
    required this.onSourceAccountTypeChanged,
    required this.onSourceAccountChanged,
    required this.onPeriodChanged,
    required this.onClear,
    required this.onCopyCsv,
  });

  final List<CategoryOption> categories;
  final String? selectedCategoryId;
  final List<SourceAccountOption> sourceAccounts;
  final String? selectedSourceAccountType;
  final String? selectedSourceAccountId;
  final List<DateTime> availableMonths;
  final DateTimeRange? dateRange;
  final TrendReport? report;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onSourceAccountTypeChanged;
  final ValueChanged<String?> onSourceAccountChanged;
  final ValueChanged<PeriodFilterSelection> onPeriodChanged;
  final VoidCallback onClear;
  final ValueChanged<TrendReport> onCopyCsv;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFilters =
        selectedCategoryId != null ||
        selectedSourceAccountType != null ||
        selectedSourceAccountId != null ||
        dateRange != null;
    final loadedReport = report;
    final hasSelectedCategory =
        selectedCategoryId == null ||
        categories.any((category) => category.id == selectedCategoryId);
    final filteredSourceAccounts = selectedSourceAccountType == null
        ? sourceAccounts
        : sourceAccounts
              .where((source) => source.type == selectedSourceAccountType)
              .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final compact = layoutWidth < 640;
        final fullWidth = math.max(0.0, layoutWidth);
        final categoryWidth = compact ? fullWidth : 300.0;
        final sourceTypeWidth = compact ? math.min(fullWidth, 220.0) : 220.0;
        final sourceWidth = compact ? fullWidth : 340.0;
        final periodWidth = compact ? math.min(fullWidth, 260.0) : 260.0;
        final pillBorder = OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
        );
        final pillDecoration = InputDecoration(
          filled: true,
          fillColor: theme.colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 12,
          ),
          border: pillBorder,
          enabledBorder: pillBorder.copyWith(
            borderSide: BorderSide(color: theme.colorScheme.outline),
          ),
        );

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: categoryWidth,
              child: DropdownButtonFormField<String>(
                key: ValueKey('trend-category-$selectedCategoryId'),
                isExpanded: true,
                initialValue: selectedCategoryId,
                decoration: pillDecoration.copyWith(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All categories'),
                  ),
                  if (!hasSelectedCategory)
                    DropdownMenuItem(
                      value: selectedCategoryId,
                      child: const Text('Selected category'),
                    ),
                  for (final category in categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: onCategoryChanged,
              ),
            ),
            SizedBox(
              width: sourceTypeWidth,
              child: DropdownButtonFormField<String>(
                key: ValueKey('trend-source-type-$selectedSourceAccountType'),
                isExpanded: true,
                initialValue: selectedSourceAccountType,
                decoration: pillDecoration.copyWith(
                  labelText: 'Source type',
                  prefixIcon: const Icon(Icons.account_balance_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All types')),
                  DropdownMenuItem(
                    value: 'credit_card',
                    child: Text('Credit card'),
                  ),
                  DropdownMenuItem(value: 'upi', child: Text('UPI')),
                ],
                onChanged: onSourceAccountTypeChanged,
              ),
            ),
            SizedBox(
              width: sourceWidth,
              child: DropdownButtonFormField<String>(
                key: ValueKey('trend-source-$selectedSourceAccountId'),
                isExpanded: true,
                initialValue: selectedSourceAccountId,
                decoration: pillDecoration.copyWith(
                  labelText: 'Source',
                  prefixIcon: const Icon(Icons.credit_card_outlined),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All sources'),
                  ),
                  for (final source in filteredSourceAccounts)
                    DropdownMenuItem(
                      value: source.id,
                      child: Text(source.label),
                    ),
                ],
                onChanged: onSourceAccountChanged,
              ),
            ),
            PeriodFilterDropdown(
              availableMonths: availableMonths,
              selectedRange: dateRange,
              pillStyle: true,
              width: periodWidth,
              onChanged: onPeriodChanged,
            ),
            IconButton.filledTonal(
              tooltip: 'Clear filters',
              onPressed: hasFilters ? onClear : null,
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
            AppActionPill.secondary(
              label: 'Copy CSV',
              icon: Icons.copy_all_outlined,
              tooltip: 'Copy filtered transactions as CSV',
              onPressed: loadedReport == null || loadedReport.isEmpty
                  ? null
                  : () => onCopyCsv(loadedReport),
            ),
          ],
        );
      },
    );
  }
}

class _TrendReportView extends StatelessWidget {
  const _TrendReportView({required this.report});

  final TrendReport report;

  @override
  Widget build(BuildContext context) {
    if (report.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart_outlined,
        title: 'No chart data',
        message: 'No transactions match the current filters.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetricCardGrid(
          minTileWidth: 220,
          children: [
            MetricCard(
              label: 'Gross spend',
              value: formatMoney(report.grossSpend),
              icon: Icons.arrow_upward_outlined,
              supportingText: '${report.transactionCount} transactions',
              width: null,
            ),
            MetricCard(
              label: 'Refunds',
              value: formatMoney(report.refundAmount),
              icon: Icons.keyboard_return_outlined,
              tone: MetricCardTone.positive,
              width: null,
            ),
            MetricCard(
              label: 'Net spend',
              value: formatMoney(report.netSpend),
              icon: Icons.account_balance_wallet_outlined,
              tone: report.netSpend < 0
                  ? MetricCardTone.positive
                  : MetricCardTone.neutral,
              width: null,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _ReportSection(
          title: 'Monthly Net Spend',
          icon: Icons.show_chart_outlined,
          child: _MonthlyNetChart(monthlySpend: report.monthlySpend),
        ),
        const SizedBox(height: 20),
        _ReportSection(
          title: 'Gross, Refunds, Net',
          icon: Icons.table_chart_outlined,
          child: _GrossRefundNetTable(monthlySpend: report.monthlySpend),
        ),
        const SizedBox(height: 20),
        _ReportSection(
          title: 'Category Trend',
          icon: Icons.category_outlined,
          child: _CategoryTrendCard(report: report),
        ),
      ],
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppContentCard(
      padding: const EdgeInsets.all(24),
      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: ShapeDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  shape: const OvalBorder(),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _MonthlyNetChart extends StatelessWidget {
  const _MonthlyNetChart({required this.monthlySpend});

  final List<MonthlySpend> monthlySpend;

  @override
  Widget build(BuildContext context) {
    if (monthlySpend.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart_outlined,
        title: 'No monthly trend',
        message: 'No monthly data is available.',
      );
    }

    final theme = Theme.of(context);
    final values = monthlySpend.map((month) => month.netSpend).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final minY = minValue < 0 ? minValue * 1.15 : 0.0;
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.15;
    final labelStep = math.max(1, (monthlySpend.length / 5).ceil());

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final readableWidth = math.max(520.0, monthlySpend.length * 84.0);
        final chartWidth = math.max(viewportWidth, readableWidth);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth,
            height: 280,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (monthlySpend.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: theme.colorScheme.outlineVariant,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                    left: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 58,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _compactMoney(value),
                          style: theme.textTheme.labelSmall,
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if ((value - index).abs() > 0.01 ||
                            index < 0 ||
                            index >= monthlySpend.length) {
                          return const SizedBox.shrink();
                        }

                        if (index % labelStep != 0 &&
                            index != monthlySpend.length - 1) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _shortMonth(monthlySpend[index].periodMonth),
                            style: theme.textTheme.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < monthlySpend.length; i += 1)
                        FlSpot(i.toDouble(), monthlySpend[i].netSpend),
                    ],
                    color: theme.colorScheme.primary,
                    barWidth: 3,
                    isCurved: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GrossRefundNetTable extends StatelessWidget {
  const _GrossRefundNetTable({required this.monthlySpend});

  final List<MonthlySpend> monthlySpend;

  @override
  Widget build(BuildContext context) {
    if (monthlySpend.isEmpty) {
      return const EmptyState(
        icon: Icons.table_chart_outlined,
        title: 'No monthly rows',
        message: 'No monthly data is available.',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Month')),
          DataColumn(label: Text('Gross'), numeric: true),
          DataColumn(label: Text('Refunds'), numeric: true),
          DataColumn(label: Text('Net'), numeric: true),
        ],
        rows: [
          for (final month in monthlySpend.reversed)
            DataRow(
              cells: [
                DataCell(Text(formatMonth(month.periodMonth))),
                DataCell(Text(formatMoney(month.grossSpend))),
                DataCell(Text(formatMoney(month.refundAmount))),
                DataCell(Text(formatMoney(month.netSpend))),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategoryTrendCard extends StatelessWidget {
  const _CategoryTrendCard({required this.report});

  final TrendReport report;

  @override
  Widget build(BuildContext context) {
    if (report.categoryTrends.isEmpty) {
      return const EmptyState(
        icon: Icons.category_outlined,
        title: 'No categories',
        message: 'No category spend matches the current filters.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final compact = layoutWidth < 640;

        if (compact) {
          return Column(
            children: [
              for (final category in report.categoryTrends)
                _CompactCategoryTrendRow(category: category),
            ],
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('Category')),
              const DataColumn(label: Text('Txns'), numeric: true),
              const DataColumn(label: Text('Total'), numeric: true),
              for (final month in report.monthlySpend)
                DataColumn(
                  label: Text(_shortMonth(month.periodMonth)),
                  numeric: true,
                ),
            ],
            rows: [
              for (final category in report.categoryTrends)
                DataRow(
                  cells: [
                    DataCell(_ConstrainedText(category.categoryName)),
                    DataCell(Text(category.transactionCount.toString())),
                    DataCell(Text(formatMoney(category.netSpend))),
                    for (final month in category.months)
                      DataCell(Text(formatMoney(month.netSpend))),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactCategoryTrendRow extends StatelessWidget {
  const _CompactCategoryTrendRow({required this.category});

  final CategoryTrend category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: ShapeDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              shape: const OvalBorder(),
            ),
            child: Icon(
              Icons.category_outlined,
              color: theme.colorScheme.onSurfaceVariant,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${category.transactionCount} transactions',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatMoney(category.netSpend),
            textAlign: TextAlign.end,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConstrainedText extends StatelessWidget {
  const _ConstrainedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Text(text, overflow: TextOverflow.ellipsis),
    );
  }
}

String _shortMonth(DateTime month) {
  return formatMonth(month).split(' ').first;
}

String _compactMoney(double value) {
  final absolute = value.abs();
  final sign = value < 0 ? '-' : '';

  if (absolute >= 100000) {
    return '$sign${(absolute / 100000).toStringAsFixed(1)}L';
  }

  if (absolute >= 1000) {
    return '$sign${(absolute / 1000).toStringAsFixed(0)}K';
  }

  return '$sign${absolute.round()}';
}
