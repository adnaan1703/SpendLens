import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/household_repository.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/metric_card.dart';
import '../../shared/widgets/period_filter_dropdown.dart';

class TrendsReportPane extends ConsumerStatefulWidget {
  const TrendsReportPane({super.key});

  @override
  ConsumerState<TrendsReportPane> createState() => _TrendsReportPaneState();
}

class _TrendsReportPaneState extends ConsumerState<TrendsReportPane> {
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

    return AppPage(
      title: 'Trends',
      subtitle: householdContext?.household.name ?? 'Monthly reports',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              title: 'Trends unavailable',
              message: error.toString(),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ],
      ),
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
    final hasFilters =
        selectedCategoryId != null ||
        selectedSourceAccountType != null ||
        selectedSourceAccountId != null ||
        dateRange != null;
    final loadedReport = report;
    final filteredSourceAccounts = selectedSourceAccountType == null
        ? sourceAccounts
        : sourceAccounts
              .where((source) => source.type == selectedSourceAccountType)
              .toList(growable: false);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 300,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: selectedCategoryId,
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('All categories'),
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
          width: 220,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: selectedSourceAccountType,
            decoration: const InputDecoration(
              labelText: 'Source type',
              prefixIcon: Icon(Icons.account_balance_outlined),
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
          width: 340,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: selectedSourceAccountId,
            decoration: const InputDecoration(
              labelText: 'Source',
              prefixIcon: Icon(Icons.credit_card_outlined),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All sources')),
              for (final source in filteredSourceAccounts)
                DropdownMenuItem(value: source.id, child: Text(source.label)),
            ],
            onChanged: onSourceAccountChanged,
          ),
        ),
        PeriodFilterDropdown(
          availableMonths: availableMonths,
          selectedRange: dateRange,
          onChanged: onPeriodChanged,
        ),
        IconButton(
          tooltip: 'Clear filters',
          onPressed: hasFilters ? onClear : null,
          icon: const Icon(Icons.filter_alt_off_outlined),
        ),
        FilledButton.icon(
          onPressed: loadedReport == null || loadedReport.isEmpty
              ? null
              : () => onCopyCsv(loadedReport),
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Copy CSV'),
        ),
      ],
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
        title: 'No trend data',
        message: 'No transactions match the current filters.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            MetricCard(
              label: 'Transactions',
              value: report.transactionCount.toString(),
              icon: Icons.receipt_long_outlined,
            ),
            MetricCard(
              label: 'Gross spend',
              value: formatMoney(report.grossSpend),
              icon: Icons.arrow_upward_outlined,
            ),
            MetricCard(
              label: 'Refunds',
              value: formatMoney(report.refundAmount),
              icon: Icons.keyboard_return_outlined,
            ),
            MetricCard(
              label: 'Net spend',
              value: formatMoney(report.netSpend),
              icon: Icons.account_balance_wallet_outlined,
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
          child: _CategoryTrendTable(report: report),
        ),
        const SizedBox(height: 20),
        _ReportSection(
          title: 'Merchant Summary',
          icon: Icons.storefront_outlined,
          child: _MerchantSummaryTable(report: report),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
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
    final width = math.max(640.0, monthlySpend.length * 84.0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
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
  }
}

class _GrossRefundNetTable extends StatelessWidget {
  const _GrossRefundNetTable({required this.monthlySpend});

  final List<MonthlySpend> monthlySpend;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Month')),
          DataColumn(label: Text('Txns'), numeric: true),
          DataColumn(label: Text('Gross'), numeric: true),
          DataColumn(label: Text('Refunds'), numeric: true),
          DataColumn(label: Text('Net'), numeric: true),
          DataColumn(label: Text('Bill payments'), numeric: true),
        ],
        rows: [
          for (final month in monthlySpend.reversed)
            DataRow(
              cells: [
                DataCell(Text(formatMonth(month.periodMonth))),
                DataCell(Text(month.transactionCount.toString())),
                DataCell(Text(formatMoney(month.grossSpend))),
                DataCell(Text(formatMoney(month.refundAmount))),
                DataCell(Text(formatMoney(month.netSpend))),
                DataCell(Text(formatMoney(month.billPayments))),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategoryTrendTable extends StatelessWidget {
  const _CategoryTrendTable({required this.report});

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
  }
}

class _MerchantSummaryTable extends StatelessWidget {
  const _MerchantSummaryTable({required this.report});

  final TrendReport report;

  @override
  Widget build(BuildContext context) {
    if (report.merchantSummaries.isEmpty) {
      return const EmptyState(
        icon: Icons.storefront_outlined,
        title: 'No merchants',
        message: 'No merchant spend matches the current filters.',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Merchant group')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Subcategory')),
          DataColumn(label: Text('Txns'), numeric: true),
          DataColumn(label: Text('Gross'), numeric: true),
          DataColumn(label: Text('Refunds'), numeric: true),
          DataColumn(label: Text('Net'), numeric: true),
        ],
        rows: [
          for (final merchant in report.merchantSummaries)
            DataRow(
              cells: [
                DataCell(_ConstrainedText(merchant.merchantGroup, width: 240)),
                DataCell(_ConstrainedText(merchant.categoryName ?? '-')),
                DataCell(_ConstrainedText(merchant.subcategoryName ?? '-')),
                DataCell(Text(merchant.transactionCount.toString())),
                DataCell(Text(formatMoney(merchant.grossSpend))),
                DataCell(Text(formatMoney(merchant.refundAmount))),
                DataCell(Text(formatMoney(merchant.netSpend))),
              ],
            ),
        ],
      ),
    );
  }
}

class _ConstrainedText extends StatelessWidget {
  const _ConstrainedText(this.text, {this.width = 180});

  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
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
