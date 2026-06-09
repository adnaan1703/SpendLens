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

final trendReportProvider = FutureProvider.family<TrendReport, TrendQuery>((
  ref,
  query,
) {
  return ref.watch(financeRepositoryProvider).fetchTrendReport(query);
});

final merchantReviewQueueProvider =
    FutureProvider.family<List<MerchantReviewItem>, String>((ref, householdId) {
      return ref
          .watch(financeRepositoryProvider)
          .fetchMerchantReviewQueue(householdId: householdId);
    });

final gmailConnectorStatusProvider =
    FutureProvider.family<List<GmailConnectorStatus>, String>((
      ref,
      householdId,
    ) {
      return ref
          .watch(financeRepositoryProvider)
          .fetchGmailConnectorStatus(householdId: householdId);
    });

final aiBudgetStatusProvider = FutureProvider.family<AiBudgetStatus, String>((
  ref,
  householdId,
) {
  return ref
      .watch(financeRepositoryProvider)
      .fetchAiBudgetStatus(householdId: householdId);
});

final merchantResearchSuggestionsProvider =
    FutureProvider.family<List<MerchantResearchSuggestion>, String>((
      ref,
      householdId,
    ) {
      return ref
          .watch(financeRepositoryProvider)
          .fetchMerchantResearchSuggestions(householdId: householdId);
    });

final merchantSubcategoriesProvider =
    FutureProvider.family<List<SubcategoryOption>, String>((ref, householdId) {
      return ref
          .watch(financeRepositoryProvider)
          .fetchSubcategories(householdId: householdId);
    });

final merchantOptionsProvider =
    FutureProvider.family<List<MerchantOption>, String>((ref, householdId) {
      return ref
          .watch(financeRepositoryProvider)
          .fetchMerchants(householdId: householdId);
    });

final piggyBanksProvider =
    FutureProvider.family<List<PiggyBankSummary>, String>((ref, householdId) {
      return ref
          .watch(financeRepositoryProvider)
          .fetchPiggyBanks(householdId: householdId);
    });

final piggyBankEntriesProvider =
    FutureProvider.family<List<PiggyBankEntry>, PiggyBankEntriesRequest>((
      ref,
      request,
    ) {
      return ref
          .watch(financeRepositoryProvider)
          .fetchPiggyBankEntries(
            householdId: request.householdId,
            piggyBankId: request.piggyBankId,
          );
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
    this.sourceAccountType,
    this.sourceAccountId,
    this.startDate,
    this.endDate,
    this.page = 0,
    this.pageSize = 25,
  });

  final String householdId;
  final String searchText;
  final String? categoryId;
  final String? sourceAccountType;
  final String? sourceAccountId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int page;
  final int pageSize;

  TransactionQuery copyWith({
    String? searchText,
    String? categoryId,
    bool clearCategory = false,
    String? sourceAccountType,
    bool clearSourceAccountType = false,
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
      sourceAccountType: clearSourceAccountType
          ? null
          : sourceAccountType ?? this.sourceAccountType,
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
        other.sourceAccountType == sourceAccountType &&
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
    sourceAccountType,
    sourceAccountId,
    _dateKey(startDate),
    _dateKey(endDate),
    page,
    pageSize,
  );
}

final class TrendQuery {
  const TrendQuery({
    required this.householdId,
    this.categoryId,
    this.sourceAccountType,
    this.sourceAccountId,
    this.startDate,
    this.endDate,
  });

  final String householdId;
  final String? categoryId;
  final String? sourceAccountType;
  final String? sourceAccountId;
  final DateTime? startDate;
  final DateTime? endDate;

  TrendQuery copyWith({
    String? categoryId,
    bool clearCategory = false,
    String? sourceAccountType,
    bool clearSourceAccountType = false,
    String? sourceAccountId,
    bool clearSourceAccount = false,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
  }) {
    return TrendQuery(
      householdId: householdId,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
      sourceAccountType: clearSourceAccountType
          ? null
          : sourceAccountType ?? this.sourceAccountType,
      sourceAccountId: clearSourceAccount
          ? null
          : sourceAccountId ?? this.sourceAccountId,
      startDate: clearStartDate ? null : startDate ?? this.startDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TrendQuery &&
        other.householdId == householdId &&
        other.categoryId == categoryId &&
        other.sourceAccountType == sourceAccountType &&
        other.sourceAccountId == sourceAccountId &&
        _dateKey(other.startDate) == _dateKey(startDate) &&
        _dateKey(other.endDate) == _dateKey(endDate);
  }

  @override
  int get hashCode => Object.hash(
    householdId,
    categoryId,
    sourceAccountType,
    sourceAccountId,
    _dateKey(startDate),
    _dateKey(endDate),
  );
}

final class PiggyBankEntriesRequest {
  const PiggyBankEntriesRequest({
    required this.householdId,
    required this.piggyBankId,
  });

  final String householdId;
  final String piggyBankId;

  @override
  bool operator ==(Object other) {
    return other is PiggyBankEntriesRequest &&
        other.householdId == householdId &&
        other.piggyBankId == piggyBankId;
  }

  @override
  int get hashCode => Object.hash(householdId, piggyBankId);
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

final class TrendReport {
  const TrendReport({
    required this.transactions,
    required this.monthlySpend,
    required this.categoryTrends,
    required this.merchantSummaries,
  });

  final List<TrendReportTransaction> transactions;
  final List<MonthlySpend> monthlySpend;
  final List<CategoryTrend> categoryTrends;
  final List<MerchantSummary> merchantSummaries;

  bool get isEmpty => transactions.isEmpty;

  int get transactionCount => transactions.length;

  double get grossSpend {
    return transactions.fold<double>(0, (total, row) => total + row.grossSpend);
  }

  double get refundAmount {
    return transactions.fold<double>(
      0,
      (total, row) => total + row.refundAmount,
    );
  }

  double get netSpend {
    return transactions.fold<double>(0, (total, row) => total + row.netExpense);
  }

  String toTransactionsCsv() {
    final rows = <List<Object?>>[
      [
        'Date',
        'Cardholder',
        'Source',
        'Statement merchant',
        'Merchant group',
        'Category',
        'Subcategory',
        'Transaction type',
        'Gross spend',
        'Refunds',
        'Net expense',
        'Amount',
        'Currency',
      ],
      for (final transaction in transactions)
        [
          dateString(transaction.transactionDate),
          transaction.cardholderName,
          transaction.sourceLabel,
          transaction.statementMerchant,
          transaction.merchantGroup,
          transaction.categoryName,
          transaction.subcategoryName,
          transaction.transactionType,
          transaction.grossSpend.toStringAsFixed(2),
          transaction.refundAmount.toStringAsFixed(2),
          transaction.netExpense.toStringAsFixed(2),
          transaction.amount.toStringAsFixed(2),
          transaction.currencyCode,
        ],
    ];

    return rows.map(_csvRow).join('\n');
  }

