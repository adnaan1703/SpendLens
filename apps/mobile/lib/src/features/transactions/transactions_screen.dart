import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/household_repository.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/period_filter_dropdown.dart';
import '../transaction_metadata/transaction_metadata_editor.dart';

final class TransactionInitialFilters {
  const TransactionInitialFilters({
    this.categoryId,
    this.merchantSearchText,
    this.startDate,
    this.endDate,
  });

  factory TransactionInitialFilters.fromUri(Uri uri) {
    return TransactionInitialFilters(
      categoryId: _nonEmptyQueryParam(uri.queryParameters['categoryId']),
      merchantSearchText: _nonEmptyQueryParam(uri.queryParameters['merchant']),
      startDate: _dateQueryParam(uri.queryParameters['startDate']),
      endDate: _dateQueryParam(uri.queryParameters['endDate']),
    );
  }

  final String? categoryId;
  final String? merchantSearchText;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  bool operator ==(Object other) {
    return other is TransactionInitialFilters &&
        other.categoryId == categoryId &&
        other.merchantSearchText == merchantSearchText &&
        _dateKey(other.startDate) == _dateKey(startDate) &&
        _dateKey(other.endDate) == _dateKey(endDate);
  }

  @override
  int get hashCode => Object.hash(
    categoryId,
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

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({
    super.key,
    this.initialFilters = const TransactionInitialFilters(),
  });

  static const routePath = '/transactions';

  final TransactionInitialFilters initialFilters;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _searchController = TextEditingController();
  String _searchText = '';
  String? _categoryId;
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
  void didUpdateWidget(covariant TransactionsScreen oldWidget) {
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
    final availableMonths = householdId == null
        ? const AsyncValue<List<DateTime>>.loading()
        : ref.watch(availableMonthsProvider(householdId));
    final query = householdId == null
        ? null
        : TransactionQuery(
            householdId: householdId,
            searchText: _searchText,
            categoryId: _categoryId,
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
      _sourceAccountType = null;
      _sourceAccountId = null;
      _dateRange = null;
      _page = 0;
    });

    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(TransactionsScreen.routePath);
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
}

class _TransactionFilters extends StatelessWidget {
  const _TransactionFilters({
    required this.searchController,
    required this.searchText,
    required this.categories,
    required this.selectedCategoryId,
    required this.sourceAccounts,
    required this.selectedSourceAccountType,
    required this.selectedSourceAccountId,
    required this.availableMonths,
    required this.dateRange,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onSourceAccountTypeChanged,
    required this.onSourceAccountChanged,
    required this.onPeriodChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final String searchText;
  final List<CategoryOption> categories;
  final String? selectedCategoryId;
  final List<SourceAccountOption> sourceAccounts;
  final String? selectedSourceAccountType;
  final String? selectedSourceAccountId;
  final List<DateTime> availableMonths;
  final DateTimeRange? dateRange;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onSourceAccountTypeChanged;
  final ValueChanged<String?> onSourceAccountChanged;
  final ValueChanged<PeriodFilterSelection> onPeriodChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasFilters =
        searchText.isNotEmpty ||
        selectedCategoryId != null ||
        selectedSourceAccountType != null ||
        selectedSourceAccountId != null ||
        dateRange != null;
    final hasSelectedCategory =
        selectedCategoryId == null ||
        categories.any((category) => category.id == selectedCategoryId);
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
  });

  final PagedTransactions page;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<FinanceTransaction>? onEdit;

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
            child: _TransactionCard(transaction: transaction, onEdit: onEdit),
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
  const _TransactionCard({required this.transaction, required this.onEdit});

  final FinanceTransaction transaction;
  final ValueChanged<FinanceTransaction>? onEdit;

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
        subtitle: Text(_subtitleFor(transaction)),
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
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: onEdit == null
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            onEdit!(transaction);
                          },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
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
