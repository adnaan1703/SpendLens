import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/household_repository.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/period_filter_dropdown.dart';
import '../activity/activity_route.dart';
import '../transaction_metadata/transaction_metadata_editor.dart';

final class TransactionInitialFilters {
  const TransactionInitialFilters({
    this.categoryId,
    this.labelId,
    this.merchantSearchText,
    this.startDate,
    this.endDate,
  });

  factory TransactionInitialFilters.fromUri(Uri uri) {
    return TransactionInitialFilters(
      categoryId: _nonEmptyQueryParam(uri.queryParameters['categoryId']),
      labelId: _nonEmptyQueryParam(uri.queryParameters['labelId']),
      merchantSearchText: _nonEmptyQueryParam(uri.queryParameters['merchant']),
      startDate: _dateQueryParam(uri.queryParameters['startDate']),
      endDate: _dateQueryParam(uri.queryParameters['endDate']),
    );
  }

  final String? categoryId;
  final String? labelId;
  final String? merchantSearchText;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  bool operator ==(Object other) {
    return other is TransactionInitialFilters &&
        other.categoryId == categoryId &&
        other.labelId == labelId &&
        other.merchantSearchText == merchantSearchText &&
        _dateKey(other.startDate) == _dateKey(startDate) &&
        _dateKey(other.endDate) == _dateKey(endDate);
  }

  @override
  int get hashCode => Object.hash(
    categoryId,
    labelId,
    merchantSearchText,
    _dateKey(startDate),
    _dateKey(endDate),
  );
}

String? _nonEmptyQueryParam(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;

  return trimmed;
}

DateTime? _dateQueryParam(String? value) {
  final parsed = DateTime.tryParse(value ?? '');
  if (parsed == null) return null;

  return DateTime(parsed.year, parsed.month, parsed.day);
}

String? _dateKey(DateTime? date) {
  return date == null ? null : dateString(date);
}

class TransactionListPane extends ConsumerStatefulWidget {
  const TransactionListPane({
    super.key,
    this.initialFilters = const TransactionInitialFilters(),
    this.clearFiltersPath = activityRoutePath,
  });

  final TransactionInitialFilters initialFilters;
  final String clearFiltersPath;

  @override
  ConsumerState<TransactionListPane> createState() =>
      _TransactionListPaneState();
}