  factory TrendReport.fromTransactions(
    List<TrendReportTransaction> transactions,
  ) {
    final sortedTransactions = [...transactions]
      ..sort((a, b) {
        final dateComparison = a.transactionDate.compareTo(b.transactionDate);
        if (dateComparison != 0) return dateComparison;

        return a.statementMerchant.compareTo(b.statementMerchant);
      });

    final monthlyTotals = <String, _MonthlyTrendAccumulator>{};
    final categoryTotals = <String, _CategoryTrendAccumulator>{};
    final merchantTotals = <String, _MerchantSummaryAccumulator>{};

    for (final transaction in sortedTransactions) {
      final month = firstDayOfMonth(transaction.transactionDate);
      final monthKey = dateString(month);
      monthlyTotals
          .putIfAbsent(monthKey, () => _MonthlyTrendAccumulator(month))
          .add(transaction);

      if (transaction.isBillPayment) continue;

      final categoryId = transaction.categoryId;
      if (categoryId != null) {
        categoryTotals
            .putIfAbsent(
              categoryId,
              () => _CategoryTrendAccumulator(
                categoryId: categoryId,
                categoryName: transaction.categoryName ?? 'Uncategorized',
              ),
            )
            .add(transaction, month);
      }

      final merchantKey = [
        transaction.merchantId ?? transaction.merchantGroup,
        transaction.categoryId ?? '',
        transaction.subcategoryId ?? '',
      ].join('|');
      merchantTotals
          .putIfAbsent(
            merchantKey,
            () => _MerchantSummaryAccumulator(
              merchantGroup: transaction.merchantGroup,
              categoryName: transaction.categoryName,
              subcategoryName: transaction.subcategoryName,
            ),
          )
          .add(transaction);
    }

    final monthlySpend =
        monthlyTotals.values.map((total) => total.toMonthlySpend()).toList()
          ..sort((a, b) => a.periodMonth.compareTo(b.periodMonth));
    final monthKeys = monthlySpend
        .map((month) => dateString(month.periodMonth))
        .toList(growable: false);

    final categoryTrends =
        categoryTotals.values
            .map((total) => total.toCategoryTrend(monthKeys))
            .toList()
          ..sort((a, b) {
            final spendComparison = b.netSpend.compareTo(a.netSpend);
            if (spendComparison != 0) return spendComparison;

            return a.categoryName.compareTo(b.categoryName);
          });

    final merchantSummaries =
        merchantTotals.values.map((total) => total.toMerchantSummary()).toList()
          ..sort((a, b) {
            final spendComparison = b.netSpend.compareTo(a.netSpend);
            if (spendComparison != 0) return spendComparison;

            return a.merchantGroup.compareTo(b.merchantGroup);
          });

    return TrendReport(
      transactions: sortedTransactions,
      monthlySpend: monthlySpend,
      categoryTrends: categoryTrends,
      merchantSummaries: merchantSummaries,
    );
  }
}

final class TrendReportTransaction {
  const TrendReportTransaction({
    required this.id,
    required this.transactionDate,
    required this.statementMerchant,
    required this.merchantGroup,
    this.merchantId,
    this.categoryId,
    this.categoryName,
    this.subcategoryId,
    this.subcategoryName,
    this.sourceAccountId,
    this.sourceLabel,
    required this.transactionType,
    required this.amount,
    required this.grossSpend,
    required this.refundAmount,
    required this.netExpense,
    required this.currencyCode,
    this.cardholderName,
  });

  final String id;
  final DateTime transactionDate;
  final String statementMerchant;
  final String merchantGroup;
  final String? merchantId;
  final String? categoryId;
  final String? categoryName;
  final String? subcategoryId;
  final String? subcategoryName;
  final String? sourceAccountId;
  final String? sourceLabel;
  final String transactionType;
  final double amount;
  final double grossSpend;
  final double refundAmount;
  final double netExpense;
  final String currencyCode;
  final String? cardholderName;

  bool get isBillPayment => transactionType == 'bill_payment_credit';

  factory TrendReportTransaction.fromJson(
    Map<String, dynamic> json, {
    required Map<String, String> categoryNamesById,
    required Map<String, String> subcategoryNamesById,
    required Map<String, String> merchantNamesById,
    required Map<String, String> sourceLabelsById,
  }) {
    final merchantId = json['merchant_id'] as String?;
    final categoryId = json['category_id'] as String?;
    final subcategoryId = json['subcategory_id'] as String?;
    final sourceAccountId = json['source_account_id'] as String?;
    final merchantName = merchantId == null
        ? null
        : merchantNamesById[merchantId];
    final normalizedMerchant =
        (json['normalized_statement_merchant'] as String?)?.trim();
    final statementMerchant = json['statement_merchant'] as String;

    return TrendReportTransaction(
      id: json['id'] as String,
      transactionDate: _parseDate(json['transaction_date'] as String),
      statementMerchant: statementMerchant,
      merchantGroup:
          merchantName ??
          (normalizedMerchant == null || normalizedMerchant.isEmpty
              ? statementMerchant
              : normalizedMerchant),
      merchantId: merchantId,
      categoryId: categoryId,
      categoryName: categoryId == null ? null : categoryNamesById[categoryId],
      subcategoryId: subcategoryId,
      subcategoryName: subcategoryId == null
          ? null
          : subcategoryNamesById[subcategoryId],
      sourceAccountId: sourceAccountId,
      sourceLabel: sourceAccountId == null
          ? null
          : sourceLabelsById[sourceAccountId],
      transactionType: json['transaction_type'] as String,
      amount: _asDouble(json['amount']),
      grossSpend: _asDouble(json['gross_spend']),
      refundAmount: _asDouble(json['refund_amount']),
      netExpense: _asDouble(json['net_expense']),
      currencyCode: json['currency_code'] as String? ?? 'INR',
      cardholderName: json['cardholder_name'] as String?,
    );
  }
}

final class CategoryTrend {
  const CategoryTrend({
    required this.categoryId,
    required this.categoryName,
    required this.transactionCount,
    required this.grossSpend,
    required this.refundAmount,
    required this.netSpend,
    required this.months,
  });

  final String categoryId;
  final String categoryName;
  final int transactionCount;
  final double grossSpend;
  final double refundAmount;
  final double netSpend;
  final List<CategoryTrendMonth> months;
}

final class CategoryTrendMonth {
  const CategoryTrendMonth({
    required this.periodMonth,
    required this.transactionCount,
    required this.grossSpend,
    required this.refundAmount,
    required this.netSpend,
  });

  final DateTime periodMonth;
  final int transactionCount;
  final double grossSpend;
  final double refundAmount;
  final double netSpend;
}

final class MerchantSummary {
  const MerchantSummary({
    required this.merchantGroup,
    this.categoryName,
    this.subcategoryName,
    required this.transactionCount,
    required this.grossSpend,
    required this.refundAmount,
    required this.netSpend,
  });

  final String merchantGroup;
  final String? categoryName;
  final String? subcategoryName;
  final int transactionCount;
  final double grossSpend;
  final double refundAmount;
  final double netSpend;
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
    required this.type,
    required this.displayName,
    this.cardholderName,
  });

