import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendlens/src/core/bootstrap/app_bootstrap.dart';
import 'package:spendlens/src/data/repositories/finance_repository.dart';
import 'package:spendlens/src/data/repositories/household_repository.dart';
import 'package:spendlens/src/features/dashboard/dashboard_screen.dart';
import 'package:spendlens/src/features/merchant_review/merchant_review_screen.dart';
import 'package:spendlens/src/features/piggy_banks/piggy_banks_screen.dart';
import 'package:spendlens/src/features/transactions/transactions_screen.dart';
import 'package:spendlens/src/features/trends/trends_screen.dart';

void main() {
  test('trend report aggregates monthly category and merchant totals', () {
    final report = TrendReport.fromTransactions([
      _trendTransaction(
        id: 'trend-1',
        transactionDate: DateTime(2026, 1, 5),
        statementMerchant: 'SWIGGY BANGALORE',
        merchantGroup: 'Swiggy/Zomato/Food delivery',
        categoryId: 'cat-food',
        categoryName: 'Food & Dining',
        subcategoryId: 'sub-delivery',
        subcategoryName: 'Delivery',
        grossSpend: 1000,
        netExpense: 1000,
      ),
      _trendTransaction(
        id: 'trend-2',
        transactionDate: DateTime(2026, 1, 14),
        statementMerchant: 'ZOMATO REFUND',
        merchantGroup: 'Swiggy/Zomato/Food delivery',
        categoryId: 'cat-food',
        categoryName: 'Food & Dining',
        subcategoryId: 'sub-delivery',
        subcategoryName: 'Delivery',
        transactionType: 'refund_reversal',
        amount: -100,
        refundAmount: 100,
        netExpense: -100,
      ),
      _trendTransaction(
        id: 'trend-3',
        transactionDate: DateTime(2026, 1, 25),
        statementMerchant: 'TELE TRANSFER CREDIT',
        merchantGroup: 'tele transfer credit',
        transactionType: 'bill_payment_credit',
        amount: -5000,
      ),
      _trendTransaction(
        id: 'trend-4',
        transactionDate: DateTime(2026, 2, 3),
        statementMerchant: 'HDFC SMARTBUY FLIGHT',
        merchantGroup: 'HDFC SmartBuy, Flights',
        categoryId: 'cat-travel',
        categoryName: 'Travel & Visa',
        subcategoryId: 'sub-flights',
        subcategoryName: 'Flights',
        grossSpend: 300,
        netExpense: 300,
      ),
    ]);

    expect(report.monthlySpend, hasLength(2));
    expect(report.monthlySpend.first.transactionCount, 3);
    expect(report.monthlySpend.first.grossSpend, 1000);
    expect(report.monthlySpend.first.refundAmount, 100);
    expect(report.monthlySpend.first.netSpend, 900);
    expect(report.monthlySpend.first.billPayments, 5000);

    expect(report.categoryTrends.first.categoryName, 'Food & Dining');
    expect(report.categoryTrends.first.transactionCount, 2);
    expect(report.categoryTrends.first.netSpend, 900);
    expect(report.categoryTrends.first.months.first.netSpend, 900);
    expect(report.categoryTrends.first.months.last.netSpend, 0);

    expect(
      report.merchantSummaries.first.merchantGroup,
      'Swiggy/Zomato/Food delivery',
    );
    expect(report.merchantSummaries.first.transactionCount, 2);
    expect(report.merchantSummaries.first.refundAmount, 100);
    expect(
      report.merchantSummaries.any(
        (merchant) => merchant.merchantGroup == 'tele transfer credit',
      ),
      isFalse,
    );

    final csv = report.toTransactionsCsv();
    expect(csv, contains('Date,Cardholder,Source,Statement merchant'));
    expect(csv, contains('"HDFC SmartBuy, Flights"'));
  });

  testWidgets('dashboard shows net spend and saves category caps', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const DashboardScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mar 2026 net'), findsOneWidget);
    expect(find.text('INR 42,000'), findsWidgets);
    expect(find.text('+INR 2,000'), findsOneWidget);
    expect(find.text('Food'), findsWidgets);
    expect(find.text('Fuel'), findsOneWidget);

    await tester.ensureVisible(find.text('Fuel'));
    await tester.tap(find.text('Fuel'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '5000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedCaps, hasLength(1));
    expect(repository.savedCaps.single.categoryId, 'cat-fuel');
    expect(repository.savedCaps.single.capAmount, 5000);
  });

  testWidgets('transactions search and category filters refresh query', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(
        repository: repository,
        child: const TransactionsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Swiggy Instamart'), findsOneWidget);
    expect(find.text('Amazon Pay'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'swiggy');
    await tester.pumpAndSettle();

    expect(repository.lastQuery?.searchText, 'swiggy');
    expect(find.text('Swiggy Instamart'), findsOneWidget);
    expect(find.text('Amazon Pay'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();

    expect(repository.lastQuery?.categoryId, 'cat-food');
  });

  testWidgets('trends render reports and refresh shared filters', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const TrendsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Monthly Net Spend'), findsOneWidget);
    expect(find.text('Gross, Refunds, Net'), findsOneWidget);
    expect(find.text('Category Trend'), findsOneWidget);
    expect(find.text('Merchant Summary'), findsOneWidget);
    expect(find.text('Swiggy Instamart'), findsWidgets);
    expect(repository.lastTrendQuery?.categoryId, isNull);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();

    expect(repository.lastTrendQuery?.categoryId, 'cat-food');
    expect(find.text('Amazon Pay'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('HDFC Credit Card - Ada').last);
    await tester.pumpAndSettle();

    expect(repository.lastTrendQuery?.sourceAccountId, 'source-1');
    final copyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Copy CSV'),
    );
    expect(copyButton.onPressed, isNotNull);
  });

  testWidgets('merchant review resolves an open item', (tester) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(
        repository: repository,
        child: const MerchantReviewScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AMZN MKTP IN'), findsOneWidget);
    expect(find.textContaining('Unknown marketplace merchant'), findsOneWidget);

    await tester.tap(find.text('Resolve'));
    await tester.pumpAndSettle();

    expect(find.text('Resolve merchant'), findsOneWidget);
    expect(find.text('Merchant group'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Subcategory'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Amazon Shopping');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.corrections, hasLength(1));
    expect(repository.corrections.single.merchantGroup, 'Amazon Shopping');
    expect(repository.corrections.single.categoryId, 'cat-shopping');
    expect(repository.corrections.single.subcategoryId, 'sub-marketplace');
    expect(find.text('No review items'), findsOneWidget);
    expect(find.text('Resolved 1 review items'), findsOneWidget);
  });

  testWidgets('piggy banks create entries and update target progress', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const PiggyBanksScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('No piggy banks'), findsOneWidget);

    await tester.tap(find.text('Create piggy bank'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Vacation');
    await tester.enterText(find.byType(TextFormField).at(1), 'Flights');
    await tester.enterText(find.byType(TextFormField).at(2), '1000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.piggyBanks, hasLength(1));
    expect(find.text('Vacation'), findsWidgets);
    expect(find.text('Target INR 1,000'), findsWidgets);

    await tester.ensureVisible(find.text('Deposit').first);
    await tester.tap(find.text('Deposit').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '400');
    await tester.enterText(find.byType(TextFormField).last, 'Initial deposit');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.piggyEntries, hasLength(1));
    expect(repository.currentPiggyBalance('piggy-1'), 400);
    expect(find.text('INR 400'), findsWidgets);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('+INR 400'), findsOneWidget);

    await tester.ensureVisible(find.text('Withdraw').first);
    await tester.tap(find.text('Withdraw').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '125');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.piggyEntries, hasLength(2));
    expect(repository.currentPiggyBalance('piggy-1'), 275);
    expect(find.text('INR 275'), findsWidgets);
    expect(find.text('28%'), findsOneWidget);
    expect(find.text('-INR 125'), findsOneWidget);
  });
}

Widget _financeTestApp({
  required _FakeFinanceRepository repository,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      appBootstrapProvider.overrideWithValue(
        const AppBootstrap(supabaseStatus: SupabaseStatus.ready),
      ),
      householdContextProvider.overrideWithValue(AsyncData(_householdContext)),
      financeRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

const _householdContext = HouseholdContext(
  profile: AppProfile(
    id: 'profile-1',
    authUserId: 'auth-1',
    displayName: 'Ada',
    email: 'ada@example.com',
  ),
  household: Household(
    id: 'household-1',
    name: 'Ada Household',
    currencyCode: 'INR',
  ),
  memberRole: 'owner',
);

final class _SavedCap {
  const _SavedCap({required this.categoryId, required this.capAmount});

  final String categoryId;
  final double capAmount;
}

final class _FakeFinanceRepository implements FinanceRepository {
  final savedCaps = <_SavedCap>[];
  final corrections = <MerchantCorrectionRequest>[];
  final piggyBanks = <PiggyBankSummary>[];
  final piggyEntries = <PiggyBankEntry>[];
  TransactionQuery? lastQuery;
  TrendQuery? lastTrendQuery;

  final categories = const [
    CategoryOption(id: 'cat-food', name: 'Food'),
    CategoryOption(id: 'cat-fuel', name: 'Fuel'),
    CategoryOption(id: 'cat-shopping', name: 'Shopping'),
  ];

  final subcategories = const [
    SubcategoryOption(
      id: 'sub-food-delivery',
      categoryId: 'cat-food',
      name: 'Delivery',
    ),
    SubcategoryOption(
      id: 'sub-marketplace',
      categoryId: 'cat-shopping',
      name: 'Marketplace',
    ),
  ];

  final transactions = [
    FinanceTransaction(
      id: 'txn-1',
      transactionDate: DateTime(2026, 3, 12),
      statementMerchant: 'Swiggy Instamart',
      categoryId: 'cat-food',
      categoryName: 'Food',
      sourceAccountId: 'source-1',
      transactionType: 'debit_spend',
      amount: 1200,
      grossSpend: 1200,
      refundAmount: 0,
      netExpense: 1200,
      currencyCode: 'INR',
      confidence: 'high',
      cardholderName: 'Ada',
    ),
    FinanceTransaction(
      id: 'txn-2',
      transactionDate: DateTime(2026, 3, 8),
      statementMerchant: 'Amazon Pay',
      categoryId: 'cat-fuel',
      categoryName: 'Fuel',
      sourceAccountId: 'source-1',
      transactionType: 'refund_reversal',
      amount: -500,
      grossSpend: 0,
      refundAmount: 500,
      netExpense: -500,
      currencyCode: 'INR',
      confidence: 'medium',
      cardholderName: 'Ada',
    ),
  ];

  final trendTransactions = [
    _trendTransaction(
      id: 'trend-fake-1',
      transactionDate: DateTime(2026, 3, 12),
      statementMerchant: 'Swiggy Instamart',
      merchantGroup: 'Swiggy Instamart',
      categoryId: 'cat-food',
      categoryName: 'Food',
      subcategoryId: 'sub-food-delivery',
      subcategoryName: 'Delivery',
      sourceAccountId: 'source-1',
      sourceLabel: 'HDFC Credit Card - Ada',
      grossSpend: 1200,
      netExpense: 1200,
    ),
    _trendTransaction(
      id: 'trend-fake-2',
      transactionDate: DateTime(2026, 3, 8),
      statementMerchant: 'Amazon Pay',
      merchantGroup: 'Amazon Shopping',
      categoryId: 'cat-shopping',
      categoryName: 'Shopping',
      subcategoryId: 'sub-marketplace',
      subcategoryName: 'Marketplace',
      sourceAccountId: 'source-2',
      sourceLabel: 'ICICI Credit Card - Ada',
      grossSpend: 2400,
      netExpense: 2400,
    ),
  ];

  final reviewItems = [
    MerchantReviewItem(
      id: 'review-1',
      householdId: 'household-1',
      transactionId: 'txn-review-1',
      reason: 'Unknown marketplace merchant',
      createdAt: DateTime(2026, 3, 12, 9),
      transactionDate: DateTime(2026, 3, 12),
      statementMerchant: 'AMZN MKTP IN',
      amount: 2499,
      netExpense: 2499,
      confidence: 'low',
      currentMerchantName: 'Unknown Amazon',
      currentCategoryId: 'cat-shopping',
      currentCategoryName: 'Shopping',
      currentSubcategoryId: 'sub-marketplace',
      currentSubcategoryName: 'Marketplace',
    ),
  ];

  @override
  Future<DashboardSnapshot> fetchDashboardSnapshot({
    required String householdId,
    DateTime? requestedMonth,
  }) async {
    return DashboardSnapshot(
      availableMonths: [DateTime(2026, 3), DateTime(2026, 2)],
      selectedMonth: DateTime(2026, 3),
      monthlySpend: MonthlySpend(
        periodMonth: DateTime(2026, 3),
        transactionCount: 8,
        grossSpend: 43000,
        refundAmount: 1000,
        netSpend: 42000,
        billPayments: 12000,
      ),
      previousMonthSpend: MonthlySpend(
        periodMonth: DateTime(2026, 2),
        transactionCount: 7,
        grossSpend: 40000,
        refundAmount: 0,
        netSpend: 40000,
        billPayments: 8000,
      ),
      reviewQueueCount: 3,
      budgetProgress: const [
        BudgetProgress(
          categoryId: 'cat-food',
          categoryName: 'Food',
          capAmount: 50000,
          spentAmount: 42000,
          remainingAmount: 8000,
          percentUsed: 0.84,
          isOverBudget: false,
        ),
      ],
      uncappedCategories: const [CategoryOption(id: 'cat-fuel', name: 'Fuel')],
      topCategories: const [
        CategorySpend(
          categoryId: 'cat-food',
          categoryName: 'Food',
          transactionCount: 8,
          netSpend: 42000,
          refundAmount: 1000,
        ),
      ],
      topMerchants: const [
        MerchantSpend(
          merchantName: 'Swiggy Instamart',
          transactionCount: 4,
          netSpend: 18000,
          refundAmount: 0,
        ),
      ],
    );
  }

  @override
  Future<List<CategoryOption>> fetchCategories({
    required String householdId,
  }) async {
    return categories;
  }

  @override
  Future<List<SourceAccountOption>> fetchSourceAccounts({
    required String householdId,
  }) async {
    return const [
      SourceAccountOption(
        id: 'source-1',
        displayName: 'HDFC Credit Card',
        cardholderName: 'Ada',
      ),
    ];
  }

  @override
  Future<List<SubcategoryOption>> fetchSubcategories({
    required String householdId,
  }) async {
    return subcategories;
  }

  @override
  Future<List<MerchantOption>> fetchMerchants({
    required String householdId,
  }) async {
    return const [
      MerchantOption(id: 'merchant-amazon', displayName: 'Amazon Shopping'),
      MerchantOption(id: 'merchant-swiggy', displayName: 'Swiggy Instamart'),
    ];
  }

  @override
  Future<List<MerchantReviewItem>> fetchMerchantReviewQueue({
    required String householdId,
  }) async {
    return reviewItems;
  }

  @override
  Future<List<PiggyBankSummary>> fetchPiggyBanks({
    required String householdId,
  }) async {
    return piggyBanks
        .where((piggyBank) => piggyBank.householdId == householdId)
        .map(_summaryWithCurrentBalance)
        .toList();
  }

  @override
  Future<PiggyBankSummary> savePiggyBank(PiggyBankSaveRequest request) async {
    final now = DateTime(2026, 3, 20, 12);
    final id = request.id ?? 'piggy-${piggyBanks.length + 1}';
    final existing = piggyBanks
        .where((piggyBank) => piggyBank.id == id)
        .firstOrNull;
    final summary = PiggyBankSummary(
      id: id,
      householdId: request.householdId,
      name: request.name,
      description: request.description,
      targetAmount: request.targetAmount,
      targetDate: request.targetDate,
      currencyCode: request.currencyCode,
      isArchived: false,
      createdBy: request.profileId,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      balanceAmount: currentPiggyBalance(id),
      targetProgress: _targetProgress(
        balance: currentPiggyBalance(id),
        targetAmount: request.targetAmount,
      ),
    );

    if (existing == null) {
      piggyBanks.add(summary);
    } else {
      final index = piggyBanks.indexWhere((piggyBank) => piggyBank.id == id);
      piggyBanks[index] = summary;
    }

    return summary;
  }

  @override
  Future<List<PiggyBankEntry>> fetchPiggyBankEntries({
    required String householdId,
    required String piggyBankId,
  }) async {
    return piggyEntries
        .where(
          (entry) =>
              entry.householdId == householdId &&
              entry.piggyBankId == piggyBankId,
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<PiggyBankEntry> createPiggyBankEntry(
    PiggyBankEntryRequest request,
  ) async {
    if (request.entryType != 'adjustment' && request.amount <= 0) {
      throw StateError('Amount must be positive');
    }

    if (request.entryType == 'adjustment' && request.amount == 0) {
      throw StateError('Adjustment amount cannot be zero');
    }

    if (request.entryType == 'withdrawal' &&
        request.amount > currentPiggyBalance(request.piggyBankId)) {
      throw StateError('Withdrawal cannot exceed current balance');
    }

    final entry = PiggyBankEntry(
      id: 'entry-${piggyEntries.length + 1}',
      householdId: request.householdId,
      piggyBankId: request.piggyBankId,
      entryType: request.entryType,
      amount: request.amount,
      entryDate: request.entryDate,
      note: request.note,
      linkedTransactionId: request.linkedTransactionId,
      createdBy: _householdContext.profile.id,
      createdAt: DateTime(2026, 3, 20, 12, piggyEntries.length),
    );
    piggyEntries.add(entry);

    return entry;
  }

  double currentPiggyBalance(String piggyBankId) {
    return piggyEntries
        .where((entry) => entry.piggyBankId == piggyBankId)
        .fold<double>(0, (total, entry) => total + entry.signedAmount);
  }

  @override
  Future<PagedTransactions> fetchTransactions(TransactionQuery query) async {
    lastQuery = query;
    final search = query.searchText.trim().toLowerCase();
    final filtered = transactions.where((transaction) {
      final matchesSearch =
          search.isEmpty ||
          transaction.statementMerchant.toLowerCase().contains(search);
      final matchesCategory =
          query.categoryId == null ||
          transaction.categoryId == query.categoryId;

      return matchesSearch && matchesCategory;
    }).toList();

    return PagedTransactions(
      items: filtered,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<TrendReport> fetchTrendReport(TrendQuery query) async {
    lastTrendQuery = query;
    final filtered = trendTransactions.where((transaction) {
      final matchesCategory =
          query.categoryId == null ||
          transaction.categoryId == query.categoryId;
      final matchesSource =
          query.sourceAccountId == null ||
          transaction.sourceAccountId == query.sourceAccountId;
      final matchesStart =
          query.startDate == null ||
          !transaction.transactionDate.isBefore(query.startDate!);
      final matchesEnd =
          query.endDate == null ||
          !transaction.transactionDate.isAfter(query.endDate!);

      return matchesCategory && matchesSource && matchesStart && matchesEnd;
    }).toList();

    return TrendReport.fromTransactions(filtered);
  }

  @override
  Future<MerchantCorrectionResult> applyMerchantReviewCorrection(
    MerchantCorrectionRequest request,
  ) async {
    corrections.add(request);
    reviewItems.removeWhere((item) => item.id == request.reviewItemId);

    return const MerchantCorrectionResult(
      ruleId: 'rule-1',
      merchantId: 'merchant-amazon',
      updatedTransactionCount: 1,
      resolvedReviewItemCount: 1,
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
    savedCaps.add(_SavedCap(categoryId: categoryId, capAmount: capAmount));
  }

  PiggyBankSummary _summaryWithCurrentBalance(PiggyBankSummary piggyBank) {
    final balance = currentPiggyBalance(piggyBank.id);

    return PiggyBankSummary(
      id: piggyBank.id,
      householdId: piggyBank.householdId,
      name: piggyBank.name,
      description: piggyBank.description,
      targetAmount: piggyBank.targetAmount,
      targetDate: piggyBank.targetDate,
      currencyCode: piggyBank.currencyCode,
      isArchived: piggyBank.isArchived,
      createdBy: piggyBank.createdBy,
      createdAt: piggyBank.createdAt,
      updatedAt: piggyBank.updatedAt,
      balanceAmount: balance,
      targetProgress: _targetProgress(
        balance: balance,
        targetAmount: piggyBank.targetAmount,
      ),
    );
  }

  double? _targetProgress({
    required double balance,
    required double? targetAmount,
  }) {
    if (targetAmount == null || targetAmount <= 0) return null;

    return double.parse((balance / targetAmount).toStringAsFixed(4));
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;

    return null;
  }
}

TrendReportTransaction _trendTransaction({
  required String id,
  required DateTime transactionDate,
  required String statementMerchant,
  required String merchantGroup,
  String? merchantId,
  String? categoryId,
  String? categoryName,
  String? subcategoryId,
  String? subcategoryName,
  String? sourceAccountId,
  String? sourceLabel,
  String transactionType = 'debit_spend',
  double amount = 0,
  double grossSpend = 0,
  double refundAmount = 0,
  double netExpense = 0,
  String currencyCode = 'INR',
  String? cardholderName = 'Ada',
}) {
  return TrendReportTransaction(
    id: id,
    transactionDate: transactionDate,
    statementMerchant: statementMerchant,
    merchantGroup: merchantGroup,
    merchantId: merchantId,
    categoryId: categoryId,
    categoryName: categoryName,
    subcategoryId: subcategoryId,
    subcategoryName: subcategoryName,
    sourceAccountId: sourceAccountId,
    sourceLabel: sourceLabel,
    transactionType: transactionType,
    amount: amount == 0 && grossSpend != 0 ? grossSpend : amount,
    grossSpend: grossSpend,
    refundAmount: refundAmount,
    netExpense: netExpense,
    currencyCode: currencyCode,
    cardholderName: cardholderName,
  );
}