class _TransactionListPaneState extends ConsumerState<TransactionListPane> {
  final _searchController = TextEditingController();
  String _searchText = '';
  String? _categoryId;
  String? _labelId;
  String? _sourceAccountType;
  String? _sourceAccountId;
  DateTimeRange? _dateRange;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _applyInitialFilters(widget.initialFilters);
  }

  @override
  void didUpdateWidget(covariant TransactionListPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilters == widget.initialFilters) return;

    setState(() {
      _applyInitialFilters(widget.initialFilters);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final householdContext = ref.watch(householdContextProvider).value;
    final householdId = householdContext?.household.id;
    final categories = householdId == null
        ? const AsyncValue<List<CategoryOption>>.loading()
        : ref.watch(transactionCategoriesProvider(householdId));
    final subcategories = householdId == null
        ? const AsyncValue<List<SubcategoryOption>>.loading()
        : ref.watch(merchantSubcategoriesProvider(householdId));
    final sourceAccounts = householdId == null
        ? const AsyncValue<List<SourceAccountOption>>.loading()
        : ref.watch(transactionSourceAccountsProvider(householdId));
    final labels = householdId == null
        ? const AsyncValue<List<LabelOption>>.loading()
        : ref.watch(transactionLabelsProvider(householdId));
    final labelOptions = labels.value ?? const [];
    if (_labelId != null &&
        labels.hasValue &&
        !labelOptions.any((label) => label.id == _labelId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _labelId == null) return;

        setState(() {
          _labelId = null;
          _page = 0;
        });
      });
    }
    final availableMonths = householdId == null
        ? const AsyncValue<List<DateTime>>.loading()
        : ref.watch(availableMonthsProvider(householdId));
    final query = householdId == null
        ? null
        : TransactionQuery(
            householdId: householdId,
            searchText: _searchText,
            categoryId: _categoryId,
            labelId: _labelId,
            sourceAccountType: _sourceAccountType,
            sourceAccountId: _sourceAccountId,
            startDate: _dateRange?.start,
            endDate: _dateRange?.end,
            page: _page,
          );
    final transactions = query == null
        ? const AsyncValue<PagedTransactions>.loading()
        : ref.watch(transactionsProvider(query));

    return AppPage(
      title: 'Transactions',
      subtitle: householdContext?.household.name ?? 'Search and filters',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TransactionFilters(
            searchController: _searchController,
            searchText: _searchText,
            categories: categories.value ?? const [],
            selectedCategoryId: _categoryId,
            labels: labelOptions,
            selectedLabelId: _labelId,
            sourceAccounts: sourceAccounts.value ?? const [],
            selectedSourceAccountType: _sourceAccountType,
            selectedSourceAccountId: _sourceAccountId,
            availableMonths: availableMonths.value ?? const [],
            dateRange: _dateRange,
            onSearchChanged: (value) {
              setState(() {
                _searchText = value;
                _page = 0;
              });
            },
            onCategoryChanged: (value) {
              setState(() {
                _categoryId = value;
                _page = 0;
              });
            },
            onLabelChanged: (value) {
              setState(() {
                _labelId = value;
                _page = 0;
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
                _page = 0;
              });
            },
            onSourceAccountChanged: (value) {
              setState(() {
                _sourceAccountId = value;
                _page = 0;
              });
            },
            onPeriodChanged: _handlePeriodChanged,
            onClear: _clearFilters,
          ),
          const SizedBox(height: 20),
          switch (transactions) {
            AsyncValue(:final value?) => _TransactionList(
              page: value,
              onPreviousPage: value.hasPreviousPage
                  ? () {
                      setState(() {
                        _page -= 1;
                      });
                    }
                  : null,
              onNextPage: value.hasNextPage
                  ? () {
                      setState(() {
                        _page += 1;
                      });
                    }
                  : null,
              onEdit:
                  householdContext == null ||
                      !categories.hasValue ||
                      !subcategories.hasValue
                  ? null
                  : (transaction) {
                      _showMetadataEditor(
                        householdContext: householdContext,
                        transaction: transaction,
                        categories: categories.value ?? const [],
                        subcategories: subcategories.value ?? const [],
                      );
                    },
              onEditLabels: householdContext == null || !labels.hasValue
                  ? null
                  : (transaction) {
                      _showLabelEditor(
                        householdContext: householdContext,
                        transaction: transaction,
                        labels: labels.value ?? const [],
                      );
                    },
            ),
            AsyncValue(hasError: true, :final error) => EmptyState(
              icon: Icons.error_outline,
              title: 'Transactions unavailable',
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
      _page = 0;
    });
  }

  void _handlePeriodChanged(PeriodFilterSelection selection) {
    switch (selection.type) {
      case PeriodFilterSelectionType.allDates:
        setState(() {
          _dateRange = null;
          _page = 0;
        });
      case PeriodFilterSelectionType.month:
        setState(() {
          _dateRange = selection.dateRange;
          _page = 0;
        });
      case PeriodFilterSelectionType.customDateRange:
        _pickDateRange();
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchText = '';
      _categoryId = null;
      _labelId = null;
      _sourceAccountType = null;
      _sourceAccountId = null;
      _dateRange = null;
      _page = 0;
    });

    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(widget.clearFiltersPath);
    }
  }

  void _applyInitialFilters(TransactionInitialFilters filters) {
    final merchantSearchText = filters.merchantSearchText ?? '';
    _searchController.value = TextEditingValue(
      text: merchantSearchText,
      selection: TextSelection.collapsed(offset: merchantSearchText.length),
    );
    final startDate = filters.startDate;
    final endDate = filters.endDate;
    _searchText = merchantSearchText;
    _categoryId = filters.categoryId;
    _labelId = filters.labelId;
    _dateRange =
        startDate == null || endDate == null || startDate.isAfter(endDate)
        ? null
        : DateTimeRange(start: startDate, end: endDate);
    _page = 0;
  }

  Future<void> _showMetadataEditor({
    required HouseholdContext householdContext,
    required FinanceTransaction transaction,
    required List<CategoryOption> categories,
    required List<SubcategoryOption> subcategories,
  }) async {
    final result = await showTransactionMetadataEditor(
      context: context,
      ref: ref,
      initialValue: TransactionMetadataEditorInitialValue(
        householdId: householdContext.household.id,
        transactionId: transaction.id,
        statementMerchant: transaction.statementMerchant,
        merchantGroup:
            transaction.merchantName ?? transaction.statementMerchant,
        categoryId: transaction.categoryId,
        subcategoryId: transaction.subcategoryId,
        confidence: transaction.confidence,
        notes: transaction.notes,
      ),
      categories: categories,
      subcategories: subcategories,
    );

    if (result == null) return;

    ref.invalidate(transactionsProvider);
    ref.invalidate(trendReportProvider);
    ref.invalidate(merchantReviewQueueProvider(householdContext.household.id));
    ref.invalidate(dashboardSnapshotProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Updated ${result.updatedTransactionCount} transactions',
          ),
        ),
      );
    }
  }

  Future<void> _showLabelEditor({
    required HouseholdContext householdContext,
    required FinanceTransaction transaction,
    required List<LabelOption> labels,
  }) async {
    final result = await showTransactionLabelEditor(
      context: context,
      ref: ref,
      householdId: householdContext.household.id,
      transaction: transaction,
      labels: labels,
    );

    if (result == null) return;

    ref.invalidate(transactionsProvider);
    ref.invalidate(transactionLabelsProvider(householdContext.household.id));
    ref.invalidate(labelManagerSnapshotProvider(householdContext.household.id));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${result.labels.length} labels')),
      );
    }
  }
}

