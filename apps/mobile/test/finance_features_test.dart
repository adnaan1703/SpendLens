import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spendlens/src/core/bootstrap/app_bootstrap.dart';
import 'package:spendlens/src/data/repositories/finance_repository.dart';
import 'package:spendlens/src/data/repositories/household_repository.dart';
import 'package:spendlens/src/features/ai/ai_screen.dart';
import 'package:spendlens/src/features/dashboard/dashboard_screen.dart';
import 'package:spendlens/src/features/merchant_review/merchant_review_screen.dart';
import 'package:spendlens/src/features/piggy_banks/piggy_banks_screen.dart';
import 'package:spendlens/src/features/settings/settings_screen.dart';
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

  testWidgets('dashboard top category drills into monthly transactions', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();
    final router = _financeTestRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _financeRouterTestApp(repository: repository, router: router),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(InkWell, 'Food'));
    await tester.tap(find.widgetWithText(InkWell, 'Food'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/transactions');
    expect(repository.lastQuery?.categoryId, 'cat-food');
    expect(repository.lastQuery?.searchText, '');
    expect(dateString(repository.lastQuery!.startDate!), '2026-03-01');
    expect(dateString(repository.lastQuery!.endDate!), '2026-03-31');
    expect(repository.lastQuery?.page, 0);
  });

  testWidgets('dashboard top merchant drills into monthly transactions', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();
    final router = _financeTestRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _financeRouterTestApp(repository: repository, router: router),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.widgetWithText(InkWell, 'Swiggy Instamart'),
    );
    await tester.tap(find.widgetWithText(InkWell, 'Swiggy Instamart'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/transactions');
    expect(repository.lastQuery?.categoryId, isNull);
    expect(repository.lastQuery?.searchText, 'Swiggy Instamart');
    expect(dateString(repository.lastQuery!.startDate!), '2026-03-01');
    expect(dateString(repository.lastQuery!.endDate!), '2026-03-31');
    expect(repository.lastQuery?.page, 0);
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
    expect(find.text('Amazon Shopping'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'swiggy');
    await tester.pumpAndSettle();

    expect(repository.lastQuery?.searchText, 'swiggy');
    expect(find.text('Swiggy Instamart'), findsOneWidget);
    expect(find.text('Amazon Shopping'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();

    expect(repository.lastQuery?.categoryId, 'cat-food');
  });

  testWidgets('transaction route filters prepopulate controls and query', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();
    final router = _financeTestRouter(
      initialLocation:
          '/transactions?categoryId=cat-food&merchant=Swiggy%20Instamart'
          '&startDate=2026-03-01&endDate=2026-03-31',
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _financeRouterTestApp(repository: repository, router: router),
    );
    await tester.pumpAndSettle();

    final merchantSearch = tester.widget<TextField>(find.byType(TextField));
    expect(merchantSearch.controller?.text, 'Swiggy Instamart');
    expect(find.text('Food'), findsWidgets);
    expect(find.text('2026-03-01 to 2026-03-31'), findsOneWidget);
    expect(repository.lastQuery?.categoryId, 'cat-food');
    expect(repository.lastQuery?.searchText, 'Swiggy Instamart');
    expect(dateString(repository.lastQuery!.startDate!), '2026-03-01');
    expect(dateString(repository.lastQuery!.endDate!), '2026-03-31');
    expect(repository.lastQuery?.page, 0);
  });

  testWidgets('clearing transaction route filters resets query and URL', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository()..addSwiggyTransactions(24);
    final router = _financeTestRouter(
      initialLocation:
          '/transactions?categoryId=cat-food&merchant=Swiggy%20Instamart'
          '&startDate=2026-03-01&endDate=2026-03-31',
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _financeRouterTestApp(repository: repository, router: router),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Next page'));
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();

    expect(repository.lastQuery?.page, 1);

    await tester.ensureVisible(find.byTooltip('Clear filters'));
    await tester.tap(find.byTooltip('Clear filters'));
    await tester.pumpAndSettle();

    final merchantSearch = tester.widget<TextField>(find.byType(TextField));
    expect(merchantSearch.controller?.text, '');
    expect(find.text('Date range'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.queryParameters, isEmpty);
    expect(repository.lastQuery?.categoryId, isNull);
    expect(repository.lastQuery?.searchText, '');
    expect(repository.lastQuery?.startDate, isNull);
    expect(repository.lastQuery?.endDate, isNull);
    expect(repository.lastQuery?.page, 0);
  });

  testWidgets('transactions source type filter separates UPI from cards', (
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

    expect(find.text('CRED Club'), findsOneWidget);
    expect(find.text('Swiggy Instamart'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UPI').last);
    await tester.pumpAndSettle();

    expect(repository.lastQuery?.sourceAccountType, 'upi');
    expect(find.text('CRED Club'), findsOneWidget);
    expect(find.text('Swiggy Instamart'), findsNothing);
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

  testWidgets('trends source type filter separates UPI reporting', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const TrendsScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UPI').last);
    await tester.pumpAndSettle();

    expect(repository.lastTrendQuery?.sourceAccountType, 'upi');
    expect(find.text('CRED Club'), findsWidgets);
    expect(find.text('Swiggy Instamart'), findsNothing);
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

    expect(find.text('Edit metadata'), findsOneWidget);
    expect(find.text('Merchant group'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Subcategory'), findsOneWidget);
    expect(find.text('Confidence'), findsOneWidget);

    await tester.tap(find.text('Suggest'));
    await tester.pumpAndSettle();

    expect(repository.metadataSuggestionRequests, hasLength(1));
    expect(
      repository.metadataSuggestionRequests.single.transactionId,
      'txn-review-1',
    );
    expect(
      repository.metadataSuggestionRequests.single.reviewItemId,
      'review-1',
    );
    expect(find.text('Amazon Shopping'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.corrections, hasLength(1));
    expect(repository.corrections.single.transactionId, 'txn-review-1');
    expect(repository.corrections.single.reviewItemId, 'review-1');
    expect(repository.corrections.single.merchantGroup, 'Amazon Shopping');
    expect(repository.corrections.single.categoryId, 'cat-shopping');
    expect(repository.corrections.single.subcategoryId, 'sub-marketplace');
    expect(repository.corrections.single.confidence, 'medium');
    expect(repository.corrections.single.notes, 'Suggested marketplace spend.');
    expect(find.text('No review items'), findsOneWidget);
    expect(find.text('Resolved 1 review items'), findsOneWidget);
  });

  testWidgets('merchant review creates and selects a category inline', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(
        repository: repository,
        child: const MerchantReviewScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Resolve'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create category'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.ancestor(
        of: find.text('Category name'),
        matching: find.byType(TextFormField),
      ),
      'Travel',
    );
    await tester.enterText(
      find.ancestor(
        of: find.text('Subcategory name'),
        matching: find.byType(TextFormField),
      ),
      'Flights',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Travel Desk');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.createdCategoryRequests, hasLength(1));
    expect(repository.createdCategoryRequests.single.categoryName, 'Travel');
    expect(
      repository.createdCategoryRequests.single.subcategoryName,
      'Flights',
    );
    expect(repository.corrections, hasLength(1));
    expect(repository.corrections.single.categoryId, 'cat-created-1');
    expect(repository.corrections.single.subcategoryId, 'sub-created-1');
  });

  testWidgets('transaction detail opens metadata editor', (tester) async {
    final repository = _FakeFinanceRepository();
    repository.nextMetadataSuggestion =
        const TransactionMetadataSuggestionResult(
          merchantGroup: 'Swiggy Grocery',
          categoryId: 'cat-food',
          subcategoryId: 'sub-food-delivery',
          confidence: 'medium',
          notes: 'Suggested grocery delivery spend.',
        );

    await tester.pumpWidget(
      _financeTestApp(
        repository: repository,
        child: const TransactionsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Swiggy Instamart'));
    await tester.pumpAndSettle();

    expect(find.text('Gross spend'), findsOneWidget);
    expect(find.text('SWIGGY INSTAMART BANGALORE'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Edit'));
    await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit metadata'), findsOneWidget);
    expect(
      find.text('Applies to matching statement merchant and future imports.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Suggest'));
    await tester.pumpAndSettle();

    expect(repository.metadataSuggestionRequests, hasLength(1));
    expect(repository.metadataSuggestionRequests.single.transactionId, 'txn-1');
    expect(repository.metadataSuggestionRequests.single.reviewItemId, isNull);
    expect(find.text('Swiggy Grocery'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.corrections, hasLength(1));
    expect(repository.corrections.single.transactionId, 'txn-1');
    expect(repository.corrections.single.reviewItemId, isNull);
    expect(repository.corrections.single.merchantGroup, 'Swiggy Grocery');
    expect(repository.corrections.single.categoryId, 'cat-food');
    expect(repository.corrections.single.subcategoryId, 'sub-food-delivery');
    expect(repository.corrections.single.confidence, 'medium');
    expect(
      repository.corrections.single.notes,
      'Suggested grocery delivery spend.',
    );
    expect(find.text('Updated 1 transactions'), findsOneWidget);
  });

  testWidgets('transaction metadata suggestion failure keeps form values', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository()
      ..metadataSuggestionError = StateError('AI unavailable');

    await tester.pumpWidget(
      _financeTestApp(
        repository: repository,
        child: const TransactionsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Swiggy Instamart'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Edit'));
    await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Suggest'));
    await tester.pumpAndSettle();

    expect(repository.metadataSuggestionRequests, hasLength(1));
    expect(find.text('Swiggy Instamart'), findsWidgets);
    expect(find.text('Bad state: AI unavailable'), findsOneWidget);
    expect(repository.corrections, isEmpty);
  });

  testWidgets('settings creates category and subcategory', (tester) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Categories'));
    await tester.tap(find.widgetWithText(FilledButton, 'Create').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Travel');
    await tester.enterText(find.byType(TextFormField).at(1), 'Flights');
    await tester.tap(find.widgetWithText(FilledButton, 'Create').last);
    await tester.pumpAndSettle();

    expect(repository.createdCategoryRequests, hasLength(1));
    expect(repository.createdCategoryRequests.single.categoryName, 'Travel');
    expect(
      repository.createdCategoryRequests.single.subcategoryName,
      'Flights',
    );
    expect(find.text('Travel'), findsOneWidget);
    expect(find.text('Flights'), findsOneWidget);
    expect(find.text('Created Travel'), findsOneWidget);
  });

  testWidgets('settings shows Gmail connector status', (tester) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gmail connector'), findsOneWidget);
    expect(find.text('spendlens.hdfc@example.test'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Queued jobs'), findsOneWidget);
  });

  testWidgets('settings shows AI budget status', (tester) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI'), findsOneWidget);
    expect(find.text('gemini'), findsOneWidget);
    expect(find.text('gemini-3.5-flash'), findsOneWidget);
    expect(find.text('Free tier'), findsOneWidget);
    expect(find.text('Search off'), findsOneWidget);
  });

  testWidgets('ask expenses submits question and shows answer', (tester) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const AiScreen()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'What did I spend on food in March?',
    );
    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();

    expect(repository.expenseQuestions, hasLength(1));
    expect(repository.expenseQuestions.single.question, contains('food'));
    expect(find.text('Food spend was INR 42,000 in Mar 2026.'), findsOneWidget);
    expect(find.text('18 input tokens'), findsOneWidget);
  });

  testWidgets(
    'merchant review hides retired AI suggestions and research action',
    (tester) async {
      final repository = _FakeFinanceRepository();

      await tester.pumpWidget(
        _financeTestApp(
          repository: repository,
          child: const MerchantReviewScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Research'), findsNothing);
      expect(find.text('AI suggestions'), findsNothing);
      expect(find.text('Amazon Shopping'), findsNothing);
    },
  );

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

Widget _financeRouterTestApp({
  required _FakeFinanceRepository repository,
  required GoRouter router,
}) {
  return ProviderScope(
    overrides: [
      appBootstrapProvider.overrideWithValue(
        const AppBootstrap(supabaseStatus: SupabaseStatus.ready),
      ),
      householdContextProvider.overrideWithValue(AsyncData(_householdContext)),
      financeRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

GoRouter _financeTestRouter({
  String initialLocation = DashboardScreen.routePath,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: DashboardScreen.routePath,
        builder: (_, _) => const Scaffold(body: DashboardScreen()),
      ),
      GoRoute(
        path: TransactionsScreen.routePath,
        builder: (_, state) => Scaffold(
          body: TransactionsScreen(
            initialFilters: TransactionInitialFilters.fromUri(state.uri),
          ),
        ),
      ),
    ],
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
  final corrections = <TransactionMetadataCorrectionRequest>[];
  final createdCategoryRequests = <CategoryCreationRequest>[];
  final expenseQuestions = <ExpenseQuestionRequest>[];
  final metadataSuggestionRequests = <TransactionMetadataSuggestionRequest>[];
  final piggyBanks = <PiggyBankSummary>[];
  final piggyEntries = <PiggyBankEntry>[];
  TransactionMetadataSuggestionResult? nextMetadataSuggestion;
  Object? metadataSuggestionError;
  final aiStatus = AiBudgetStatus(
    householdId: 'household-1',
    provider: 'gemini',
    model: 'gemini-3.5-flash',
    monthlySpendCapUsd: 0,
    expenseQaEnabled: true,
    transactionMetadataSuggestionEnabled: true,
    transactionMetadataSuggestionWebSearchEnabled: false,
    freeTierOnly: true,
    currentPeriodMonth: DateTime(2026, 6),
    currentMonthSpendUsd: 0,
    currentMonthEventCount: 0,
    remainingMonthlyBudgetUsd: 0,
  );
  final gmailStatuses = <GmailConnectorStatus>[
    GmailConnectorStatus(
      id: 'mailbox-1',
      householdId: 'household-1',
      email: 'spendlens.hdfc@example.test',
      connectorStatus: 'connected',
      isActive: true,
      queuedJobCount: 1,
      watchExpiresAt: DateTime(2026, 6, 14),
      lastSyncAt: DateTime(2026, 6, 7, 9),
    ),
  ];
  var startedGmailConnector = false;
  String? disconnectedMailboxId;
  TransactionQuery? lastQuery;
  TrendQuery? lastTrendQuery;

  final categories = <CategoryOption>[
    CategoryOption(id: 'cat-food', name: 'Food'),
    CategoryOption(id: 'cat-fuel', name: 'Fuel'),
    CategoryOption(id: 'cat-shopping', name: 'Shopping'),
  ];

  final subcategories = <SubcategoryOption>[
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
      statementMerchant: 'SWIGGY INSTAMART BANGALORE',
      merchantId: 'merchant-swiggy',
      merchantName: 'Swiggy Instamart',
      categoryId: 'cat-food',
      categoryName: 'Food',
      subcategoryId: 'sub-food-delivery',
      subcategoryName: 'Delivery',
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
      merchantId: 'merchant-amazon',
      merchantName: 'Amazon Shopping',
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
    FinanceTransaction(
      id: 'txn-3',
      transactionDate: DateTime(2026, 6, 5),
      statementMerchant: 'CRED Club',
      categoryId: 'cat-shopping',
      categoryName: 'Shopping',
      subcategoryId: 'sub-marketplace',
      subcategoryName: 'Marketplace',
      sourceAccountId: 'source-upi',
      transactionType: 'debit_spend',
      amount: 112937,
      grossSpend: 112937,
      refundAmount: 0,
      netExpense: 112937,
      currencyCode: 'INR',
      confidence: 'high',
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
    _trendTransaction(
      id: 'trend-fake-3',
      transactionDate: DateTime(2026, 6, 5),
      statementMerchant: 'CRED Club',
      merchantGroup: 'CRED Club',
      categoryId: 'cat-shopping',
      categoryName: 'Shopping',
      sourceAccountId: 'source-upi',
      sourceLabel: 'HDFC Bank UPI account ending 0932',
      grossSpend: 112937,
      netExpense: 112937,
      cardholderName: null,
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

  void addSwiggyTransactions(int count) {
    for (var index = 0; index < count; index += 1) {
      transactions.add(
        FinanceTransaction(
          id: 'txn-swiggy-extra-${index + 1}',
          transactionDate: DateTime(2026, 3, (index % 28) + 1),
          statementMerchant: 'SWIGGY INSTAMART BANGALORE ${index + 1}',
          merchantId: 'merchant-swiggy',
          merchantName: 'Swiggy Instamart',
          categoryId: 'cat-food',
          categoryName: 'Food',
          subcategoryId: 'sub-food-delivery',
          subcategoryName: 'Delivery',
          sourceAccountId: 'source-1',
          transactionType: 'debit_spend',
          amount: 100,
          grossSpend: 100,
          refundAmount: 0,
          netExpense: 100,
          currencyCode: 'INR',
          confidence: 'high',
          cardholderName: 'Ada',
        ),
      );
    }
  }

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
        type: 'credit_card',
        displayName: 'HDFC Credit Card',
        cardholderName: 'Ada',
      ),
      SourceAccountOption(
        id: 'source-2',
        type: 'credit_card',
        displayName: 'ICICI Credit Card',
        cardholderName: 'Ada',
      ),
      SourceAccountOption(
        id: 'source-upi',
        type: 'upi',
        displayName: 'HDFC Bank UPI account ending 0932',
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
  Future<CategoryCreationResult> createCategory(
    CategoryCreationRequest request,
  ) async {
    createdCategoryRequests.add(request);
    final index = createdCategoryRequests.length;
    final category = CategoryOption(
      id: 'cat-created-$index',
      name: request.categoryName.trim(),
    );
    final subcategory = SubcategoryOption(
      id: 'sub-created-$index',
      categoryId: category.id,
      name: request.subcategoryName.trim(),
    );

    categories.add(category);
    subcategories.add(subcategory);

    return CategoryCreationResult(category: category, subcategory: subcategory);
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
  Future<List<GmailConnectorStatus>> fetchGmailConnectorStatus({
    required String householdId,
  }) async {
    return gmailStatuses
        .where((status) => status.householdId == householdId)
        .toList();
  }

  @override
  Future<AiBudgetStatus> fetchAiBudgetStatus({
    required String householdId,
  }) async {
    return aiStatus;
  }

  @override
  Future<ExpenseQuestionAnswer> askExpenseQuestion(
    ExpenseQuestionRequest request,
  ) async {
    expenseQuestions.add(request);
    return const ExpenseQuestionAnswer(
      answer: 'Food spend was INR 42,000 in Mar 2026.',
      jobId: 'job-1',
      usageEventId: 'usage-1',
      inputTokens: 18,
      outputTokens: 9,
      estimatedCostUsd: 0,
    );
  }

  @override
  Future<String> startGmailConnector({required String householdId}) async {
    startedGmailConnector = true;
    return 'https://accounts.google.com/o/oauth2/v2/auth?state=test';
  }

  @override
  Future<void> disconnectGmailMailbox({required String mailboxId}) async {
    disconnectedMailboxId = mailboxId;
    gmailStatuses.removeWhere((status) => status.id == mailboxId);
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
          transaction.statementMerchant.toLowerCase().contains(search) ||
          (transaction.merchantName?.toLowerCase().contains(search) ?? false);
      final matchesCategory =
          query.categoryId == null ||
          transaction.categoryId == query.categoryId;
      final matchesSourceType =
          query.sourceAccountType == null ||
          sourceTypeFor(transaction.sourceAccountId) == query.sourceAccountType;
      final matchesSource =
          query.sourceAccountId == null ||
          transaction.sourceAccountId == query.sourceAccountId;
      final matchesStart =
          query.startDate == null ||
          !transaction.transactionDate.isBefore(query.startDate!);
      final matchesEnd =
          query.endDate == null ||
          !transaction.transactionDate.isAfter(query.endDate!);

      return matchesSearch &&
          matchesCategory &&
          matchesSourceType &&
          matchesSource &&
          matchesStart &&
          matchesEnd;
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
      final matchesSourceType =
          query.sourceAccountType == null ||
          sourceTypeFor(transaction.sourceAccountId) == query.sourceAccountType;
      final matchesStart =
          query.startDate == null ||
          !transaction.transactionDate.isBefore(query.startDate!);
      final matchesEnd =
          query.endDate == null ||
          !transaction.transactionDate.isAfter(query.endDate!);

      return matchesCategory &&
          matchesSource &&
          matchesSourceType &&
          matchesStart &&
          matchesEnd;
    }).toList();

    return TrendReport.fromTransactions(filtered);
  }

  String? sourceTypeFor(String? sourceAccountId) {
    return switch (sourceAccountId) {
      'source-1' || 'source-2' => 'credit_card',
      'source-upi' => 'upi',
      _ => null,
    };
  }

  @override
  Future<TransactionMetadataCorrectionResult>
  applyTransactionMetadataCorrection(
    TransactionMetadataCorrectionRequest request,
  ) async {
    corrections.add(request);
    reviewItems.removeWhere((item) => item.id == request.reviewItemId);

    return TransactionMetadataCorrectionResult(
      ruleId: 'rule-1',
      merchantId: 'merchant-amazon',
      categoryId: request.categoryId,
      subcategoryId: request.subcategoryId,
      updatedTransactionCount: 1,
      resolvedReviewItemCount: 1,
    );
  }

  @override
  Future<TransactionMetadataSuggestionResult> suggestTransactionMetadata(
    TransactionMetadataSuggestionRequest request,
  ) async {
    metadataSuggestionRequests.add(request);
    final error = metadataSuggestionError;
    if (error != null) throw error;

    return nextMetadataSuggestion ??
        const TransactionMetadataSuggestionResult(
          merchantGroup: 'Amazon Shopping',
          categoryId: 'cat-shopping',
          subcategoryId: 'sub-marketplace',
          confidence: 'medium',
          notes: 'Suggested marketplace spend.',
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
