import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/auth_repository.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  if (authRepository is SupabaseAuthRepository) {
    return SupabaseFinanceRepository(Supabase.instance.client);
  }

  return const DisabledFinanceRepository();
});

final dashboardSnapshotProvider =
    FutureProvider.family<DashboardSnapshot, FinanceMonthRequest>((
      ref,
      request,
    ) {
      return ref
          .watch(financeRepositoryProvider)
          .fetchDashboardSnapshot(
            householdId: request.householdId,
            requestedMonth: request.month,
          );
    });

final transactionCategoriesProvider =
    FutureProvider.family<List<CategoryOption>, String>((ref, householdId) {
      return ref
          .watch(financeRepositoryProvider)
          .fetchCategories(householdId: householdId);
    });

final transactionSourceAccountsProvider =
    FutureProvider.family<List<SourceAccountOption>, String>((
      ref,
      householdId,
    ) {
      return ref
          .watch(financeRepositoryProvider)
          .fetchSourceAccounts(householdId: householdId);
    });

final transactionsProvider =
    FutureProvider.family<PagedTransactions, TransactionQuery>((ref, query) {
      return ref.watch(financeRepositoryProvider).fetchTransactions(query);
    });

final class FinanceMonthRequest {
  const FinanceMonthRequest({required this.householdId, this.month});

  final String householdId;
  final DateTime? month;

  @override
  bool operator ==(Object other) {
    return other is FinanceMonthRequest &&
        other.householdId == householdId &&
        _monthKey(other.month) == _monthKey(month);
  }

  @override
  int get hashCode => Object.hash(householdId, _monthKey(month));
}

final class TransactionQuery {
  const TransactionQuery({
    required this.householdId,
    this.searchText = '',
    this.categoryId,
    this.sourceAccountId,
    this.startDate,
    this.endDate,
    this.page = 0,
    this.pageSize = 25,
  });

  final String householdId;
  final String searchText;
  final String? categoryId;
  final String? sourceAccountId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int page;
  final int pageSize;

  TransactionQuery copyWith({
    String? searchText,
    String? categoryId,
    bool clearCategory = false,
    String? sourceAccountId,
    bool clearSourceAccount = false,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    int? page,
  }) {
    return TransactionQuery(
      householdId: householdId,
      searchText: searchText ?? this.searchText,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
      sourceAccountId: clearSourceAccount
          ? null
          : sourceAccountId ?? this.sourceAccountId,
      startDate: clearStartDate ? null : startDate ?? this.startDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      page: page ?? this.page,
      pageSize: pageSize,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TransactionQuery &&
        other.householdId == householdId &&
        other.searchText == searchText &&
        other.categoryId == categoryId &&
        other.sourceAccountId == sourceAccountId &&
        _dateKey(other.startDate) == _dateKey(startDate) &&
        _dateKey(other.endDate) == _dateKey(endDate) &&
        other.page == page &&
        other.pageSize == pageSize;
  }

  @override
  int get hashCode => Object.hash(
    householdId,
    searchText,
    categoryId,
    sourceAccountId,
    _dateKey(startDate),
    _dateKey(endDate),
    page,
    pageSize,
  );
}

final class DashboardSnapshot {
  const DashboardSnapshot({
    required this.availableMonths,
    required this.selectedMonth,
    required this.monthlySpend,
    required this.previousMonthSpend,
    required this.reviewQueueCount,
    required this.budgetProgress,
    required this.uncappedCategories,
    required this.topCategories,
    required this.topMerchants,
  });

  final List<DateTime> availableMonths;
  final DateTime selectedMonth;
  final MonthlySpend monthlySpend;
  final MonthlySpend? previousMonthSpend;
  final int reviewQueueCount;
  final List<BudgetProgress> budgetProgress;
  final List<CategoryOption> uncappedCategories;
  final List<CategorySpend> topCategories;
  final List<MerchantSpend> topMerchants;

  int get cappedCategoryCount => budgetProgress.length;

  double get monthOverMonthChange {
    return monthlySpend.netSpend - (previousMonthSpend?.netSpend ?? 0);
  }

  double? get monthOverMonthPercent {
    final previous = previousMonthSpend?.netSpend ?? 0;
    if (previous == 0) return null;

    return monthOverMonthChange / previous;
  }
}

final class MonthlySpend {
  const MonthlySpend({
    required this.periodMonth,
    required this.transactionCount,
    required this.grossSpend,
    required this.refundAmount,
    required this.netSpend,
    required this.billPayments,
  });