class _TransactionFilters extends StatelessWidget {
  const _TransactionFilters({
    required this.searchController,
    required this.searchText,
    required this.categories,
    required this.selectedCategoryId,
    required this.labels,
    required this.selectedLabelId,
    required this.sourceAccounts,
    required this.selectedSourceAccountType,
    required this.selectedSourceAccountId,
    required this.availableMonths,
    required this.dateRange,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onLabelChanged,
    required this.onSourceAccountTypeChanged,
    required this.onSourceAccountChanged,
    required this.onPeriodChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final String searchText;
  final List<CategoryOption> categories;
  final String? selectedCategoryId;
  final List<LabelOption> labels;
  final String? selectedLabelId;
  final List<SourceAccountOption> sourceAccounts;
  final String? selectedSourceAccountType;
  final String? selectedSourceAccountId;
  final List<DateTime> availableMonths;
  final DateTimeRange? dateRange;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onLabelChanged;
  final ValueChanged<String?> onSourceAccountTypeChanged;
  final ValueChanged<String?> onSourceAccountChanged;
  final ValueChanged<PeriodFilterSelection> onPeriodChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasFilters =
        searchText.isNotEmpty ||
        selectedCategoryId != null ||
        selectedLabelId != null ||
        selectedSourceAccountType != null ||
        selectedSourceAccountId != null ||
        dateRange != null;
    final hasSelectedCategory =
        selectedCategoryId == null ||
        categories.any((category) => category.id == selectedCategoryId);
    final hasSelectedLabel =
        selectedLabelId == null ||
        labels.any((label) => label.id == selectedLabelId);
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
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Merchant search',
            ),
          ),
        ),
        SizedBox(
          width: 300,
          child: DropdownButtonFormField<String>(
            key: ValueKey('category-$selectedCategoryId'),
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
          width: 220,
          child: DropdownButtonFormField<String>(
            key: ValueKey('source-type-$selectedSourceAccountType'),
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
            key: ValueKey('source-$selectedSourceAccountId'),
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
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<String>(
            key: ValueKey('label-$selectedLabelId'),
            isExpanded: true,
            initialValue: selectedLabelId,
            decoration: const InputDecoration(
              labelText: 'Label',
              prefixIcon: Icon(Icons.label_outline),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All labels')),
              if (!hasSelectedLabel)
                DropdownMenuItem(
                  value: selectedLabelId,
                  child: const Text('Selected label'),
                ),
              for (final label in labels)
                DropdownMenuItem(value: label.id, child: Text(label.name)),
            ],
            onChanged: onLabelChanged,
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
      ],
    );
  }
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({
    required this.page,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onEdit,
    required this.onEditLabels,
  });

  final PagedTransactions page;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<FinanceTransaction>? onEdit;
  final ValueChanged<FinanceTransaction>? onEditLabels;

  @override
  Widget build(BuildContext context) {
    if (page.items.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions',
        message: 'No transactions match the current filters.',
      );
    }

    return Column(
      children: [
        for (final transaction in page.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TransactionCard(
              transaction: transaction,
              onEdit: onEdit,
              onEditLabels: onEditLabels,
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Page ${page.page + 1}'),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Previous page',
              onPressed: onPreviousPage,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Next page',
              onPressed: onNextPage,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
    required this.onEdit,
    required this.onEditLabels,
  });

  final FinanceTransaction transaction;
  final ValueChanged<FinanceTransaction>? onEdit;
  final ValueChanged<FinanceTransaction>? onEditLabels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountColor = transaction.netExpense < 0
        ? theme.colorScheme.tertiary
        : transaction.isBillPayment
        ? theme.colorScheme.outline
        : theme.colorScheme.primary;

    return Card(
      child: ListTile(
        leading: Icon(_iconFor(transaction), color: amountColor),
        title: Text(
          _titleFor(transaction),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: _TransactionSubtitle(
          text: _subtitleFor(transaction),
          labels: transaction.labels,
        ),
        trailing: Text(
          formatMoney(transaction.netExpense),
          style: theme.textTheme.titleMedium?.copyWith(color: amountColor),
        ),
        onTap: () => _showTransactionDetail(context, transaction),
      ),
    );
  }

  IconData _iconFor(FinanceTransaction transaction) {
    if (transaction.isRefund) return Icons.keyboard_return_outlined;
    if (transaction.isBillPayment) return Icons.account_balance_wallet_outlined;

    return Icons.receipt_long_outlined;
  }

  String _titleFor(FinanceTransaction transaction) {
    final merchantName = transaction.merchantName?.trim();
    if (merchantName != null && merchantName.isNotEmpty) {
      return merchantName;
    }

    return transaction.statementMerchant;
  }

  String _subtitleFor(FinanceTransaction transaction) {
    final title = _titleFor(transaction);
    final statementMerchant = transaction.statementMerchant.trim();
    final pieces = [
      dateString(transaction.transactionDate),
      if (statementMerchant.isNotEmpty && statementMerchant != title)
        statementMerchant,
      if (transaction.categoryName != null) transaction.categoryName!,
      transaction.transactionType.replaceAll('_', ' '),
      if (transaction.cardholderName != null) transaction.cardholderName!,
    ];

    return pieces.join(' - ');
  }

  void _showTransactionDetail(
    BuildContext context,
    FinanceTransaction transaction,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _titleFor(transaction),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(dateString(transaction.transactionDate)),
                const SizedBox(height: 20),
                if (transaction.statementMerchant.trim() !=
                    _titleFor(transaction))
                  _DetailRow(
                    label: 'Statement',
                    value: transaction.statementMerchant,
                  ),
                _DetailRow(
                  label: 'Gross spend',
                  value: formatMoney(transaction.grossSpend),
                ),
                _DetailRow(
                  label: 'Refunds',
                  value: formatMoney(transaction.refundAmount),
                ),
                _DetailRow(
                  label: 'Net expense',
                  value: formatMoney(transaction.netExpense),
                ),
                _DetailRow(
                  label: 'Source amount',
                  value: formatMoney(transaction.amount),
                ),
                _DetailRow(
                  label: 'Category',
                  value: transaction.categoryName ?? 'Uncategorized',
                ),
                _DetailRow(
                  label: 'Subcategory',
                  value: transaction.subcategoryName ?? 'Uncategorized',
                ),
                _DetailRow(
                  label: 'Type',
                  value: transaction.transactionType.replaceAll('_', ' '),
                ),
                _DetailRow(label: 'Confidence', value: transaction.confidence),
                if (transaction.cardholderName != null)
                  _DetailRow(
                    label: 'Cardholder',
                    value: transaction.cardholderName!,
                  ),
                if (transaction.notes != null &&
                    transaction.notes!.trim().isNotEmpty)
                  _DetailRow(label: 'Notes', value: transaction.notes!),
                _DetailLabelRow(labels: transaction.labels),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onEditLabels == null
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              onEditLabels!(transaction);
                            },
                      icon: const Icon(Icons.label_outline),
                      label: const Text('Edit labels'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: onEdit == null
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              onEdit!(transaction);
                            },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: theme.textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _TransactionSubtitle extends StatelessWidget {
  const _TransactionSubtitle({required this.text, required this.labels});

  final String text;
  final List<LabelOption> labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (labels.isNotEmpty) ...[
          const SizedBox(height: 6),
          _LabelChips(labels: labels, maxVisible: 2, compact: true),
        ],
      ],
    );
  }
}