  final String id;
  final String type;
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
      type: json['type'] as String? ?? 'other',
      displayName: json['display_name'] as String,
      cardholderName: json['cardholder_name'] as String?,
    );
  }
}

final class SubcategoryOption {
  const SubcategoryOption({
    required this.id,
    required this.categoryId,
    required this.name,
  });

  final String id;
  final String categoryId;
  final String name;

  factory SubcategoryOption.fromJson(Map<String, dynamic> json) {
    return SubcategoryOption(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      name: json['name'] as String,
    );
  }
}

final class CategoryCreationRequest {
  const CategoryCreationRequest({
    required this.householdId,
    required this.categoryName,
    required this.subcategoryName,
  });

  final String householdId;
  final String categoryName;
  final String subcategoryName;
}

final class CategoryCreationResult {
  const CategoryCreationResult({
    required this.category,
    required this.subcategory,
  });

  final CategoryOption category;
  final SubcategoryOption subcategory;

  factory CategoryCreationResult.fromJson(Map<String, dynamic> json) {
    final categoryId = json['category_id'] as String;

    return CategoryCreationResult(
      category: CategoryOption(
        id: categoryId,
        name: json['category_name'] as String,
      ),
      subcategory: SubcategoryOption(
        id: json['subcategory_id'] as String,
        categoryId: categoryId,
        name: json['subcategory_name'] as String,
      ),
    );
  }
}

final class MerchantOption {
  const MerchantOption({required this.id, required this.displayName});

  final String id;
  final String displayName;

  factory MerchantOption.fromJson(Map<String, dynamic> json) {
    return MerchantOption(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
    );
  }
}

final class MerchantReviewItem {
  const MerchantReviewItem({
    required this.id,
    required this.householdId,
    required this.transactionId,
    required this.reason,
    required this.createdAt,
    required this.transactionDate,
    required this.statementMerchant,
    required this.amount,
    required this.netExpense,
    required this.confidence,
    this.currentMerchantId,
    this.currentMerchantName,
    this.currentCategoryId,
    this.currentCategoryName,
    this.currentSubcategoryId,
    this.currentSubcategoryName,
    this.suggestedMerchantId,
    this.suggestedMerchantName,
    this.suggestedCategoryId,
    this.suggestedCategoryName,
    this.suggestedSubcategoryId,
    this.suggestedSubcategoryName,
  });

  final String id;
  final String householdId;
  final String transactionId;
  final String reason;
  final DateTime createdAt;
  final DateTime transactionDate;
  final String statementMerchant;
  final double amount;
  final double netExpense;
  final String confidence;
  final String? currentMerchantId;
  final String? currentMerchantName;
  final String? currentCategoryId;
  final String? currentCategoryName;
  final String? currentSubcategoryId;
  final String? currentSubcategoryName;
  final String? suggestedMerchantId;
  final String? suggestedMerchantName;
  final String? suggestedCategoryId;
  final String? suggestedCategoryName;
  final String? suggestedSubcategoryId;
  final String? suggestedSubcategoryName;

  String get correctionMerchantName {
    return currentMerchantName ?? suggestedMerchantName ?? statementMerchant;
  }

  String? get correctionCategoryId => currentCategoryId ?? suggestedCategoryId;

  String? get correctionSubcategoryId {
    return currentSubcategoryId ?? suggestedSubcategoryId;
  }

  factory MerchantReviewItem.fromJson(Map<String, dynamic> json) {
    return MerchantReviewItem(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      transactionId: json['transaction_id'] as String,
      reason: json['reason'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      transactionDate: _parseDate(json['transaction_date'] as String),
      statementMerchant: json['statement_merchant'] as String,
      amount: _asDouble(json['amount']),
      netExpense: _asDouble(json['net_expense']),
      confidence: json['transaction_confidence'] as String? ?? 'medium',
      currentMerchantId: json['current_merchant_id'] as String?,
      currentMerchantName: json['current_merchant_name'] as String?,
      currentCategoryId: json['current_category_id'] as String?,
      currentCategoryName: json['current_category_name'] as String?,
      currentSubcategoryId: json['current_subcategory_id'] as String?,
      currentSubcategoryName: json['current_subcategory_name'] as String?,
      suggestedMerchantId: json['suggested_merchant_id'] as String?,
      suggestedMerchantName: json['suggested_merchant_name'] as String?,
      suggestedCategoryId: json['suggested_category_id'] as String?,
      suggestedCategoryName: json['suggested_category_name'] as String?,
      suggestedSubcategoryId: json['suggested_subcategory_id'] as String?,
      suggestedSubcategoryName: json['suggested_subcategory_name'] as String?,
    );
  }
}

final class TransactionMetadataCorrectionRequest {
  const TransactionMetadataCorrectionRequest({
    required this.householdId,
    required this.transactionId,
    required this.merchantGroup,
    required this.categoryId,
    required this.subcategoryId,
    this.reviewItemId,
    this.confidence = 'manual',
    this.notes,
  });

  final String householdId;
  final String transactionId;
  final String merchantGroup;
  final String categoryId;
  final String subcategoryId;
  final String? reviewItemId;
  final String confidence;
  final String? notes;
}

final class TransactionMetadataSuggestionRequest {
  const TransactionMetadataSuggestionRequest({
    required this.householdId,
    required this.transactionId,
    this.reviewItemId,
  });

  final String householdId;
  final String transactionId;
  final String? reviewItemId;
}

final class TransactionMetadataSuggestionResult {
  const TransactionMetadataSuggestionResult({
    required this.merchantGroup,
    required this.categoryId,
    required this.subcategoryId,
    required this.confidence,
    required this.notes,
  });

  final String merchantGroup;
  final String categoryId;
  final String subcategoryId;
  final String confidence;
  final String notes;

  factory TransactionMetadataSuggestionResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return TransactionMetadataSuggestionResult(
      merchantGroup: json['merchant_group'] as String,
      categoryId: json['category_id'] as String,
      subcategoryId: json['subcategory_id'] as String,
      confidence: json['confidence'] as String,
      notes: json['notes'] as String? ?? '',
    );
  }
}

final class TransactionMetadataCorrectionResult {
  const TransactionMetadataCorrectionResult({
    required this.ruleId,
    required this.merchantId,
    required this.categoryId,
    required this.subcategoryId,
    required this.updatedTransactionCount,
    required this.resolvedReviewItemCount,
  });

  final String ruleId;
  final String merchantId;
  final String categoryId;
  final String subcategoryId;
  final int updatedTransactionCount;
  final int resolvedReviewItemCount;

  factory TransactionMetadataCorrectionResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return TransactionMetadataCorrectionResult(
      ruleId: json['rule_id'] as String,
      merchantId: json['merchant_id'] as String,
      categoryId: json['category_id'] as String,
      subcategoryId: json['subcategory_id'] as String,
      updatedTransactionCount: _asInt(json['updated_transaction_count']),
      resolvedReviewItemCount: _asInt(json['resolved_review_item_count']),
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
    this.merchantId,
    this.merchantName,
    this.categoryId,
    this.categoryName,
    this.subcategoryId,
    this.subcategoryName,
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
  final String? merchantId;
  final String? merchantName;
  final String? categoryId;
  final String? categoryName;
  final String? subcategoryId;
  final String? subcategoryName;
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
    required Map<String, String> subcategoryNamesById,
    required Map<String, String> merchantNamesById,
  }) {
    final merchantId = json['merchant_id'] as String?;
    final categoryId = json['category_id'] as String?;
    final subcategoryId = json['subcategory_id'] as String?;

    return FinanceTransaction(
      id: json['id'] as String,
      transactionDate: _parseDate(json['transaction_date'] as String),
      statementMerchant: json['statement_merchant'] as String,
      merchantId: merchantId,
      merchantName: merchantId == null ? null : merchantNamesById[merchantId],
      categoryId: categoryId,
      categoryName: categoryId == null
          ? null
          : categoryNamesById[categoryId] ?? 'Uncategorized',
      subcategoryId: subcategoryId,
      subcategoryName: subcategoryId == null
          ? null
          : subcategoryNamesById[subcategoryId] ?? 'Uncategorized',
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

final class PiggyBankSummary {
  const PiggyBankSummary({
    required this.id,
    required this.householdId,
    required this.name,
    this.description,
    this.targetAmount,
    this.targetDate,
    required this.currencyCode,
    required this.isArchived,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.balanceAmount,
    this.targetProgress,
  });

  final String id;
  final String householdId;
  final String name;
  final String? description;
  final double? targetAmount;
  final DateTime? targetDate;
  final String currencyCode;
  final bool isArchived;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double balanceAmount;
  final double? targetProgress;

  double? get remainingToTarget {
    final target = targetAmount;
    if (target == null) return null;

    return target - balanceAmount;
  }

  factory PiggyBankSummary.fromJson(Map<String, dynamic> json) {
    return PiggyBankSummary(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      targetAmount: json['target_amount'] == null
          ? null
          : _asDouble(json['target_amount']),
      targetDate: json['target_date'] == null
          ? null
          : _parseDate(json['target_date'] as String),
      currencyCode: json['currency_code'] as String? ?? 'INR',
      isArchived: json['is_archived'] as bool? ?? false,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      balanceAmount: _asDouble(json['balance_amount']),
      targetProgress: json['target_progress'] == null
          ? null
          : _asDouble(json['target_progress']),
    );
  }
}

final class PiggyBankEntry {
  const PiggyBankEntry({
    required this.id,
    required this.householdId,
    required this.piggyBankId,
    required this.entryType,
    required this.amount,
    required this.entryDate,
    this.note,
    this.linkedTransactionId,
    this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String householdId;
  final String piggyBankId;
  final String entryType;
  final double amount;
  final DateTime entryDate;
  final String? note;
  final String? linkedTransactionId;
  final String? createdBy;
  final DateTime createdAt;

  double get signedAmount {
    return switch (entryType) {
      'deposit' => amount,
      'withdrawal' => -amount,
      'adjustment' => amount,
      _ => amount,
    };
  }

  String get typeLabel {
    return entryType.replaceAll('_', ' ');
  }

  factory PiggyBankEntry.fromJson(Map<String, dynamic> json) {
    return PiggyBankEntry(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      piggyBankId: json['piggy_bank_id'] as String,
      entryType: json['entry_type'] as String,
      amount: _asDouble(json['amount']),
      entryDate: _parseDate(json['entry_date'] as String),
      note: json['note'] as String?,
      linkedTransactionId: json['linked_transaction_id'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

final class PiggyBankSaveRequest {
  const PiggyBankSaveRequest({
    this.id,
    required this.householdId,
    required this.profileId,
    required this.name,
    this.description,
    this.targetAmount,
    this.targetDate,
    this.currencyCode = 'INR',
  });

  final String? id;
  final String householdId;
  final String profileId;
  final String name;
  final String? description;
  final double? targetAmount;
  final DateTime? targetDate;
  final String currencyCode;

  bool get isCreate => id == null;
}

final class PiggyBankEntryRequest {
  const PiggyBankEntryRequest({
    required this.householdId,
    required this.piggyBankId,
    required this.entryType,
    required this.amount,
    required this.entryDate,
    this.note,
    this.linkedTransactionId,
  });

  final String householdId;
  final String piggyBankId;
  final String entryType;
  final double amount;
  final DateTime entryDate;
  final String? note;
  final String? linkedTransactionId;
}

final class GmailConnectorStatus {
  const GmailConnectorStatus({
    required this.id,
    required this.householdId,
    required this.email,
    required this.connectorStatus,
    required this.isActive,
    required this.queuedJobCount,
    this.watchExpiresAt,
    this.lastSyncAt,
    this.lastError,
    this.latestJobError,
  });

  final String id;
  final String householdId;
  final String email;
  final String connectorStatus;
  final bool isActive;
  final int queuedJobCount;
  final DateTime? watchExpiresAt;
  final DateTime? lastSyncAt;
  final String? lastError;
  final String? latestJobError;

  String get displayStatus {
    return switch (connectorStatus) {
      'connected' => 'Connected',
      'watch_pending' => 'Watch pending',
      'watch_expired' => 'Watch expired',
      'needs_reconnect' => 'Needs reconnect',
      'error' => 'Error',
      'disconnected' => 'Disconnected',
      _ => connectorStatus,
    };
  }

  factory GmailConnectorStatus.fromJson(Map<String, dynamic> json) {
    return GmailConnectorStatus(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      email: json['email'] as String,
      connectorStatus: json['connector_status'] as String? ?? 'disconnected',
      isActive: json['is_active'] as bool? ?? false,
      queuedJobCount: (json['queued_job_count'] as num?)?.toInt() ?? 0,
      watchExpiresAt: parseOptionalDateTime(json['watch_expires_at']),
      lastSyncAt: parseOptionalDateTime(json['last_sync_at']),
      lastError: json['last_error'] as String?,
      latestJobError: json['latest_job_error'] as String?,
    );
  }
}

final class AiBudgetStatus {
  const AiBudgetStatus({
    required this.householdId,
    required this.provider,
    required this.model,
    required this.monthlySpendCapUsd,
    required this.expenseQaEnabled,
    required this.merchantResearchEnabled,
    required this.merchantResearchWebSearchEnabled,
    required this.freeTierOnly,
    required this.currentPeriodMonth,
    required this.currentMonthSpendUsd,
    required this.currentMonthEventCount,
    required this.remainingMonthlyBudgetUsd,
  });

  final String householdId;
  final String provider;
  final String model;
  final double monthlySpendCapUsd;
  final bool expenseQaEnabled;
  final bool merchantResearchEnabled;
  final bool merchantResearchWebSearchEnabled;
  final bool freeTierOnly;
  final DateTime currentPeriodMonth;
  final double currentMonthSpendUsd;
  final int currentMonthEventCount;
  final double remainingMonthlyBudgetUsd;

  String get modeLabel => freeTierOnly ? 'Free tier' : 'Paid budget';

  String get merchantResearchSearchLabel {
    return merchantResearchWebSearchEnabled ? 'Search enabled' : 'Search off';
  }

  factory AiBudgetStatus.fromJson(Map<String, dynamic> json) {
    return AiBudgetStatus(
      householdId: json['household_id'] as String,
      provider: json['provider'] as String? ?? 'gemini',
      model: json['model'] as String? ?? 'gemini-3.5-flash',
      monthlySpendCapUsd: _asDouble(json['monthly_spend_cap_usd']),
      expenseQaEnabled: json['expense_qa_enabled'] as bool? ?? true,
      merchantResearchEnabled:
          json['merchant_research_enabled'] as bool? ?? true,
      merchantResearchWebSearchEnabled:
          json['merchant_research_web_search_enabled'] as bool? ?? false,
      freeTierOnly: json['free_tier_only'] as bool? ?? true,
      currentPeriodMonth: _parseDate(json['current_period_month'] as String),
      currentMonthSpendUsd: _asDouble(json['current_month_spend_usd']),
      currentMonthEventCount: _asInt(json['current_month_event_count']),
      remainingMonthlyBudgetUsd: _asDouble(
        json['remaining_monthly_budget_usd'],
      ),
    );
  }
}

final class ExpenseQuestionRequest {
  const ExpenseQuestionRequest({
    required this.householdId,
    required this.question,
  });

  final String householdId;
  final String question;
}

final class ExpenseQuestionAnswer {
  const ExpenseQuestionAnswer({
    required this.answer,
    this.jobId,
    this.usageEventId,
    required this.inputTokens,
    required this.outputTokens,
    required this.estimatedCostUsd,
  });

  final String answer;
  final String? jobId;
  final String? usageEventId;
  final int inputTokens;
  final int outputTokens;
  final double estimatedCostUsd;

  factory ExpenseQuestionAnswer.fromJson(Map<String, dynamic> json) {
    final usage = json['usage'] as Map<String, dynamic>? ?? const {};

    return ExpenseQuestionAnswer(
      answer: json['answer'] as String,
      jobId: json['job_id'] as String?,
      usageEventId: json['usage_event_id'] as String?,
      inputTokens: _asInt(usage['inputTokens']),
      outputTokens: _asInt(usage['outputTokens']),
      estimatedCostUsd: _asDouble(json['estimated_cost_usd']),
    );
  }
}

final class MerchantResearchRequest {
  const MerchantResearchRequest({
    required this.householdId,
    required this.reviewItemId,
    required this.statementMerchant,
  });

  final String householdId;
  final String reviewItemId;
  final String statementMerchant;
}

final class MerchantResearchSuggestion {
  const MerchantResearchSuggestion({
    required this.id,
    required this.householdId,
    this.reviewItemId,
    required this.normalizedMerchantName,
    this.statementMerchant,
    this.suggestedDisplayName,
    this.suggestedCategoryName,
    this.suggestedSubcategoryName,
    this.confidence,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String householdId;
  final String? reviewItemId;
  final String normalizedMerchantName;
  final String? statementMerchant;
  final String? suggestedDisplayName;
  final String? suggestedCategoryName;
  final String? suggestedSubcategoryName;
  final String? confidence;
  final String status;
  final DateTime createdAt;

  String get title {
    return suggestedDisplayName ?? statementMerchant ?? normalizedMerchantName;
  }

  String get subtitle {
    final parts = [
      suggestedCategoryName,
      suggestedSubcategoryName,
      confidence,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Pending approval' : parts.join(' / ');
  }

  factory MerchantResearchSuggestion.fromJson(Map<String, dynamic> json) {
    return MerchantResearchSuggestion(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      reviewItemId: json['review_item_id'] as String?,
      normalizedMerchantName: json['normalized_merchant_name'] as String,
      statementMerchant: json['statement_merchant'] as String?,
      suggestedDisplayName: json['suggested_display_name'] as String?,
      suggestedCategoryName: json['suggested_category_name'] as String?,
      suggestedSubcategoryName: json['suggested_subcategory_name'] as String?,
      confidence: json['confidence'] as String?,
      status: json['status'] as String? ?? 'open',
      createdAt: DateTime.parse(json['created_at'] as String),
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

  Future<List<SubcategoryOption>> fetchSubcategories({
    required String householdId,
  });

  Future<CategoryCreationResult> createCategory(
    CategoryCreationRequest request,
  );

  Future<List<MerchantOption>> fetchMerchants({required String householdId});

  Future<List<MerchantReviewItem>> fetchMerchantReviewQueue({
    required String householdId,
  });

  Future<List<GmailConnectorStatus>> fetchGmailConnectorStatus({
    required String householdId,
  });

  Future<AiBudgetStatus> fetchAiBudgetStatus({required String householdId});

  Future<ExpenseQuestionAnswer> askExpenseQuestion(
    ExpenseQuestionRequest request,
  );

  Future<List<MerchantResearchSuggestion>> fetchMerchantResearchSuggestions({
    required String householdId,
  });

  Future<MerchantResearchSuggestion> researchMerchant(
    MerchantResearchRequest request,
  );

  Future<String> startGmailConnector({required String householdId});

  Future<void> disconnectGmailMailbox({required String mailboxId});

  Future<List<PiggyBankSummary>> fetchPiggyBanks({required String householdId});

  Future<PiggyBankSummary> savePiggyBank(PiggyBankSaveRequest request);

  Future<List<PiggyBankEntry>> fetchPiggyBankEntries({
    required String householdId,
    required String piggyBankId,
  });

  Future<PiggyBankEntry> createPiggyBankEntry(PiggyBankEntryRequest request);

  Future<PagedTransactions> fetchTransactions(TransactionQuery query);

  Future<TrendReport> fetchTrendReport(TrendQuery query);

  Future<TransactionMetadataCorrectionResult>
  applyTransactionMetadataCorrection(
    TransactionMetadataCorrectionRequest request,
  );

  Future<TransactionMetadataSuggestionResult> suggestTransactionMetadata(
    TransactionMetadataSuggestionRequest request,
  );

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
        .select('id, type, display_name, cardholder_name')
        .eq('household_id', householdId)
        .eq('is_active', true)
        .order('display_name');

    return rows.map(SourceAccountOption.fromJson).toList(growable: false);
  }

  @override
  Future<List<SubcategoryOption>> fetchSubcategories({
    required String householdId,
  }) async {
    final rows = await _client
        .from('subcategories')
        .select('id, category_id, name')
        .eq('household_id', householdId)
        .order('sort_order')
        .order('name');

    return rows.map(SubcategoryOption.fromJson).toList(growable: false);
  }

  @override
  Future<CategoryCreationResult> createCategory(
    CategoryCreationRequest request,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(
      'create_household_category',
      params: {
        'p_household_id': request.householdId,
        'p_category_name': request.categoryName,
        'p_subcategory_name': request.subcategoryName,
      },
    );

    if (rows.isEmpty) {
      throw StateError('Category creation did not return a result.');
    }

    return CategoryCreationResult.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<List<MerchantOption>> fetchMerchants({
    required String householdId,
  }) async {
    final rows = await _client
        .from('merchants')
        .select('id, display_name')
        .eq('household_id', householdId)
        .order('display_name');

    return rows.map(MerchantOption.fromJson).toList(growable: false);
  }

  @override
  Future<List<MerchantReviewItem>> fetchMerchantReviewQueue({
    required String householdId,
  }) async {
    final rows = await _client
        .from('v_review_queue')
        .select(
          'id, household_id, transaction_id, reason, created_at, '
          'transaction_date, statement_merchant, amount, net_expense, '
          'transaction_confidence, current_merchant_id, '
          'current_merchant_name, current_category_id, current_category_name, '
          'current_subcategory_id, current_subcategory_name, '
          'suggested_merchant_id, suggested_merchant_name, '
          'suggested_category_id, suggested_category_name, '
          'suggested_subcategory_id, suggested_subcategory_name',
        )
        .eq('household_id', householdId)
        .order('created_at');

    return rows.map(MerchantReviewItem.fromJson).toList(growable: false);
  }

  @override
  Future<List<GmailConnectorStatus>> fetchGmailConnectorStatus({
    required String householdId,
  }) async {
    final response = await _client.functions.invoke(
      'gmail-connector-status',
      body: {'household_id': householdId},
    );
    final data = response.data as Map<String, dynamic>;
    final rows = data['mailboxes'] as List<dynamic>? ?? const [];
    return rows
        .cast<Map<String, dynamic>>()
        .map(GmailConnectorStatus.fromJson)
        .toList(growable: false);
  }

  @override
  Future<AiBudgetStatus> fetchAiBudgetStatus({
    required String householdId,
  }) async {
    final row = await _client
        .from('v_ai_budget_status')
        .select(
          'household_id, provider, model, monthly_spend_cap_usd, '
          'expense_qa_enabled, merchant_research_enabled, '
          'merchant_research_web_search_enabled, free_tier_only, '
          'current_period_month, current_month_spend_usd, '
          'current_month_event_count, remaining_monthly_budget_usd',
        )
        .eq('household_id', householdId)
        .single();

    return AiBudgetStatus.fromJson(row);
  }

  @override
  Future<ExpenseQuestionAnswer> askExpenseQuestion(
    ExpenseQuestionRequest request,
  ) async {
    final response = await _client.functions.invoke(
      'expense-qa',
      body: {'household_id': request.householdId, 'question': request.question},
    );
    final data = response.data as Map<String, dynamic>;
    return ExpenseQuestionAnswer.fromJson(data);
  }

  @override
  Future<List<MerchantResearchSuggestion>> fetchMerchantResearchSuggestions({
    required String householdId,
  }) async {
    final rows = await _client
        .from('v_open_merchant_research_suggestions')
        .select(
          'id, household_id, review_item_id, normalized_merchant_name, '
          'statement_merchant, suggested_display_name, '
          'suggested_category_name, suggested_subcategory_name, confidence, '
          'status, created_at',
        )
        .eq('household_id', householdId)
        .order('created_at', ascending: false);

    return rows
        .map(MerchantResearchSuggestion.fromJson)
        .toList(growable: false);
  }

  @override
  Future<MerchantResearchSuggestion> researchMerchant(
    MerchantResearchRequest request,
  ) async {
    final response = await _client.functions.invoke(
      'merchant-research',
      body: {
        'household_id': request.householdId,
        'review_item_id': request.reviewItemId,
        'statement_merchant': request.statementMerchant,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final suggestion = data['suggestion'] as Map<String, dynamic>?;
    if (suggestion == null) {
      throw StateError('Merchant research did not return a suggestion.');
    }

    return MerchantResearchSuggestion.fromJson(suggestion);
  }

  @override
  Future<String> startGmailConnector({required String householdId}) async {
    final response = await _client.functions.invoke(
      'gmail-oauth-start',
      body: {'household_id': householdId},
    );
    final data = response.data as Map<String, dynamic>;
    final authorizationUrl = data['authorizationUrl'] as String?;
    if (authorizationUrl == null || authorizationUrl.isEmpty) {
      throw StateError(
        'Gmail OAuth start did not return an authorization URL.',
      );
    }
    return authorizationUrl;
  }

  @override
  Future<void> disconnectGmailMailbox({required String mailboxId}) async {
    await _client.functions.invoke(
      'gmail-disconnect',
      body: {'mailbox_id': mailboxId},
    );
  }

  @override
  Future<List<PiggyBankSummary>> fetchPiggyBanks({
    required String householdId,
  }) async {
    final rows = await _client
        .from('v_piggy_bank_balances')
        .select(
          'id, household_id, name, description, target_amount, target_date, '
          'currency_code, is_archived, created_by, created_at, updated_at, '
          'balance_amount, target_progress',
        )
        .eq('household_id', householdId)
        .eq('is_archived', false)
        .order('created_at', ascending: false);

    return rows.map(PiggyBankSummary.fromJson).toList(growable: false);
  }

  @override
  Future<PiggyBankSummary> savePiggyBank(PiggyBankSaveRequest request) async {
    final name = request.name.trim();
    final description = request.description?.trim();

    if (name.isEmpty) {
      throw ArgumentError.value(request.name, 'name', 'Name is required.');
    }

    final targetAmount = request.targetAmount;
    if (targetAmount != null && targetAmount < 0) {
      throw ArgumentError.value(
        targetAmount,
        'targetAmount',
        'Target amount cannot be negative.',
      );
    }

    final payload = <String, Object?>{
      'household_id': request.householdId,
      'name': name,
      'description': description == null || description.isEmpty
          ? null
          : description,
      'target_amount': targetAmount,
      'target_date': request.targetDate == null
          ? null
          : dateString(request.targetDate!),
      'currency_code': request.currencyCode,
    };

    final String piggyBankId;
    if (request.id == null) {
      final row = await _client
          .from('piggy_banks')
          .insert({...payload, 'created_by': request.profileId})
          .select('id')
          .single();
      piggyBankId = row['id'] as String;
    } else {
      final row = await _client
          .from('piggy_banks')
          .update(payload)
          .eq('household_id', request.householdId)
          .eq('id', request.id!)
          .select('id')
          .single();
      piggyBankId = row['id'] as String;
    }

    return _fetchPiggyBank(
      householdId: request.householdId,
      piggyBankId: piggyBankId,
    );
  }

  @override
  Future<List<PiggyBankEntry>> fetchPiggyBankEntries({
    required String householdId,
    required String piggyBankId,
  }) async {
    final rows = await _client
        .from('piggy_bank_entries')
        .select(
          'id, household_id, piggy_bank_id, entry_type, amount, entry_date, '
          'note, linked_transaction_id, created_by, created_at',
        )
        .eq('household_id', householdId)
        .eq('piggy_bank_id', piggyBankId)
        .order('entry_date', ascending: false)
        .order('created_at', ascending: false);

    return rows.map(PiggyBankEntry.fromJson).toList(growable: false);
  }

  @override
  Future<PiggyBankEntry> createPiggyBankEntry(
    PiggyBankEntryRequest request,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(
      'create_piggy_bank_entry',
      params: {
        'p_household_id': request.householdId,
        'p_piggy_bank_id': request.piggyBankId,
        'p_entry_type': request.entryType,
        'p_amount': request.amount,
        'p_entry_date': dateString(request.entryDate),
        'p_note': request.note,
        'p_linked_transaction_id': request.linkedTransactionId,
      },
    );

    if (rows.isEmpty) {
      throw StateError('Piggy-bank entry was not created.');
    }

    return PiggyBankEntry.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<PagedTransactions> fetchTransactions(TransactionQuery query) async {
    final results = await Future.wait<Object>([
      fetchCategories(householdId: query.householdId),
      fetchSubcategories(householdId: query.householdId),
      fetchMerchants(householdId: query.householdId),
    ]);
    final categories = results[0] as List<CategoryOption>;
    final subcategories = results[1] as List<SubcategoryOption>;
    final merchants = results[2] as List<MerchantOption>;
    final categoryNamesById = {
      for (final category in categories) category.id: category.name,
    };
    final subcategoryNamesById = {
      for (final subcategory in subcategories) subcategory.id: subcategory.name,
    };
    final merchantNamesById = {
      for (final merchant in merchants) merchant.id: merchant.displayName,
    };
    final sourceAccountIds = await _sourceAccountIdsForType(
      householdId: query.householdId,
      sourceAccountType: query.sourceAccountType,
    );

    if (query.sourceAccountType != null &&
        (sourceAccountIds.isEmpty ||
            (query.sourceAccountId != null &&
                !sourceAccountIds.contains(query.sourceAccountId)))) {
      return PagedTransactions(
        items: const [],
        page: query.page,
        pageSize: query.pageSize,
      );
    }

    var request = _client
        .from('transactions')
        .select(
          'id, transaction_date, statement_merchant, merchant_id, '
          'category_id, subcategory_id, source_account_id, transaction_type, '
          'amount, gross_spend, refund_amount, net_expense, currency_code, '
          'confidence, cardholder_name, notes',
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
    } else if (sourceAccountIds.isNotEmpty) {
      request = request.inFilter('source_account_id', sourceAccountIds);
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
              subcategoryNamesById: subcategoryNamesById,
              merchantNamesById: merchantNamesById,
            ),
          )
          .toList(growable: false),
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<TrendReport> fetchTrendReport(TrendQuery query) async {
    final results = await Future.wait<Object>([
      fetchCategories(householdId: query.householdId),
      fetchSubcategories(householdId: query.householdId),
      fetchMerchants(householdId: query.householdId),
      fetchSourceAccounts(householdId: query.householdId),
      _fetchTrendTransactions(query),
    ]);

    final categories = results[0] as List<CategoryOption>;
    final subcategories = results[1] as List<SubcategoryOption>;
    final merchants = results[2] as List<MerchantOption>;
    final sourceAccounts = results[3] as List<SourceAccountOption>;
    final rows = results[4] as List<Map<String, dynamic>>;
    final categoryNamesById = {
      for (final category in categories) category.id: category.name,
    };
    final subcategoryNamesById = {
      for (final subcategory in subcategories) subcategory.id: subcategory.name,
    };
    final merchantNamesById = {
      for (final merchant in merchants) merchant.id: merchant.displayName,
    };
    final sourceLabelsById = {
      for (final source in sourceAccounts) source.id: source.label,
    };

    return TrendReport.fromTransactions(
      rows
          .map(
            (row) => TrendReportTransaction.fromJson(
              row,
              categoryNamesById: categoryNamesById,
              subcategoryNamesById: subcategoryNamesById,
              merchantNamesById: merchantNamesById,
              sourceLabelsById: sourceLabelsById,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<TransactionMetadataCorrectionResult>
  applyTransactionMetadataCorrection(
    TransactionMetadataCorrectionRequest request,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(
      'apply_transaction_metadata_correction',
      params: {
        'p_household_id': request.householdId,
        'p_transaction_id': request.transactionId,
        'p_merchant_group': request.merchantGroup,
        'p_category_id': request.categoryId,
        'p_subcategory_id': request.subcategoryId,
        'p_confidence': request.confidence,
        'p_notes': request.notes,
        'p_review_item_id': request.reviewItemId,
      },
    );

    if (rows.isEmpty) {
      throw StateError('Correction did not return a result.');
    }

    return TransactionMetadataCorrectionResult.fromJson(
      rows.first as Map<String, dynamic>,
    );
  }

  @override
  Future<TransactionMetadataSuggestionResult> suggestTransactionMetadata(
    TransactionMetadataSuggestionRequest request,
  ) async {
    final response = await _client.functions.invoke(
      'transaction-metadata-suggest',
      body: {
        'household_id': request.householdId,
        'transaction_id': request.transactionId,
        if (request.reviewItemId != null)
          'review_item_id': request.reviewItemId,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final suggestion = data['suggestion'] as Map<String, dynamic>?;
    if (suggestion == null) {
      throw StateError(
        'Transaction metadata suggestion did not return a suggestion.',
      );
    }

    return TransactionMetadataSuggestionResult.fromJson(suggestion);
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

  Future<List<Map<String, dynamic>>> _fetchTrendTransactions(
    TrendQuery query,
  ) async {
    final sourceAccountIds = await _sourceAccountIdsForType(
      householdId: query.householdId,
      sourceAccountType: query.sourceAccountType,
    );

    if (query.sourceAccountType != null &&
        (sourceAccountIds.isEmpty ||
            (query.sourceAccountId != null &&
                !sourceAccountIds.contains(query.sourceAccountId)))) {
      return const [];
    }

    var request = _client
        .from('transactions')
        .select(
          'id, transaction_date, statement_merchant, '
          'normalized_statement_merchant, merchant_id, category_id, '
          'subcategory_id, source_account_id, transaction_type, amount, '
          'gross_spend, refund_amount, net_expense, currency_code, '
          'cardholder_name',
        )
        .eq('household_id', query.householdId);

    if (query.categoryId != null) {
      request = request.eq('category_id', query.categoryId!);
    }

    if (query.sourceAccountId != null) {
      request = request.eq('source_account_id', query.sourceAccountId!);
    } else if (sourceAccountIds.isNotEmpty) {
      request = request.inFilter('source_account_id', sourceAccountIds);
    }

    if (query.startDate != null) {
      request = request.gte('transaction_date', dateString(query.startDate!));
    }

    if (query.endDate != null) {
      request = request.lte('transaction_date', dateString(query.endDate!));
    }

    final rows = await request
        .order('transaction_date')
        .order('created_at')
        .limit(5000);

    return rows.cast<Map<String, dynamic>>();
  }

  Future<List<String>> _sourceAccountIdsForType({
    required String householdId,
    required String? sourceAccountType,
  }) async {
    if (sourceAccountType == null) return const [];

    final sourceAccounts = await fetchSourceAccounts(householdId: householdId);
    return sourceAccounts
        .where((source) => source.type == sourceAccountType)
        .map((source) => source.id)
        .toList(growable: false);
  }

  Future<int> _fetchOpenReviewCount({required String householdId}) async {
    final rows = await _client
        .from('v_review_queue')
        .select('id')
        .eq('household_id', householdId);

    return rows.length;
  }

  Future<PiggyBankSummary> _fetchPiggyBank({
    required String householdId,
    required String piggyBankId,
  }) async {
    final row = await _client
        .from('v_piggy_bank_balances')
        .select(
          'id, household_id, name, description, target_amount, target_date, '
          'currency_code, is_archived, created_by, created_at, updated_at, '
          'balance_amount, target_progress',
        )
        .eq('household_id', householdId)
        .eq('id', piggyBankId)
        .single();

    return PiggyBankSummary.fromJson(row);
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
  Future<List<SubcategoryOption>> fetchSubcategories({
    required String householdId,
  }) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<CategoryCreationResult> createCategory(
    CategoryCreationRequest request,
  ) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<List<MerchantOption>> fetchMerchants({required String householdId}) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<List<MerchantReviewItem>> fetchMerchantReviewQueue({
    required String householdId,
  }) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<List<GmailConnectorStatus>> fetchGmailConnectorStatus({
    required String householdId,
  }) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<AiBudgetStatus> fetchAiBudgetStatus({required String householdId}) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<ExpenseQuestionAnswer> askExpenseQuestion(
    ExpenseQuestionRequest request,
  ) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<List<MerchantResearchSuggestion>> fetchMerchantResearchSuggestions({
    required String householdId,
  }) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<MerchantResearchSuggestion> researchMerchant(
    MerchantResearchRequest request,
  ) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<String> startGmailConnector({required String householdId}) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<void> disconnectGmailMailbox({required String mailboxId}) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<List<PiggyBankSummary>> fetchPiggyBanks({
    required String householdId,
  }) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<PiggyBankSummary> savePiggyBank(PiggyBankSaveRequest request) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<List<PiggyBankEntry>> fetchPiggyBankEntries({
    required String householdId,
    required String piggyBankId,
  }) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<PiggyBankEntry> createPiggyBankEntry(PiggyBankEntryRequest request) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<PagedTransactions> fetchTransactions(TransactionQuery query) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<TrendReport> fetchTrendReport(TrendQuery query) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<TransactionMetadataCorrectionResult>
  applyTransactionMetadataCorrection(
    TransactionMetadataCorrectionRequest request,
  ) {
    throw const SupabaseNotConfiguredException();
  }

  @override
  Future<TransactionMetadataSuggestionResult> suggestTransactionMetadata(
    TransactionMetadataSuggestionRequest request,
  ) {
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

final class _MonthlyTrendAccumulator {
  _MonthlyTrendAccumulator(this.periodMonth);

  final DateTime periodMonth;
  int transactionCount = 0;
  double grossSpend = 0;
  double refundAmount = 0;
  double netSpend = 0;
  double billPayments = 0;

  void add(TrendReportTransaction transaction) {
    transactionCount += 1;
    grossSpend += transaction.grossSpend;
    refundAmount += transaction.refundAmount;
    netSpend += transaction.netExpense;
    if (transaction.isBillPayment) {
      billPayments += transaction.amount.abs();
    }
  }

  MonthlySpend toMonthlySpend() {
    return MonthlySpend(
      periodMonth: periodMonth,
      transactionCount: transactionCount,
      grossSpend: grossSpend,
      refundAmount: refundAmount,
      netSpend: netSpend,
      billPayments: billPayments,
    );
  }
}

final class _CategoryTrendAccumulator {
  _CategoryTrendAccumulator({
    required this.categoryId,
    required this.categoryName,
  });

  final String categoryId;
  final String categoryName;
  int transactionCount = 0;
  double grossSpend = 0;
  double refundAmount = 0;
  double netSpend = 0;
  final monthTotals = <String, _CategoryTrendMonthAccumulator>{};

  void add(TrendReportTransaction transaction, DateTime month) {
    transactionCount += 1;
    grossSpend += transaction.grossSpend;
    refundAmount += transaction.refundAmount;
    netSpend += transaction.netExpense;
    monthTotals
        .putIfAbsent(
          dateString(month),
          () => _CategoryTrendMonthAccumulator(month),
        )
        .add(transaction);
  }

  CategoryTrend toCategoryTrend(List<String> monthKeys) {
    return CategoryTrend(
      categoryId: categoryId,
      categoryName: categoryName,
      transactionCount: transactionCount,
      grossSpend: grossSpend,
      refundAmount: refundAmount,
      netSpend: netSpend,
      months: [
        for (final monthKey in monthKeys)
          monthTotals[monthKey]?.toCategoryTrendMonth() ??
              CategoryTrendMonth(
                periodMonth: _parseDate(monthKey),
                transactionCount: 0,
                grossSpend: 0,
                refundAmount: 0,
                netSpend: 0,
              ),
      ],
    );
  }
}

final class _CategoryTrendMonthAccumulator {
  _CategoryTrendMonthAccumulator(this.periodMonth);

  final DateTime periodMonth;
  int transactionCount = 0;
  double grossSpend = 0;
  double refundAmount = 0;
  double netSpend = 0;

  void add(TrendReportTransaction transaction) {
    transactionCount += 1;
    grossSpend += transaction.grossSpend;
    refundAmount += transaction.refundAmount;
    netSpend += transaction.netExpense;
  }

  CategoryTrendMonth toCategoryTrendMonth() {
    return CategoryTrendMonth(
      periodMonth: periodMonth,
      transactionCount: transactionCount,
      grossSpend: grossSpend,
      refundAmount: refundAmount,
      netSpend: netSpend,
    );
  }
}

final class _MerchantSummaryAccumulator {
  _MerchantSummaryAccumulator({
    required this.merchantGroup,
    required this.categoryName,
    required this.subcategoryName,
  });

  final String merchantGroup;
  final String? categoryName;
  final String? subcategoryName;
  int transactionCount = 0;
  double grossSpend = 0;
  double refundAmount = 0;
  double netSpend = 0;

  void add(TrendReportTransaction transaction) {
    transactionCount += 1;
    grossSpend += transaction.grossSpend;
    refundAmount += transaction.refundAmount;
    netSpend += transaction.netExpense;
  }

  MerchantSummary toMerchantSummary() {
    return MerchantSummary(
      merchantGroup: merchantGroup,
      categoryName: categoryName,
      subcategoryName: subcategoryName,
      transactionCount: transactionCount,
      grossSpend: grossSpend,
      refundAmount: refundAmount,
      netSpend: netSpend,
    );
  }
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

DateTime? parseOptionalDateTime(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : DateTime.parse(text);
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

String _csvRow(List<Object?> cells) {
  return cells.map(_csvCell).join(',');
}

String _csvCell(Object? value) {
  final text = value?.toString() ?? '';
  final needsQuotes =
      text.contains(',') || text.contains('"') || text.contains('\n');
  if (!needsQuotes) return text;

  return '"${text.replaceAll('"', '""')}"';
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;

    return null;
  }
}