  final DateTime periodMonth;
  final int transactionCount;
  final double grossSpend;
  final double refundAmount;
  final double netSpend;
  final double billPayments;

  static MonthlySpend empty(DateTime month) {
    return MonthlySpend(
      periodMonth: firstDayOfMonth(month),
      transactionCount: 0,
      grossSpend: 0,
      refundAmount: 0,
      netSpend: 0,
      billPayments: 0,
    );
  }

  factory MonthlySpend.fromJson(Map<String, dynamic> json) {
    return MonthlySpend(
      periodMonth: _parseDate(json['period_month'] as String),
      transactionCount: _asInt(json['transaction_count']),
      grossSpend: _asDouble(json['gross_spend']),
      refundAmount: _asDouble(json['refund_amount']),
      netSpend: _asDouble(json['net_spend']),
      billPayments: _asDouble(json['bill_payments']),
    );
  }
}

final class CategorySpend {
  const CategorySpend({
    required this.categoryId,
    required this.categoryName,
    required this.transactionCount,
    required this.netSpend,
    required this.refundAmount,
  });

  final String categoryId;
  final String categoryName;
  final int transactionCount;
  final double netSpend;
  final double refundAmount;

  factory CategorySpend.fromJson(Map<String, dynamic> json) {
    return CategorySpend(
      categoryId: json['category_id'] as String,
      categoryName: (json['category_name'] as String?) ?? 'Uncategorized',
      transactionCount: _asInt(json['transaction_count']),
      netSpend: _asDouble(json['net_spend']),
      refundAmount: _asDouble(json['refund_amount']),
    );
  }
}

final class BudgetProgress {
  const BudgetProgress({
    required this.categoryId,
    required this.categoryName,
    required this.capAmount,
    required this.spentAmount,
    required this.remainingAmount,
    required this.percentUsed,
    required this.isOverBudget,
  });

  final String categoryId;
  final String categoryName;
  final double capAmount;
  final double spentAmount;
  final double remainingAmount;
  final double? percentUsed;
  final bool isOverBudget;

  factory BudgetProgress.fromJson(Map<String, dynamic> json) {
    return BudgetProgress(
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String,
      capAmount: _asDouble(json['cap_amount']),
      spentAmount: _asDouble(json['spent_amount']),
      remainingAmount: _asDouble(json['remaining_amount']),
      percentUsed: json['percent_used'] == null
          ? null
          : _asDouble(json['percent_used']),
      isOverBudget: json['is_over_budget'] as bool? ?? false,
    );
  }
}

final class MerchantSpend {
  const MerchantSpend({
    required this.merchantName,
    required this.transactionCount,
    required this.netSpend,
    required this.refundAmount,
  });

  final String merchantName;
  final int transactionCount;
  final double netSpend;
  final double refundAmount;
}

final class CategoryOption {
  const CategoryOption({required this.id, required this.name});

  final String id;
  final String name;

  factory CategoryOption.fromJson(Map<String, dynamic> json) {
    return CategoryOption(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

final class SourceAccountOption {
  const SourceAccountOption({
    required this.id,
    required this.displayName,
    this.cardholderName,
  });

  final String id;
  final String displayName;
  final String? cardholderName;

  String get label {
    final cardholder = cardholderName?.trim();
    if (cardholder == null || cardholder.isEmpty) return displayName;

    return '$displayName - $cardholder';
  }

  factory SourceAccountOption.fromJson(Map<String, dynamic> json) {
    return SourceAccountOption(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      cardholderName: json['cardholder_name'] as String?,
    );
  }
}

final class PagedTransactions {
  const PagedTransactions({
    required this.items,
    required this.page,
    required this.pageSize,
  });

  final List<FinanceTransaction> items;
  final int page;
  final int pageSize;

  bool get hasPreviousPage => page > 0;

  bool get hasNextPage => items.length == pageSize;
}

final class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.transactionDate,
    required this.statementMerchant,
    this.categoryId,
    this.categoryName,
    this.sourceAccountId,
    required this.transactionType,
    required this.amount,
    required this.grossSpend,
    required this.refundAmount,
    required this.netExpense,
    required this.currencyCode,
    required this.confidence,
    this.cardholderName,
    this.notes,
  });

  final String id;
  final DateTime transactionDate;
  final String statementMerchant;
  final String? categoryId;
  final String? categoryName;
  final String? sourceAccountId;
  final String transactionType;
  final double amount;
  final double grossSpend;
  final double refundAmount;
  final double netExpense;
  final String currencyCode;
  final String confidence;
  final String? cardholderName;
  final String? notes;