class _DetailLabelRow extends StatelessWidget {
  const _DetailLabelRow({required this.labels});

  final List<LabelOption> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('Labels', style: theme.textTheme.labelLarge),
          ),
          Expanded(
            child: labels.isEmpty
                ? const Text('None')
                : _LabelChips(labels: labels),
          ),
        ],
      ),
    );
  }
}

class _LabelChips extends StatelessWidget {
  const _LabelChips({
    required this.labels,
    this.maxVisible,
    this.compact = false,
  });

  final List<LabelOption> labels;
  final int? maxVisible;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visibleCount = maxVisible == null
        ? labels.length
        : labels.length.clamp(0, maxVisible!);
    final visibleLabels = labels.take(visibleCount);
    final overflowCount = labels.length - visibleCount;

    return Wrap(
      spacing: compact ? 4 : 6,
      runSpacing: compact ? 4 : 6,
      children: [
        for (final label in visibleLabels)
          Chip(
            visualDensity: compact ? VisualDensity.compact : null,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelPadding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
            label: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 120 : 220),
              child: Text(
                label.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        if (overflowCount > 0)
          Chip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            label: Text('+$overflowCount'),
          ),
      ],
    );
  }
}

Future<TransactionLabelsSetResult?> showTransactionLabelEditor({
  required BuildContext context,
  required WidgetRef ref,
  required String householdId,
  required FinanceTransaction transaction,
  required List<LabelOption> labels,
}) {
  final newLabelController = TextEditingController();
  final initialLabelIds = transaction.labels.map((label) => label.id).toSet();
  final selectedLabelIds = {...initialLabelIds};
  var availableLabels = _mergeLabels(labels, transaction.labels);
  var newLabelNames = <String>[];
  var isSaving = false;
  String? errorMessage;

  return showModalBottomSheet<TransactionLabelsSetResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
          final hasChanges =
              !_sameStringSet(initialLabelIds, selectedLabelIds) ||
              newLabelNames.isNotEmpty;

          void addNewLabel() {
            final name = newLabelController.text.trim();
            if (name.isEmpty) return;

            final existing = availableLabels
                .where(
                  (label) => label.name.toLowerCase() == name.toLowerCase(),
                )
                .firstOrNull;
            setSheetState(() {
              if (existing != null) {
                selectedLabelIds.add(existing.id);
              } else if (!newLabelNames.any(
                (candidate) => candidate.toLowerCase() == name.toLowerCase(),
              )) {
                newLabelNames = [...newLabelNames, name]
                  ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              }
              errorMessage = null;
              newLabelController.clear();
            });
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, keyboardBottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Edit labels',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(transaction.statementMerchant),
                    const SizedBox(height: 12),
                    Text(
                      'Labels apply only to this transaction. They do not change merchant rules, categories, or matching transactions.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    if (availableLabels.isEmpty)
                      const Text('No existing labels yet.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final label in availableLabels)
                            FilterChip(
                              label: Text(label.name),
                              selected: selectedLabelIds.contains(label.id),
                              onSelected: isSaving
                                  ? null
                                  : (selected) {
                                      setSheetState(() {
                                        if (selected) {
                                          selectedLabelIds.add(label.id);
                                        } else {
                                          selectedLabelIds.remove(label.id);
                                        }
                                        errorMessage = null;
                                      });
                                    },
                            ),
                        ],
                      ),
                    if (newLabelNames.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final name in newLabelNames)
                            InputChip(
                              label: Text(name),
                              onDeleted: isSaving
                                  ? null
                                  : () {
                                      setSheetState(() {
                                        newLabelNames = [
                                          for (final candidate in newLabelNames)
                                            if (candidate != name) candidate,
                                        ];
                                        errorMessage = null;
                                      });
                                    },
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: newLabelController,
                      enabled: !isSaving,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'New label',
                        prefixIcon: const Icon(Icons.add),
                        suffixIcon: IconButton(
                          tooltip: 'Add label',
                          onPressed: isSaving ? null : addNewLabel,
                          icon: const Icon(Icons.check),
                        ),
                      ),
                      onSubmitted: (_) => isSaving ? null : addNewLabel(),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.of(sheetContext).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: isSaving || !hasChanges
                              ? null
                              : () async {
                                  setSheetState(() {
                                    isSaving = true;
                                    errorMessage = null;
                                  });

                                  try {
                                    final result = await ref
                                        .read(financeRepositoryProvider)
                                        .setTransactionLabels(
                                          TransactionLabelsSetRequest(
                                            householdId: householdId,
                                            transactionId: transaction.id,
                                            labelIds: selectedLabelIds.toList()
                                              ..sort(),
                                            newLabelNames: newLabelNames,
                                          ),
                                        );

                                    availableLabels = _mergeLabels(
                                      availableLabels,
                                      result.labels,
                                    );
                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop(result);
                                    }
                                  } catch (error) {
                                    setSheetState(() {
                                      isSaving = false;
                                      errorMessage = error.toString();
                                    });
                                    if (sheetContext.mounted) {
                                      ScaffoldMessenger.of(
                                        sheetContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(error.toString()),
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

List<LabelOption> _mergeLabels(
  List<LabelOption> primary,
  List<LabelOption> secondary,
) {
  final labelsById = <String, LabelOption>{};
  for (final label in [...primary, ...secondary]) {
    labelsById[label.id] = label;
  }

  return labelsById.values.toList(growable: false)..sort(_compareLabelsByName);
}

int _compareLabelsByName(LabelOption a, LabelOption b) {
  final lowerComparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  if (lowerComparison != 0) return lowerComparison;

  return a.id.compareTo(b.id);
}

bool _sameStringSet(Set<String> a, Set<String> b) {
  return a.length == b.length && a.every(b.contains);
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;

    return null;
  }
}
