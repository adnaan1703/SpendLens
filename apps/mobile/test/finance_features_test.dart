import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendlens/src/core/bootstrap/app_bootstrap.dart';
import 'package:spendlens/src/data/repositories/finance_repository.dart';
import 'package:spendlens/src/data/repositories/household_repository.dart';
import 'package:spendlens/src/features/dashboard/dashboard_screen.dart';
import 'package:spendlens/src/features/transactions/transactions_screen.dart';

void main() {
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
  TransactionQuery? lastQuery;

  final categories = const [
    CategoryOption(id: 'cat-food', name: 'Food'),
    CategoryOption(id: 'cat-fuel', name: 'Fuel'),
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
  Future<void> saveCategoryCap({
    required String householdId,
    required String profileId,
    required String categoryId,
    required DateTime periodMonth,
    required double capAmount,
  }) async {
    savedCaps.add(_SavedCap(categoryId: categoryId, capAmount: capAmount));
  }
}