  bool get isRefund => transactionType == 'refund_reversal';

  bool get isBillPayment => transactionType == 'bill_payment_credit';

  factory FinanceTransaction.fromJson(
    Map<String, dynamic> json, {
    required Map<String, String> categoryNamesById,
  }) {
    final categoryId = json['category_id'] as String?;

    return FinanceTransaction(
      id: json['id'] as String,
      transactionDate: _parseDate(json['transaction_date'] as String),
      statementMerchant: json['statement_merchant'] as String,
      categoryId: categoryId,
      categoryName: categoryId == null
          ? null
          : categoryNamesById[categoryId] ?? 'Uncategorized',
      sourceAccountId: json['source_account_id'] as String?,
      transactionType: json['transaction_type'] as String,
      amount: _asDouble(json['amount']),
      grossSpend: _asDouble(json['gross_spend']),
      refundAmount: _asDouble(json['refund_amount']),
      netExpense: _asDouble(json['net_expense']),
      currencyCode: json['currency_code'] as String? ?? 'INR',
      confidence: json['confidence'] as String? ?? 'medium',
      cardholderName: json['cardholder_name'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

abstract interface class FinanceRepository {
  Future<DashboardSnapshot> fetchDashboardSnapshot({
    required String householdId,
    DateTime? requestedMonth,
  });

  Future<List<CategoryOption>> fetchCategories({required String householdId});

  Future<List<SourceAccountOption>> fetchSourceAccounts({
    required String householdId,
  });

  Future<PagedTransactions> fetchTransactions(TransactionQuery query);

  Future<void> saveCategoryCap({
    required String householdId,
    required String profileId,
    required String categoryId,
    required DateTime periodMonth,
    required double capAmount,
  });
}

final class SupabaseFinanceRepository implements FinanceRepository {
  SupabaseFinanceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<DashboardSnapshot> fetchDashboardSnapshot({
    required String householdId,
    DateTime? requestedMonth,
  }) async {
    final monthlySpend = await _fetchMonthlySpend(householdId: householdId);
    final availableMonths = monthlySpend.map((row) => row.periodMonth).toList();
    final selectedMonth = _selectReportingMonth(
      monthlySpend: monthlySpend,
      requestedMonth: requestedMonth,
    );

    final selectedSpend = monthlySpend.firstWhere(
      (row) => isSameMonth(row.periodMonth, selectedMonth),
      orElse: () => MonthlySpend.empty(selectedMonth),
    );
    final previousMonth = addMonths(selectedMonth, -1);
    final previousSpend = monthlySpend
        .where((row) => isSameMonth(row.periodMonth, previousMonth))
        .firstOrNull;

    final results = await Future.wait<Object>([
      _fetchCategorySpend(householdId: householdId, month: selectedMonth),
      _fetchBudgetProgress(householdId: householdId, month: selectedMonth),
      fetchCategories(householdId: householdId),
      _fetchTopMerchants(householdId: householdId, month: selectedMonth),
      _fetchOpenReviewCount(householdId: householdId),
    ]);

    final topCategories = results[0] as List<CategorySpend>;
    final budgetProgress = results[1] as List<BudgetProgress>;
    final categories = results[2] as List<CategoryOption>;
    final topMerchants = results[3] as List<MerchantSpend>;
    final reviewQueueCount = results[4] as int;
    final cappedIds = budgetProgress.map((row) => row.categoryId).toSet();
    final uncappedCategories = categories
        .where((category) => !cappedIds.contains(category.id))
        .toList();

    return DashboardSnapshot(
      availableMonths: availableMonths,
      selectedMonth: selectedMonth,
      monthlySpend: selectedSpend,
      previousMonthSpend: previousSpend,
      reviewQueueCount: reviewQueueCount,
      budgetProgress: budgetProgress,
      uncappedCategories: uncappedCategories,
      topCategories: topCategories,
      topMerchants: topMerchants,
    );
  }

  @override
  Future<List<CategoryOption>> fetchCategories({
    required String householdId,
  }) async {
    final rows = await _client
        .from('categories')
        .select('id, name')
        .eq('household_id', householdId)
        .order('sort_order')
        .order('name');

    return rows.map(CategoryOption.fromJson).toList(growable: false);
  }

  @override
  Future<List<SourceAccountOption>> fetchSourceAccounts({
    required String householdId,
  }) async {
    final rows = await _client
        .from('source_accounts')
        .select('id, display_name, cardholder_name')
        .eq('household_id', householdId)
        .eq('is_active', true)
        .order('display_name');

    return rows.map(SourceAccountOption.fromJson).toList(growable: false);
  }

  @override
  Future<PagedTransactions> fetchTransactions(TransactionQuery query) async {
    final categories = await fetchCategories(householdId: query.householdId);
    final categoryNamesById = {
      for (final category in categories) category.id: category.name,
    };

    var request = _client
        .from('transactions')
        .select(
          'id, transaction_date, statement_merchant, category_id, '
          'source_account_id, transaction_type, amount, gross_spend, '
          'refund_amount, net_expense, currency_code, confidence, '
          'cardholder_name, notes',
        )
        .eq('household_id', query.householdId);

    final searchText = query.searchText.trim();
    if (searchText.isNotEmpty) {
      request = request.ilike('statement_merchant', '%$searchText%');
    }

    if (query.categoryId != null) {
      request = request.eq('category_id', query.categoryId!);
    }

    if (query.sourceAccountId != null) {
      request = request.eq('source_account_id', query.sourceAccountId!);
    }

    if (query.startDate != null) {
      request = request.gte('transaction_date', dateString(query.startDate!));
    }

    if (query.endDate != null) {
      request = request.lte('transaction_date', dateString(query.endDate!));
    }

    final from = query.page * query.pageSize;
    final to = from + query.pageSize - 1;
    final rows = await request
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false)
        .range(from, to);

    return PagedTransactions(
      items: rows
          .map(
            (row) => FinanceTransaction.fromJson(
              row,
              categoryNamesById: categoryNamesById,
            ),
          )
          .toList(growable: false),
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<void> saveCategoryCap({
    required String householdId,
    required String profileId,
    required String categoryId,
    required DateTime periodMonth,
    required double capAmount,
  }) async {
    await _client.from('category_caps').upsert({
      'household_id': householdId,
      'category_id': categoryId,
      'period_month': dateString(firstDayOfMonth(periodMonth)),
      'cap_amount': capAmount,
      'created_by': profileId,
    }, onConflict: 'household_id,category_id,period_month');
  }

  Future<List<MonthlySpend>> _fetchMonthlySpend({
    required String householdId,
  }) async {
    final rows = await _client
        .from('v_monthly_spend')
        .select(
          'period_month, transaction_count, gross_spend, refund_amount, '
          'net_spend, bill_payments',
        )
        .eq('household_id', householdId)
        .order('period_month', ascending: false);

    return rows.map(MonthlySpend.fromJson).toList(growable: false);
  }

  Future<List<CategorySpend>> _fetchCategorySpend({
    required String householdId,
    required DateTime month,
  }) async {
    final rows = await _client
        .from('v_category_monthly_spend')
        .select(
          'category_id, category_name, transaction_count, refund_amount, '
          'net_spend',
        )
        .eq('household_id', householdId)
        .eq('period_month', dateString(firstDayOfMonth(month)))
        .order('net_spend', ascending: false)
        .limit(8);

    return rows.map(CategorySpend.fromJson).toList(growable: false);
  }

  Future<List<BudgetProgress>> _fetchBudgetProgress({
    required String householdId,
    required DateTime month,
  }) async {
    final rows = await _client
        .from('v_budget_progress')
        .select(
          'category_id, category_name, cap_amount, spent_amount, '
          'remaining_amount, percent_used, is_over_budget',
        )
        .eq('household_id', householdId)
        .eq('period_month', dateString(firstDayOfMonth(month)))
        .order('percent_used', ascending: false, nullsFirst: false);

    return rows.map(BudgetProgress.fromJson).toList(growable: false);
  }

  Future<List<MerchantSpend>> _fetchTopMerchants({
    required String householdId,
    required DateTime month,
  }) async {
    final monthStart = firstDayOfMonth(month);
    final nextMonth = addMonths(monthStart, 1);
    final rows = await _client
        .from('transactions')
        .select(
          'statement_merchant, normalized_statement_merchant, '
          'net_expense, refund_amount',
        )
        .eq('household_id', householdId)
        .gte('transaction_date', dateString(monthStart))
        .lt('transaction_date', dateString(nextMonth));

    final totals = <String, _MerchantAccumulator>{};
    for (final row in rows) {
      final merchant = (row['statement_merchant'] as String?)?.trim();
      final normalized = (row['normalized_statement_merchant'] as String?)
          ?.trim();
      final name = (merchant == null || merchant.isEmpty)
          ? (normalized == null || normalized.isEmpty ? 'Unknown' : normalized)
          : merchant;
      final accumulator = totals.putIfAbsent(
        name,
        () => _MerchantAccumulator(name),
      );
      accumulator.count += 1;
      accumulator.netSpend += _asDouble(row['net_expense']);
      accumulator.refundAmount += _asDouble(row['refund_amount']);
    }

    final merchants =
        totals.values
            .map(
              (total) => MerchantSpend(
                merchantName: total.name,
                transactionCount: total.count,
                netSpend: total.netSpend,
                refundAmount: total.refundAmount,
              ),
            )
            .toList()
          ..sort((a, b) => b.netSpend.compareTo(a.netSpend));

    return merchants.take(5).toList(growable: false);
  }

  Future<int> _fetchOpenReviewCount({required String householdId}) async {
    final rows = await _client
        .from('v_review_queue')
        .select('review_item_id')
        .eq('household_id', householdId);

    return rows.length;
  }

  DateTime _selectReportingMonth({
    required List<MonthlySpend> monthlySpend,
    required DateTime? requestedMonth,
  }) {
    final requested = requestedMonth == null
        ? null
        : firstDayOfMonth(requestedMonth);
    if (requested != null) return requested;

    final currentMonth = firstDayOfMonth(DateTime.now());
    if (monthlySpend.any((row) => isSameMonth(row.periodMonth, currentMonth))) {
      return currentMonth;
    }

    return monthlySpend.isEmpty ? currentMonth : monthlySpend.first.periodMonth;
  }
}

final class DisabledFinanceRepository implements FinanceRepository {
  const DisabledFinanceRepository();

  @override
  Future<DashboardSnapshot> fetchDashboardSnapshot({
    required String householdId,
    DateTime? requestedMonth,
  }) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<List<CategoryOption>> fetchCategories({required String householdId}) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<List<SourceAccountOption>> fetchSourceAccounts({
    required String householdId,
  }) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<PagedTransactions> fetchTransactions(TransactionQuery query) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<void> saveCategoryCap({
    required String householdId,
    required String profileId,
    required String categoryId,
    required DateTime periodMonth,
    required double capAmount,
  }) {
    throw const SupabaseNotConfiguredException();
  }
}

final class _MerchantAccumulator {
  _MerchantAccumulator(this.name);

  final String name;
  int count = 0;
  double netSpend = 0;
  double refundAmount = 0;
}

DateTime firstDayOfMonth(DateTime date) {
  return DateTime(date.year, date.month);
}

DateTime addMonths(DateTime date, int months) {
  return DateTime(date.year, date.month + months);
}

bool isSameMonth(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month;
}

String dateString(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');

  return '${normalized.year}-$month-$day';
}

String formatMonth(DateTime month) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${names[month.month - 1]} ${month.year}';
}

String formatMoney(double amount, {String currencyCode = 'INR'}) {
  final isNegative = amount < 0;
  final absolute = amount.abs();
  final rounded = absolute.round();
  final formatted = _withThousands(rounded);

  return '${isNegative ? '-' : ''}$currencyCode $formatted';
}

String formatSignedMoney(double amount, {String currencyCode = 'INR'}) {
  if (amount == 0) return formatMoney(0, currencyCode: currencyCode);

  final sign = amount > 0 ? '+' : '-';
  return '$sign${formatMoney(amount.abs(), currencyCode: currencyCode)}';
}

String formatPercent(double value) {
  return '${(value * 100).round()}%';
}

String _withThousands(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i += 1) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  return buffer.toString();
}

DateTime _parseDate(String value) {
  return DateTime.parse(value);
}

double _asDouble(Object? value) {
  return switch (value) {
    null => 0,
    int() => value.toDouble(),
    double() => value,
    String() => double.parse(value),
    _ => throw FormatException('Expected numeric value, got $value'),
  };
}

int _asInt(Object? value) {
  return switch (value) {
    null => 0,
    int() => value,
    num() => value.toInt(),
    String() => int.parse(value),
    _ => throw FormatException('Expected integer value, got $value'),
  };
}

String? _monthKey(DateTime? date) {
  return date == null ? null : dateString(firstDayOfMonth(date));
}

String? _dateKey(DateTime? date) {
  return date == null ? null : dateString(date);
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;

    return null;
  }
}
