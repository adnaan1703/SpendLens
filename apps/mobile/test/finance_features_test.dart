import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spendlens/src/app/app_shell.dart';
import 'package:spendlens/src/core/bootstrap/app_bootstrap.dart';
import 'package:spendlens/src/core/theme/app_theme.dart';
import 'package:spendlens/src/core/theme/theme_mode_controller.dart';
import 'package:spendlens/src/data/repositories/finance_repository.dart';
import 'package:spendlens/src/data/repositories/household_repository.dart';
import 'package:spendlens/src/features/ai/ai_screen.dart';
import 'package:spendlens/src/features/activity/activity_screen.dart';
import 'package:spendlens/src/features/dashboard/dashboard_screen.dart';
import 'package:spendlens/src/features/merchant_review/merchant_review_screen.dart';
import 'package:spendlens/src/features/piggy_banks/piggy_banks_screen.dart';
import 'package:spendlens/src/features/settings/settings_screen.dart';
import 'package:spendlens/src/features/transaction_metadata/merchant_name_matcher.dart';
import 'package:spendlens/src/features/trends/trends_screen.dart';
import 'package:spendlens/src/shared/widgets/app_primitives.dart';

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

  test('transaction query supports label filter equality and copyWith', () {
    const query = TransactionQuery(
      householdId: 'household-1',
      searchText: 'swiggy',
      merchantId: 'merchant-swiggy',
      labelId: 'label-grocery',
    );

    expect(
      query,
      const TransactionQuery(
        householdId: 'household-1',
        searchText: 'swiggy',
        merchantId: 'merchant-swiggy',
        labelId: 'label-grocery',
      ),
    );
    expect(
      query.copyWith(labelId: 'label-reimburse').labelId,
      'label-reimburse',
    );
    expect(
      query.copyWith(merchantId: 'merchant-amazon').merchantId,
      'merchant-amazon',
    );
    expect(query.copyWith(clearMerchant: true).merchantId, isNull);
    expect(query.copyWith(clearLabel: true).labelId, isNull);
  });

  test('merchant name matcher handles close, exact, and non-match cases', () {
    const merchants = [
      MerchantOption(id: 'merchant-amazon', displayName: 'Amazon Shopping'),
      MerchantOption(id: 'merchant-swiggy', displayName: 'Swiggy Instamart'),
      MerchantOption(id: 'merchant-uber', displayName: 'Uber'),
    ];

    expect(normalizeMerchantName('Food & Fuel - Mart'), 'food and fuel mart');

    final amazonTypo = findMerchantNameMatch(
      input: 'Amazon Shoping',
      merchants: merchants,
    );
    expect(amazonTypo?.kind, MerchantNameMatchKind.close);
    expect(amazonTypo?.merchant.displayName, 'Amazon Shopping');
    expect(
      amazonTypo!.score,
      greaterThanOrEqualTo(merchantCloseMatchThreshold),
    );

    final swiggyTypo = findMerchantNameMatch(
      input: 'Swigy Instamart',
      merchants: merchants,
    );
    expect(swiggyTypo?.kind, MerchantNameMatchKind.close);
    expect(swiggyTypo?.merchant.displayName, 'Swiggy Instamart');

    final exactCase = findMerchantNameMatch(
      input: 'amazon shopping',
      merchants: merchants,
    );
    expect(exactCase?.kind, MerchantNameMatchKind.exact);
    expect(exactCase?.merchant.displayName, 'Amazon Shopping');

    expect(
      findMerchantNameMatch(input: 'Amazon Prime', merchants: merchants),
      isNull,
    );
    expect(
      findMerchantNameMatch(input: 'Uber Eats', merchants: merchants),
      isNull,
    );
  });

  test(
    'merchant group repository contract mutates fake rename and merge',
    () async {
      final repository = _FakeFinanceRepository();

      final snapshot = await repository.fetchMerchantGroupManagerSnapshot(
        householdId: 'household-1',
      );
      final swiggyUsage = snapshot.usageFor('merchant-swiggy');
      expect(swiggyUsage?.displayName, 'Swiggy Instamart');
      expect(swiggyUsage?.transactionCount, 1);
      expect(swiggyUsage?.activeMappingRuleCount, 1);

      final renamed = await repository.renameMerchantGroup(
        const MerchantGroupRenameRequest(
          householdId: 'household-1',
          merchantId: 'merchant-swiggy',
          displayName: 'Swiggy Market',
        ),
      );
      expect(renamed.displayName, 'Swiggy Market');
      expect(
        repository.merchantGroupRenameRequests.single.merchantId,
        'merchant-swiggy',
      );

      final result = await repository.mergeMerchantGroups(
        const MerchantGroupMergeRequest(
          householdId: 'household-1',
          destinationMerchantId: 'merchant-swiggy',
          destinationDisplayName: 'Swiggy Market',
          sourceMerchantIds: ['merchant-amazon'],
          categoryStrategy: MerchantGroupMergeCategoryStrategy.destination,
        ),
      );

      expect(result.destinationMerchantId, 'merchant-swiggy');
      expect(result.movedTransactionCount, 1);
      expect(result.movedAliasCount, 1);
      expect(result.deletedSourceMerchantCount, 1);
      expect(result.categoryUpdatedTransactionCount, 1);
      expect(
        repository.merchantGroupMergeRequests.single.categoryStrategy,
        MerchantGroupMergeCategoryStrategy.destination,
      );

      final page = await repository.fetchTransactions(
        const TransactionQuery(householdId: 'household-1'),
      );
      final amazonTransaction = page.items
          .where((transaction) => transaction.id == 'txn-2')
          .single;
      expect(amazonTransaction.merchantId, 'merchant-swiggy');
      expect(amazonTransaction.merchantName, 'Swiggy Market');
      expect(amazonTransaction.categoryId, 'cat-food');
      expect(amazonTransaction.subcategoryId, 'sub-food-delivery');
    },
  );

  test('merchant group merge result parses count payloads', () {
    final result = MerchantGroupMergeResult.fromJson({
      'destination_merchant_id': 'merchant-swiggy',
      'destination_display_name': 'Swiggy Instamart',
      'destination_category_id': 'cat-food',
      'destination_subcategory_id': 'sub-food-delivery',
      'moved_transaction_count': '2',
      'moved_alias_count': 3,
      'moved_mapping_rule_count': 4,
      'moved_review_suggestion_count': 1,
      'deleted_source_merchant_count': 2,
      'category_updated_transaction_count': 2,
      'category_updated_mapping_rule_count': 1,
      'category_updated_review_suggestion_count': 1,
    });

    expect(result.destinationMerchantId, 'merchant-swiggy');
    expect(result.destinationCategoryId, 'cat-food');
    expect(result.movedTransactionCount, 2);
    expect(result.movedAliasCount, 3);
    expect(result.categoryUpdatedMappingRuleCount, 1);
  });

  test('dashboard top merchants group by canonical merchant id', () {
    final merchants = topMerchantsFromTransactionRows(
      [
        {
          'merchant_id': 'merchant-swiggy',
          'statement_merchant': 'SWIGGY INSTAMART BLR',
          'normalized_statement_merchant': 'swiggy instamart blr',
          'net_expense': 1200,
          'refund_amount': 0,
        },
        {
          'merchant_id': 'merchant-swiggy',
          'statement_merchant': 'SWIGGY GROCERY',
          'normalized_statement_merchant': 'swiggy grocery',
          'net_expense': 300,
          'refund_amount': 0,
        },
        {
          'merchant_id': null,
          'statement_merchant': 'LOCAL CAFE',
          'normalized_statement_merchant': 'local cafe',
          'net_expense': 500,
          'refund_amount': 50,
        },
      ],
      merchantNamesById: {'merchant-swiggy': 'Swiggy Instamart'},
    );

    expect(merchants.first.merchantName, 'Swiggy Instamart');
    expect(merchants.first.transactionCount, 2);
    expect(merchants.first.netSpend, 1500);
    expect(merchants.last.merchantName, 'LOCAL CAFE');
    expect(merchants.last.refundAmount, 50);
  });

  test('monthly cap progress parses carry-forward values', () {
    final progress = MonthlyCapProgress.fromJson({
      'monthly_cap_id': 'cap-carry',
      'monthly_cap_version_id': 'cap-version-carry',
      'household_id': 'household-1',
      'name': 'Carry cap',
      'period_month': '2026-06-01',
      'cap_amount': 1000,
      'base_cap_amount': 1000,
      'carry_forward_enabled': true,
      'carry_forward_amount': -200,
      'effective_cap_amount': 800,
      'spent_amount': 900,
      'remaining_amount': -100,
      'percent_used': 1.125,
      'is_over_budget': true,
      'matched_transaction_count': 3,
      'category_target_ids': ['cat-food'],
      'category_target_names': ['Food'],
      'label_target_ids': ['label-grocery'],
      'label_target_names': ['Groceries'],
    });

    expect(progress.baseCapAmount, 1000);
    expect(progress.carryForwardEnabled, isTrue);
    expect(progress.carryForwardAmount, -200);
    expect(progress.effectiveCapAmount, 800);
    expect(progress.remainingAmount, -100);
    expect(progress.percentUsed, 1.125);
    expect(progress.isOverBudget, isTrue);
    expect(progress.categoryTargets.single.name, 'Food');
    expect(progress.labelTargets.single.name, 'Groceries');
  });

  test('primary app destinations match the redesigned IA', () {
    expect(appDestinations.map((destination) => destination.label), [
      'Dashboard',
      'Activity',
      'Review',
      'Vaults',
    ]);
    expect(appDestinations.map((destination) => destination.path), [
      DashboardScreen.routePath,
      ActivityScreen.routePath,
      MerchantReviewScreen.routePath,
      PiggyBanksScreen.routePath,
    ]);
  });

  testWidgets('app shell exposes settings outside primary navigation', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final size in [
      const Size(390, 844),
      const Size(768, 1024),
      const Size(1024, 900),
    ]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      final router = _shellTestRouter();

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      if (size.width < 768) {
        expect(find.byType(NavigationDestination), findsNWidgets(4));
        expect(find.byType(NavigationRail), findsNothing);
      } else {
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(NavigationDestination), findsNothing);
      }
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Activity'), findsWidgets);
      expect(find.text('Review'), findsWidgets);
      expect(find.text('Vaults'), findsWidgets);
      expect(find.text('Settings'), findsNothing);

      await tester.tap(find.byTooltip('Open settings'));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/settings');
      expect(find.byType(NavigationDestination), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Focused settings'), findsOneWidget);

      router.dispose();
    }
  });

  testWidgets('redesigned core surfaces render at M51 widths and theme modes', (
    tester,
  ) async {
    final scenarios = [
      _RedesignQaScenario(
        '390px light mobile',
        const Size(390, 900),
        ThemeMode.light,
        Brightness.light,
      ),
      _RedesignQaScenario(
        '768px dark tablet',
        const Size(768, 1024),
        ThemeMode.dark,
        Brightness.light,
      ),
      _RedesignQaScenario(
        '1024px system desktop',
        const Size(1024, 900),
        ThemeMode.system,
        Brightness.dark,
      ),
    ];
    addTearDown(() {
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final scenario in scenarios) {
      await _pumpRedesignSurface(
        tester,
        scenario,
        repository: _FakeFinanceRepository(),
        child: const DashboardScreen(),
      );
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Spending'), findsOneWidget);
      expect(find.text('Review Queue'), findsOneWidget);

      await _pumpRedesignSurface(
        tester,
        scenario,
        repository: _FakeFinanceRepository(),
        child: const ActivityScreen(),
      );
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('List'), findsOneWidget);
      expect(find.text('Merchant search'), findsOneWidget);
      expect(find.text('Swiggy Instamart'), findsWidgets);

      await _pumpRedesignSurface(
        tester,
        scenario,
        repository: _FakeFinanceRepository(),
        child: const SingleChildScrollView(child: ActivityChartsPane()),
      );
      expect(find.text('Monthly Net Spend'), findsOneWidget);
      expect(find.text('Gross, Refunds, Net'), findsOneWidget);

      await _pumpRedesignSurface(
        tester,
        scenario,
        repository: _FakeFinanceRepository(),
        child: const MerchantReviewScreen(),
      );
      expect(find.text('Review'), findsOneWidget);
      expect(find.text('Open Reviews'), findsOneWidget);
      expect(find.text('AMZN MKTP IN'), findsOneWidget);

      await _pumpRedesignSurface(
        tester,
        scenario,
        repository: _FakeFinanceRepository(),
        child: const PiggyBanksScreen(),
      );
      expect(find.text('Vaults'), findsWidgets);
      expect(find.text('Create Vault'), findsOneWidget);
      expect(find.text('No vaults yet'), findsOneWidget);

      await _pumpRedesignSurface(
        tester,
        scenario,
        repository: _FakeFinanceRepository(),
        child: const SettingsScreen(),
      );
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Account & Runtime'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('System default'), findsOneWidget);

      await _pumpRedesignSurface(
        tester,
        scenario,
        repository: _FakeFinanceRepository(),
        child: const AiScreen(),
      );
      expect(find.text('Ask Expenses'), findsOneWidget);
      expect(find.text('Question'), findsOneWidget);
      expect(find.text('AI budget'), findsOneWidget);

      await _pumpRedesignSurface(
        tester,
        scenario,
        repository: _FakeFinanceRepository(),
        child: const ActivityScreen(),
      );
      final transactionTitle = find.text('Swiggy Instamart').first;
      await tester.ensureVisible(transactionTitle);
      final transactionCard = find.ancestor(
        of: transactionTitle,
        matching: find.byType(AppContentCard),
      );
      await tester.tap(transactionCard.first);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byTooltip('Close transaction details'), findsOneWidget);
      expect(find.text('Debit Spend'), findsOneWidget);

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Edit'));
      await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('metadata-editor-card')),
        findsOneWidget,
      );
      expect(find.text('Edit metadata'), findsOneWidget);
      expect(find.text('Suggest'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: scenario.label);
    }
  });

  test('label repository contract mutates one transaction label set', () async {
    final repository = _FakeFinanceRepository();

    final result = await repository.setTransactionLabels(
      const TransactionLabelsSetRequest(
        householdId: 'household-1',
        transactionId: 'txn-2',
        labelIds: ['label-grocery'],
        newLabelNames: ['Office'],
      ),
    );

    expect(result.labels.map((label) => label.name), ['Groceries', 'Office']);
    expect(repository.labelSetRequests.single.transactionId, 'txn-2');

    final groceryPage = await repository.fetchTransactions(
      const TransactionQuery(
        householdId: 'household-1',
        labelId: 'label-grocery',
      ),
    );
    expect(groceryPage.items.map((transaction) => transaction.id), [
      'txn-1',
      'txn-2',
    ]);

    final renamed = await repository.renameHouseholdLabel(
      const LabelRenameRequest(
        householdId: 'household-1',
        labelId: 'label-grocery',
        name: 'Food Run',
      ),
    );
    expect(renamed.name, 'Food Run');

    final snapshot = await repository.fetchLabelManagerSnapshot(
      householdId: 'household-1',
    );
    expect(snapshot.usageFor('label-grocery')?.transactionCount, 2);

    final deleted = await repository.deleteHouseholdLabel(
      const LabelDeleteRequest(
        householdId: 'household-1',
        labelId: 'label-grocery',
      ),
    );
    expect(deleted.detachedTransactionCount, 2);

    final emptyPage = await repository.fetchTransactions(
      const TransactionQuery(
        householdId: 'household-1',
        labelId: 'label-grocery',
      ),
    );
    expect(emptyPage.items, isEmpty);
  });

  testWidgets('dashboard creates a category-only monthly cap', (tester) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const DashboardScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mar 2026 net'), findsOneWidget);
    expect(find.text('INR 42,000'), findsWidgets);
    expect(find.text('+INR 2,000'), findsOneWidget);
    expect(find.text('Add cap'), findsOneWidget);

    await _openAddCapSheet(tester);
    expect(
      find.text('Starts in Mar 2026 and repeats until stopped.'),
      findsOneWidget,
    );
    await _fillCapNameAndAmount(tester, name: 'Fuel cap', amount: '5000');
    await _tapTargetChip(tester, 'Fuel');
    await _saveCapSheet(tester);

    expect(repository.monthlyCapUpsertRequests, hasLength(1));
    expect(repository.monthlyCapUpsertRequests.single.name, 'Fuel cap');
    expect(repository.monthlyCapUpsertRequests.single.categoryIds, [
      'cat-fuel',
    ]);
    expect(repository.monthlyCapUpsertRequests.single.labelIds, isEmpty);
    expect(repository.monthlyCapUpsertRequests.single.capAmount, 5000);
    expect(
      repository.monthlyCapUpsertRequests.single.carryForwardEnabled,
      isFalse,
    );
  });

  testWidgets('dashboard can create a monthly cap with carry-forward', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const DashboardScreen()),
    );
    await tester.pumpAndSettle();

    await _openAddCapSheet(tester);

    expect(_capCarryForwardSwitch(tester).value, isFalse);

    await _tapCarryForwardSwitch(tester);
    await _fillCapNameAndAmount(tester, name: 'Rolling fuel', amount: '5000');
    await _tapTargetChip(tester, 'Fuel');
    await _saveCapSheet(tester);

    expect(repository.monthlyCapUpsertRequests, hasLength(1));
    expect(repository.monthlyCapUpsertRequests.single.name, 'Rolling fuel');
    expect(
      repository.monthlyCapUpsertRequests.single.carryForwardEnabled,
      isTrue,
    );
  });

  testWidgets('dashboard cap metric includes category and label targets', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const DashboardScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Monthly caps'), findsWidgets);
    expect(find.text('3 targets without caps'), findsOneWidget);
  });

  testWidgets('dashboard redesign renders hierarchy at 390px width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const DashboardScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Mar 2026'), findsOneWidget);
    expect(find.text('Spending'), findsOneWidget);
    expect(find.text('Mar 2026 net'), findsOneWidget);
    expect(find.text('Month Change'), findsOneWidget);
    expect(find.text('+5%'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Review Queue'), findsOneWidget);
    expect(find.text('3 Items'), findsOneWidget);
    expect(find.text('Monthly caps'), findsWidgets);
    expect(find.text('Top categories'), findsOneWidget);
    expect(find.text('Top merchants'), findsOneWidget);
    expect(find.text('Swiggy Instamart'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard empty cap state avoids one-month-only copy', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository()..monthlyCapProgress.clear();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const DashboardScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('No caps set'), findsOneWidget);
    expect(
      find.text('Add a recurring category or label cap starting this month.'),
      findsOneWidget,
    );
  });

  testWidgets('dashboard creates a label-only monthly cap', (tester) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const DashboardScreen()),
    );
    await tester.pumpAndSettle();

    await _openAddCapSheet(tester);
    await _fillCapNameAndAmount(tester, name: 'Reimbursements', amount: '2500');
    await _tapTargetChip(tester, 'Reimburse');
    await _saveCapSheet(tester);

    expect(repository.monthlyCapUpsertRequests, hasLength(1));
    expect(repository.monthlyCapUpsertRequests.single.name, 'Reimbursements');
    expect(repository.monthlyCapUpsertRequests.single.categoryIds, isEmpty);
    expect(repository.monthlyCapUpsertRequests.single.labelIds, [
      'label-reimburse',
    ]);
    expect(repository.monthlyCapUpsertRequests.single.capAmount, 2500);
  });

  testWidgets('dashboard creates a mixed category and label monthly cap', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const DashboardScreen()),
    );
    await tester.pumpAndSettle();

    await _openAddCapSheet(tester);
    await _fillCapNameAndAmount(tester, name: 'Essentials', amount: '12500');
    await _tapTargetChip(tester, 'Fuel');
    await _tapTargetChip(tester, 'Groceries');
    await _saveCapSheet(tester);

    expect(repository.monthlyCapUpsertRequests, hasLength(1));
    expect(repository.monthlyCapUpsertRequests.single.name, 'Essentials');
    expect(repository.monthlyCapUpsertRequests.single.categoryIds, [
      'cat-fuel',
    ]);
    expect(repository.monthlyCapUpsertRequests.single.labelIds, [
      'label-grocery',
    ]);
    expect(repository.monthlyCapUpsertRequests.single.capAmount, 12500);
  });

  testWidgets('dashboard cap form validates required name', (tester) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const DashboardScreen()),
    );
    await tester.pumpAndSettle();

    await _openAddCapSheet(tester);
    await _fillCapNameAndAmount(tester, name: '', amount: '1000');
    await _tapTargetChip(tester, 'Fuel');

    expect(find.text('Name is required'), findsOneWidget);
    expect(_capSaveButton(tester).enabled, isFalse);
    expect(repository.monthlyCapUpsertRequests, isEmpty);
  });

  testWidgets('dashboard cap form validates at least one target', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const DashboardScreen()),
    );
    await tester.pumpAndSettle();

    await _openAddCapSheet(tester);
    await _fillCapNameAndAmount(tester, name: 'Loose cap', amount: '1000');

    expect(find.text('Choose at least one target'), findsOneWidget);
    expect(_capSaveButton(tester).enabled, isFalse);
    expect(repository.monthlyCapUpsertRequests, isEmpty);
  });

  testWidgets('dashboard edits caps while preserving and changing targets', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    repository.monthlyCapProgress[0] = _copyMonthlyCapProgress(
      repository.monthlyCapProgress[0],
      carryForwardEnabled: true,
    );

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const DashboardScreen()),
    );
    await tester.pumpAndSettle();

    final firstEditButton = find.byTooltip('Edit cap').first;
    await tester.ensureVisible(firstEditButton);
    await tester.tap(firstEditButton);
    await tester.pumpAndSettle();

    expect(find.text('Saves from Mar 2026 onward.'), findsOneWidget);
    expect(_capCarryForwardSwitch(tester).value, isTrue);

    await _saveCapSheet(tester);

    expect(repository.monthlyCapUpsertRequests, hasLength(1));
    expect(repository.monthlyCapUpsertRequests.single.monthlyCapId, 'cap-food');
    expect(repository.monthlyCapUpsertRequests.single.name, 'Food');
    expect(repository.monthlyCapUpsertRequests.single.categoryIds, [
      'cat-food',
    ]);
    expect(repository.monthlyCapUpsertRequests.single.labelIds, isEmpty);
    expect(
      repository.monthlyCapUpsertRequests.single.carryForwardEnabled,
      isTrue,
    );

    final updatedEditButton = find.byTooltip('Edit cap').first;
    await tester.ensureVisible(updatedEditButton);
    await tester.tap(updatedEditButton);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('cap-name-field')),
      'Fuel and groceries',
    );
    await tester.enterText(
      find.byKey(const ValueKey('cap-amount-field')),
      '30000',
    );
    await _tapCarryForwardSwitch(tester);
    await _tapTargetChip(tester, 'Food');
    await _tapTargetChip(tester, 'Fuel');
    await _tapTargetChip(tester, 'Groceries');
    await _saveCapSheet(tester);

    final changedRequest = repository.monthlyCapUpsertRequests.last;
    expect(changedRequest.monthlyCapId, 'cap-food');
    expect(changedRequest.name, 'Fuel and groceries');
    expect(changedRequest.categoryIds, ['cat-fuel']);
    expect(changedRequest.labelIds, ['label-grocery']);
    expect(changedRequest.capAmount, 30000);
    expect(changedRequest.carryForwardEnabled, false);
  });

  testWidgets('dashboard deletes caps after confirmation', (tester) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const DashboardScreen()),
    );
    await tester.pumpAndSettle();

    final firstDeleteButton = find.byTooltip('Stop cap').first;
    await tester.ensureVisible(firstDeleteButton);
    await tester.tap(firstDeleteButton);
    await tester.pumpAndSettle();
    expect(find.text('Stop Food?'), findsOneWidget);
    expect(
      find.textContaining('transactions, categories, labels'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    expect(repository.monthlyCapDeleteRequests, isEmpty);

    final confirmedDeleteButton = find.byTooltip('Stop cap').first;
    await tester.ensureVisible(confirmedDeleteButton);
    await tester.tap(confirmedDeleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Stop cap'));
    await tester.pumpAndSettle();

    expect(repository.monthlyCapDeleteRequests, hasLength(1));
    expect(repository.monthlyCapDeleteRequests.single.monthlyCapId, 'cap-food');
    expect(
      repository.monthlyCapDeleteRequests.single.periodMonth,
      DateTime(2026, 3),
    );
  });

  testWidgets('dashboard renders cap progress and target chips', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository()
      ..monthlyCapProgress.add(
        MonthlyCapProgress(
          monthlyCapId: 'cap-mixed',
          monthlyCapVersionId: 'cap-version-mixed',
          householdId: 'household-1',
          name: 'Very long category and label cap name for a narrow screen',
          periodMonth: DateTime(2026, 3),
          capAmount: 12000,
          baseCapAmount: 12000,
          carryForwardEnabled: false,
          carryForwardAmount: 0,
          effectiveCapAmount: 12000,
          spentAmount: 3000,
          remainingAmount: 9000,
          percentUsed: 0.25,
          isOverBudget: false,
          matchedTransactionCount: 3,
          categoryTargets: const [
            MonthlyCapCategoryTarget(id: 'cat-fuel', name: 'Fuel'),
          ],
          labelTargets: const [
            MonthlyCapLabelTarget(
              id: 'label-grocery',
              name: 'Groceries with a very long target name',
            ),
          ],
        ),
      )
      ..monthlyCapProgress.add(
        MonthlyCapProgress(
          monthlyCapId: 'cap-positive-carry',
          monthlyCapVersionId: 'cap-version-positive-carry',
          householdId: 'household-1',
          name: 'Travel carry forward',
          periodMonth: DateTime(2026, 3),
          capAmount: 13000,
          baseCapAmount: 13000,
          carryForwardEnabled: true,
          carryForwardAmount: 3000,
          effectiveCapAmount: 16000,
          spentAmount: 3000,
          remainingAmount: 13000,
          percentUsed: 0.1875,
          isOverBudget: false,
          matchedTransactionCount: 2,
          categoryTargets: const [
            MonthlyCapCategoryTarget(id: 'cat-fuel', name: 'Fuel'),
          ],
          labelTargets: const [],
        ),
      )
      ..monthlyCapProgress.add(
        MonthlyCapProgress(
          monthlyCapId: 'cap-negative-carry',
          monthlyCapVersionId: 'cap-version-negative-carry',
          householdId: 'household-1',
          name: 'Already exhausted cap',
          periodMonth: DateTime(2026, 3),
          capAmount: 5000,
          baseCapAmount: 5000,
          carryForwardEnabled: true,
          carryForwardAmount: -7000,
          effectiveCapAmount: -2000,
          spentAmount: 0,
          remainingAmount: -2000,
          percentUsed: null,
          isOverBudget: true,
          matchedTransactionCount: 0,
          categoryTargets: const [
            MonthlyCapCategoryTarget(id: 'cat-shopping', name: 'Shopping'),
          ],
          labelTargets: const [],
        ),
      );

    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const DashboardScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Spent INR 42,000'), findsOneWidget);
    expect(find.text('Base INR 50,000'), findsOneWidget);
    expect(find.text('Available INR 50,000'), findsOneWidget);
    expect(find.text('Left INR 8,000'), findsOneWidget);
    expect(find.text('84%'), findsOneWidget);
    expect(find.text('8 matched'), findsOneWidget);
    expect(find.text('Base INR 13,000'), findsOneWidget);
    expect(find.text('Carried +INR 3,000'), findsOneWidget);
    expect(find.text('Available INR 16,000'), findsOneWidget);
    expect(find.text('Left INR 13,000'), findsOneWidget);
    expect(find.text('Base INR 5,000'), findsOneWidget);
    expect(find.text('Carried -INR 7,000'), findsOneWidget);
    expect(find.text('Available -INR 2,000'), findsOneWidget);
    expect(find.text('Over INR 2,000'), findsOneWidget);
    expect(find.text('Over INR 12,937'), findsOneWidget);
    expect(find.text('113%'), findsOneWidget);
    expect(find.text('Food'), findsWidgets);
    expect(find.text('Shopping'), findsWidgets);
    expect(find.text('Groceries with a very long target name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard can select a future active cap month without spend', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository()
      ..availableMonths = [DateTime(2026, 6), DateTime(2026, 3)]
      ..monthlyCapProgress.add(
        MonthlyCapProgress(
          monthlyCapId: 'cap-june',
          monthlyCapVersionId: 'cap-version-june',
          householdId: 'household-1',
          name: 'Future fuel',
          periodMonth: DateTime(2026, 6),
          capAmount: 9000,
          baseCapAmount: 9000,
          carryForwardEnabled: false,
          carryForwardAmount: 0,
          effectiveCapAmount: 9000,
          spentAmount: 0,
          remainingAmount: 9000,
          percentUsed: 0,
          isOverBudget: false,
          matchedTransactionCount: 0,
          categoryTargets: const [
            MonthlyCapCategoryTarget(id: 'cat-fuel', name: 'Fuel'),
          ],
          labelTargets: const [],
        ),
      );

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const DashboardScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mar 2026 net'), findsOneWidget);

    await tester.tap(find.text('Mar 2026').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jun 2026').last);
    await tester.pumpAndSettle();

    expect(find.text('Jun 2026 net'), findsOneWidget);
    expect(find.text('0 transactions'), findsOneWidget);
    expect(find.text('Future fuel'), findsOneWidget);
    expect(find.text('Available INR 9,000'), findsOneWidget);
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

    final categoryRow = find.ancestor(
      of: find.text('8 transactions'),
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(categoryRow);
    await tester.tap(categoryRow);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/activity');
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

    final merchantRow = find.ancestor(
      of: find.text('4 transactions'),
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(merchantRow);
    await tester.tap(merchantRow);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/activity');
    expect(repository.lastQuery?.categoryId, isNull);
    expect(repository.lastQuery?.searchText, 'Swiggy Instamart');
    expect(repository.lastQuery?.merchantId, isNull);
    expect(dateString(repository.lastQuery!.startDate!), '2026-03-01');
    expect(dateString(repository.lastQuery!.endDate!), '2026-03-31');
    expect(repository.lastQuery?.page, 0);
  });

  testWidgets('transactions search and category filters refresh query', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const ActivityScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Swiggy Instamart'), findsWidgets);
    expect(find.text('Amazon Shopping'), findsOneWidget);
    expect(find.text('All dates'), findsOneWidget);
    expect(repository.lastQuery?.startDate, isNull);
    expect(repository.lastQuery?.endDate, isNull);

    await tester.enterText(find.byType(TextField), 'swiggy');
    await tester.pumpAndSettle();

    expect(repository.lastQuery?.searchText, 'swiggy');
    expect(find.text('Swiggy Instamart'), findsWidgets);
    expect(find.text('Amazon Shopping'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();

    expect(repository.lastQuery?.categoryId, 'cat-food');
  });

  testWidgets(
    'Activity merchant autocomplete filters by selected merchant id',
    (tester) async {
      final repository = _FakeFinanceRepository();

      await tester.pumpWidget(
        _financeTestApp(repository: repository, child: const ActivityScreen()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'swiggy');
      await tester.pumpAndSettle();

      expect(repository.lastQuery?.searchText, 'swiggy');
      expect(repository.lastQuery?.merchantId, isNull);
      expect(
        find.byKey(const ValueKey('merchant-option-merchant-swiggy')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('merchant-option-merchant-swiggy')),
      );
      await tester.pumpAndSettle();

      final selectedMerchantSearch = tester.widget<TextField>(
        find.byType(TextField),
      );
      expect(selectedMerchantSearch.controller?.text, 'Swiggy Instamart');
      expect(repository.lastQuery?.searchText, 'Swiggy Instamart');
      expect(repository.lastQuery?.merchantId, 'merchant-swiggy');
      expect(find.text('Amazon Shopping'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Amazon Pay');
      await tester.pumpAndSettle();

      expect(repository.lastQuery?.searchText, 'Amazon Pay');
      expect(repository.lastQuery?.merchantId, isNull);
      expect(find.text('Amazon Shopping'), findsOneWidget);
      expect(find.text('Swiggy Instamart'), findsNothing);
    },
  );

  testWidgets('activity opens in list mode by default on a narrow viewport', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const ActivityScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
    expect(find.text('Charts'), findsOneWidget);
    expect(find.text('Merchant search'), findsOneWidget);
    expect(find.text('Swiggy Instamart'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction detail opens from Activity List at 390px width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const ActivityScreen()),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Swiggy Instamart').first);
    await tester.tap(find.text('Swiggy Instamart').first);
    await tester.pumpAndSettle();

    final detailSheet = find.byType(BottomSheet);
    expect(detailSheet, findsOneWidget);
    expect(
      find.descendant(
        of: detailSheet,
        matching: find.byTooltip('Close transaction details'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detailSheet, matching: find.text('Swiggy Instamart')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detailSheet, matching: find.text('2026-03-12')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detailSheet, matching: find.text('Debit Spend')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detailSheet, matching: find.text('Statement')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detailSheet, matching: find.text('Gross spend')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detailSheet, matching: find.text('Refunds')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detailSheet, matching: find.text('Net expense')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detailSheet, matching: find.text('Source amount')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detailSheet, matching: find.text('Category')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detailSheet, matching: find.text('Subcategory')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detailSheet, matching: find.text('Confidence')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detailSheet, matching: find.text('Cardholder')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: detailSheet,
        matching: find.widgetWithText(OutlinedButton, 'Edit labels'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: detailSheet,
        matching: find.widgetWithText(FilledButton, 'Edit'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction delete action is owner-only in detail', (
    tester,
  ) async {
    final ownerRepository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(
        repository: ownerRepository,
        child: const ActivityScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await _openTransactionDetail(tester, 'Swiggy Instamart');

    expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);

    for (final role in ['admin', 'member', 'viewer']) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      final repository = _FakeFinanceRepository();
      await tester.pumpWidget(
        _financeTestApp(
          repository: repository,
          householdContext: _householdContextWithRole(role),
          child: const ActivityScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await _openTransactionDetail(tester, 'Swiggy Instamart');

      expect(
        find.widgetWithText(FilledButton, 'Delete'),
        findsNothing,
        reason: role,
      );
      expect(find.widgetWithText(FilledButton, 'Edit'), findsOneWidget);
    }
  });

  testWidgets('transaction delete confirmation can be canceled', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const ActivityScreen()),
    );
    await tester.pumpAndSettle();
    await _openTransactionDetail(tester, 'Swiggy Instamart');

    await _tapTransactionDeleteAction(tester);

    expect(find.text('Delete transaction?'), findsOneWidget);
    expect(
      find.textContaining('monthly spend, merchant spend, trends'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Vault entries and service diagnostics'),
      findsOneWidget,
    );
    expect(
      find.textContaining('future workbook or Gmail re-import'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repository.transactionDeleteRequests, isEmpty);
    expect(find.byTooltip('Close transaction details'), findsOneWidget);
    expect(find.text('Swiggy Instamart'), findsWidgets);
  });

  testWidgets('transaction delete confirms and removes Activity row', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const ActivityScreen()),
    );
    await tester.pumpAndSettle();
    final initialFetchCount = repository.transactionFetchCount;
    await _openTransactionDetail(tester, 'Swiggy Instamart');

    await _tapTransactionDeleteAction(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm delete'));
    await tester.pumpAndSettle();

    expect(repository.transactionDeleteRequests, hasLength(1));
    expect(
      repository.transactionDeleteRequests.single.householdId,
      'household-1',
    );
    expect(repository.transactionDeleteRequests.single.transactionId, 'txn-1');
    expect(
      repository.transactions.any((transaction) => transaction.id == 'txn-1'),
      isFalse,
    );
    expect(repository.transactionFetchCount, greaterThan(initialFetchCount));
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Swiggy Instamart'), findsNothing);
    expect(find.textContaining('Deleted transaction.'), findsOneWidget);
  });

  testWidgets('transaction delete error keeps current Activity state', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository()
      ..transactionDeleteError = StateError('RPC unavailable');

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const ActivityScreen()),
    );
    await tester.pumpAndSettle();
    await _openTransactionDetail(tester, 'Swiggy Instamart');

    await _tapTransactionDeleteAction(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm delete'));
    await tester.pumpAndSettle();

    expect(repository.transactionDeleteRequests, hasLength(1));
    expect(
      repository.transactions.any((transaction) => transaction.id == 'txn-1'),
      isTrue,
    );
    expect(find.text('Delete transaction?'), findsOneWidget);
    expect(find.text('Swiggy Instamart'), findsWidgets);
    expect(find.textContaining('Bad state: RPC unavailable'), findsOneWidget);
  });

  testWidgets('transaction delete dialog fits narrow Activity layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const ActivityScreen()),
    );
    await tester.pumpAndSettle();
    await _openTransactionDetail(tester, 'Swiggy Instamart');
    await _tapTransactionDeleteAction(tester);

    expect(find.text('Delete transaction?'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Confirm delete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transactions period month filters query and resets pagination', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository()..addSwiggyTransactions(22);

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const ActivityScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('All dates'), findsOneWidget);
    expect(repository.lastQuery?.startDate, isNull);
    expect(repository.lastQuery?.endDate, isNull);

    await tester.ensureVisible(find.byTooltip('Next page'));
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();

    expect(repository.lastQuery?.page, 1);

    await tester.tap(find.text('All dates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mar 2026').last);
    await tester.pumpAndSettle();

    expect(dateString(repository.lastQuery!.startDate!), '2026-03-01');
    expect(dateString(repository.lastQuery!.endDate!), '2026-03-31');
    expect(repository.lastQuery?.page, 0);
    expect(find.text('CRED Club'), findsNothing);
  });

  testWidgets('transaction route filters prepopulate controls and query', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();
    final router = _financeTestRouter(
      initialLocation:
          '/activity?categoryId=cat-food&merchant=Swiggy%20Instamart'
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
    expect(find.text('Mar 2026'), findsOneWidget);
    expect(repository.lastQuery?.categoryId, 'cat-food');
    expect(repository.lastQuery?.searchText, 'Swiggy Instamart');
    expect(repository.lastQuery?.merchantId, isNull);
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
          '/activity?categoryId=cat-food&merchant=Swiggy%20Instamart'
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
    expect(find.text('All dates'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.queryParameters, isEmpty);
    expect(repository.lastQuery?.categoryId, isNull);
    expect(repository.lastQuery?.searchText, '');
    expect(repository.lastQuery?.merchantId, isNull);
    expect(repository.lastQuery?.startDate, isNull);
    expect(repository.lastQuery?.endDate, isNull);
    expect(repository.lastQuery?.page, 0);
  });

  testWidgets('transactions show label chips and label route filters query', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();
    final router = _financeTestRouter(
      initialLocation: '/activity?labelId=label-reimburse',
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _financeRouterTestApp(repository: repository, router: router),
    );
    await tester.pumpAndSettle();

    expect(repository.lastQuery?.labelId, 'label-reimburse');
    expect(find.text('Reimburse'), findsWidgets);
    expect(find.text('Swiggy Instamart'), findsNothing);

    await tester.tap(find.byTooltip('Clear filters'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.queryParameters, isEmpty);
    expect(repository.lastQuery?.labelId, isNull);
    expect(find.text('Groceries'), findsWidgets);
    expect(find.text('Reimburse'), findsWidgets);
  });

  testWidgets(
    'transactions clear active label filter after selected label is deleted',
    (tester) async {
      final repository = _FakeFinanceRepository();
      final router = _financeTestRouter(
        initialLocation: '/activity?labelId=label-grocery',
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        _financeRouterTestApp(repository: repository, router: router),
      );
      await tester.pumpAndSettle();

      expect(repository.lastQuery?.labelId, 'label-grocery');
      expect(find.text('Swiggy Instamart'), findsWidgets);

      await repository.deleteHouseholdLabel(
        const LabelDeleteRequest(
          householdId: 'household-1',
          labelId: 'label-grocery',
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(
        _financeRouterTestApp(repository: repository, router: router),
      );
      await tester.pumpAndSettle();

      expect(repository.lastQuery?.labelId, isNull);
      expect(find.text('Amazon Shopping'), findsOneWidget);
      expect(find.text('CRED Club'), findsOneWidget);
    },
  );

  testWidgets(
    'transaction detail opens label editor and saves existing label',
    (tester) async {
      final repository = _FakeFinanceRepository();

      await tester.pumpWidget(
        _financeTestApp(repository: repository, child: const ActivityScreen()),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Amazon Shopping'));
      await tester.tap(find.text('Amazon Shopping'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Edit labels'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Edit labels'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Labels apply only to this transaction'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilterChip, 'Reimburse'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repository.labelSetRequests.single.transactionId, 'txn-2');
      expect(repository.labelSetRequests.single.labelIds, ['label-reimburse']);
      expect(repository.labelSetRequests.single.newLabelNames, isEmpty);
      expect(
        repository.transactions
            .where((transaction) => transaction.id == 'txn-1')
            .single
            .labels
            .map((label) => label.id),
        ['label-grocery'],
      );
    },
  );

  testWidgets('transaction label editor creates and removes labels', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const ActivityScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Swiggy Instamart').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Edit labels'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit labels'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Groceries'));
    await tester.enterText(find.widgetWithText(TextField, 'New label'), 'Trip');
    await tester.tap(find.byTooltip('Add label'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.labelSetRequests.single.transactionId, 'txn-1');
    expect(repository.labelSetRequests.single.labelIds, isEmpty);
    expect(repository.labelSetRequests.single.newLabelNames, ['Trip']);
    expect(
      repository.transactions
          .where((transaction) => transaction.id == 'txn-1')
          .single
          .labels
          .map((label) => label.name),
      ['Trip'],
    );
  });

  testWidgets('transaction list caps visible labels with overflow chip', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository()
      ..labels.addAll(const [
        LabelOption(id: 'label-family', name: 'Family'),
        LabelOption(id: 'label-tax', name: 'Tax'),
      ])
      ..transactions[0] = _copyTransaction(
        _FakeFinanceRepository().transactions[0],
        labels: const [
          LabelOption(id: 'label-grocery', name: 'Groceries'),
          LabelOption(id: 'label-family', name: 'Family'),
          LabelOption(id: 'label-tax', name: 'Tax'),
        ],
      );

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const ActivityScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsWidgets);
    expect(find.text('Family'), findsWidgets);
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('transactions source type filter separates UPI from cards', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const ActivityScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('CRED Club'), findsWidgets);
    expect(find.text('Swiggy Instamart'), findsWidgets);

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UPI').last);
    await tester.pumpAndSettle();

    expect(repository.lastQuery?.sourceAccountType, 'upi');
    expect(find.text('CRED Club'), findsWidgets);
    expect(find.text('Swiggy Instamart'), findsNothing);
  });

  testWidgets('activity charts render reports and refresh shared filters', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await _pumpActivityCharts(tester, repository);

    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Monthly Net Spend'), findsOneWidget);
    expect(find.text('Gross, Refunds, Net'), findsOneWidget);
    expect(find.text('Category Trend'), findsOneWidget);
    expect(find.text('Food'), findsWidgets);
    expect(find.text('Shopping'), findsWidgets);
    expect(repository.lastTrendQuery?.categoryId, isNull);
    expect(repository.lastTrendQuery?.startDate, isNull);
    expect(repository.lastTrendQuery?.endDate, isNull);
    expect(find.text('All dates'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();

    expect(repository.lastTrendQuery?.categoryId, 'cat-food');
    expect(find.text('Shopping'), findsNothing);

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

  testWidgets('activity charts period month composes with shared filters', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await _pumpActivityCharts(tester, repository);

    await tester.tap(find.text('All dates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mar 2026').last);
    await tester.pumpAndSettle();

    expect(dateString(repository.lastTrendQuery!.startDate!), '2026-03-01');
    expect(dateString(repository.lastTrendQuery!.endDate!), '2026-03-31');
    expect(find.text('June 2026'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();

    expect(repository.lastTrendQuery?.categoryId, 'cat-food');
    expect(dateString(repository.lastTrendQuery!.startDate!), '2026-03-01');
    expect(dateString(repository.lastTrendQuery!.endDate!), '2026-03-31');
    expect(find.text('Shopping'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('HDFC Credit Card - Ada').last);
    await tester.pumpAndSettle();

    expect(repository.lastTrendQuery?.sourceAccountId, 'source-1');
    expect(repository.lastTrendQuery?.categoryId, 'cat-food');
    expect(dateString(repository.lastTrendQuery!.startDate!), '2026-03-01');
    expect(dateString(repository.lastTrendQuery!.endDate!), '2026-03-31');
  });

  testWidgets('activity charts source type filter separates UPI reporting', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await _pumpActivityCharts(tester, repository);

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UPI').last);
    await tester.pumpAndSettle();

    expect(repository.lastTrendQuery?.sourceAccountType, 'upi');
    expect(find.text('Shopping'), findsWidgets);
    expect(find.text('Food'), findsNothing);
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
    expect(find.text("You're all caught up for now."), findsOneWidget);
    expect(find.text('Resolved 1 review items'), findsOneWidget);
  });

  testWidgets('merchant review metadata editor reuses merchant suggestions', (
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

    await tester.enterText(
      find.byKey(const ValueKey('metadata-merchant-group-field')),
      'swiggy',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('metadata-merchant-option-merchant-swiggy')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('metadata-merchant-option-merchant-swiggy')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.corrections, hasLength(1));
    expect(repository.corrections.single.transactionId, 'txn-review-1');
    expect(repository.corrections.single.reviewItemId, 'review-1');
    expect(repository.corrections.single.merchantGroup, 'Swiggy Instamart');
    expect(repository.corrections.single.categoryId, 'cat-food');
    expect(repository.corrections.single.subcategoryId, 'sub-food-delivery');
  });

  testWidgets('merchant review shows redesigned loading state', (tester) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(
        repository: repository,
        child: const MerchantReviewScreen(),
      ),
    );

    expect(find.text('Loading review queue'), findsOneWidget);
    expect(
      find.text('Checking review items and Gmail parser diagnostics.'),
      findsOneWidget,
    );
  });

  testWidgets('merchant review shows redesigned queue error state', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository()
      ..reviewQueueError = StateError('review unavailable');

    await tester.pumpWidget(
      _financeTestApp(
        repository: repository,
        child: const MerchantReviewScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review queue unavailable'), findsOneWidget);
    expect(find.textContaining('review unavailable'), findsOneWidget);
  });

  testWidgets('merchant review queue card fits 390px viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(
        repository: repository,
        child: const MerchantReviewScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('review-queue-card-review-1')),
      findsOneWidget,
    );
    expect(find.text('Open Reviews'), findsOneWidget);
    expect(find.text('Correction Data'), findsOneWidget);
    expect(find.text('Needs Attention'), findsOneWidget);
    expect(find.text('Low Confidence'), findsOneWidget);
    expect(find.text('Resolve'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('merchant review hides Gmail parse failures card when empty', (
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

    expect(find.text('Gmail parse failures'), findsNothing);
    expect(find.text('AMZN MKTP IN'), findsOneWidget);
  });

  testWidgets('merchant review shows Gmail parse failures card', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository()
      ..gmailParseFailures.add(_gmailParseFailure());

    await tester.pumpWidget(
      _financeTestApp(
        repository: repository,
        child: const MerchantReviewScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gmail parse failures'), findsOneWidget);
    expect(find.text('1 recent failure'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('AMZN MKTP IN'), findsOneWidget);
  });

  testWidgets(
    'merchant review shows Gmail parse failures without queue items',
    (tester) async {
      final repository = _FakeFinanceRepository()
        ..reviewItems.clear()
        ..gmailParseFailures.add(_gmailParseFailure());

      await tester.pumpWidget(
        _financeTestApp(
          repository: repository,
          child: const MerchantReviewScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gmail parse failures'), findsOneWidget);
      expect(find.text('No review items'), findsNothing);
    },
  );

  testWidgets('merchant review renders Gmail parse failure details', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository()
      ..gmailParseFailures.add(_gmailParseFailure());

    await tester.pumpWidget(
      _financeTestApp(
        repository: repository,
        child: const MerchantReviewScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('A payment was made using your Credit Card'),
      findsOneWidget,
    );
    expect(find.text('Credit card'), findsOneWidget);
    expect(find.text('HDFC debit pattern not matched'), findsOneWidget);
    expect(find.text('hdfc_credit_card_debit 1.0.0'), findsOneWidget);
    expect(find.text('Received 2026-06-08 10:30'), findsOneWidget);
    expect(find.text('Message gmail-failure-message-1'), findsOneWidget);
    expect(find.text('Thread gmail-failure-thread-1'), findsOneWidget);
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
      _financeTestApp(repository: repository, child: const ActivityScreen()),
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

  testWidgets(
    'transaction metadata editor merchant exact match saves canonical name',
    (tester) async {
      final repository = _FakeFinanceRepository();

      await tester.pumpWidget(
        _financeTestApp(repository: repository, child: const ActivityScreen()),
      );
      await tester.pumpAndSettle();
      await _openTransactionMetadataEditor(tester, 'Swiggy Instamart');

      await tester.enterText(
        find.byKey(const ValueKey('metadata-merchant-group-field')),
        'swiggy instamart',
      );
      await _tapMetadataSave(tester);

      expect(find.text('Use existing merchant?'), findsNothing);
      expect(repository.corrections, hasLength(1));
      expect(repository.corrections.single.merchantGroup, 'Swiggy Instamart');
    },
  );

  testWidgets(
    'transaction metadata editor merchant close match can use existing name',
    (tester) async {
      final repository = _FakeFinanceRepository();

      await tester.pumpWidget(
        _financeTestApp(repository: repository, child: const ActivityScreen()),
      );
      await tester.pumpAndSettle();
      await _openTransactionMetadataEditor(tester, 'Swiggy Instamart');

      await tester.enterText(
        find.byKey(const ValueKey('metadata-merchant-group-field')),
        'Swigy Instamart',
      );
      await _tapMetadataSave(tester);

      expect(find.text('Use existing merchant?'), findsOneWidget);
      expect(repository.corrections, isEmpty);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Use Swiggy Instamart'),
      );
      await tester.pumpAndSettle();

      expect(repository.corrections, hasLength(1));
      expect(repository.corrections.single.merchantGroup, 'Swiggy Instamart');
    },
  );

  testWidgets(
    'transaction metadata editor merchant close match keeps new name once',
    (tester) async {
      final repository = _FakeFinanceRepository()
        ..metadataCorrectionFailuresRemaining = 1;

      await tester.pumpWidget(
        _financeTestApp(repository: repository, child: const ActivityScreen()),
      );
      await tester.pumpAndSettle();
      await _openTransactionMetadataEditor(tester, 'Swiggy Instamart');

      await tester.enterText(
        find.byKey(const ValueKey('metadata-merchant-group-field')),
        'Swigy Instamart',
      );
      await _tapMetadataSave(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Keep new name'));
      await tester.pumpAndSettle();

      expect(repository.corrections, isEmpty);
      expect(find.text('Use existing merchant?'), findsNothing);
      expect(find.textContaining('save unavailable'), findsOneWidget);

      await _tapMetadataSave(tester);

      expect(find.text('Use existing merchant?'), findsNothing);
      expect(repository.corrections, hasLength(1));
      expect(repository.corrections.single.merchantGroup, 'Swigy Instamart');
    },
  );

  testWidgets(
    'transaction metadata editor merchant close match cancel keeps editing',
    (tester) async {
      final repository = _FakeFinanceRepository();

      await tester.pumpWidget(
        _financeTestApp(repository: repository, child: const ActivityScreen()),
      );
      await tester.pumpAndSettle();
      await _openTransactionMetadataEditor(tester, 'Swiggy Instamart');

      await tester.enterText(
        find.byKey(const ValueKey('metadata-merchant-group-field')),
        'Amazon Shoping',
      );
      await _tapMetadataSave(tester);

      expect(find.text('Use existing merchant?'), findsOneWidget);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(repository.corrections, isEmpty);
      expect(find.text('Use existing merchant?'), findsNothing);
      expect(
        find.byKey(const ValueKey('metadata-editor-card')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'transaction metadata editor merchant non-match saves without prompt',
    (tester) async {
      final repository = _FakeFinanceRepository();

      await tester.pumpWidget(
        _financeTestApp(repository: repository, child: const ActivityScreen()),
      );
      await tester.pumpAndSettle();
      await _openTransactionMetadataEditor(tester, 'Swiggy Instamart');

      await tester.enterText(
        find.byKey(const ValueKey('metadata-merchant-group-field')),
        'Amazon Prime',
      );
      await _tapMetadataSave(tester);

      expect(find.text('Use existing merchant?'), findsNothing);
      expect(repository.corrections, hasLength(1));
      expect(repository.corrections.single.merchantGroup, 'Amazon Prime');
    },
  );

  testWidgets(
    'transaction metadata editor autocomplete selects merchant taxonomy',
    (tester) async {
      final repository = _FakeFinanceRepository();

      await tester.pumpWidget(
        _financeTestApp(repository: repository, child: const ActivityScreen()),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Amazon Shopping'));
      await tester.tap(find.text('Amazon Shopping'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Edit'));
      await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('metadata-merchant-group-field')),
        'ama',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('metadata-merchant-option-merchant-amazon')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('metadata-merchant-option-merchant-amazon')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.corrections, hasLength(1));
      expect(repository.corrections.single.transactionId, 'txn-2');
      expect(repository.corrections.single.reviewItemId, isNull);
      expect(repository.corrections.single.merchantGroup, 'Amazon Shopping');
      expect(repository.corrections.single.categoryId, 'cat-shopping');
      expect(repository.corrections.single.subcategoryId, 'sub-marketplace');
    },
  );

  testWidgets('transaction metadata suggestion failure keeps form values', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository()
      ..metadataSuggestionError = StateError('AI unavailable');

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const ActivityScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Swiggy Instamart'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Edit'));
    await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Swiggy Manual');
    await tester.ensureVisible(find.byType(TextFormField).last);
    await tester.enterText(
      find.byType(TextFormField).last,
      'Keep manual correction.',
    );

    await tester.tap(find.text('Suggest'));
    await tester.pumpAndSettle();

    expect(repository.metadataSuggestionRequests, hasLength(1));
    expect(find.text('Swiggy Manual'), findsOneWidget);
    expect(find.text('Keep manual correction.'), findsOneWidget);
    expect(find.text('Bad state: AI unavailable'), findsOneWidget);
    expect(repository.corrections, isEmpty);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.corrections, hasLength(1));
    expect(repository.corrections.single.merchantGroup, 'Swiggy Manual');
    expect(repository.corrections.single.notes, 'Keep manual correction.');
  });

  testWidgets('transaction metadata editor fits narrow dark viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(
        repository: repository,
        theme: AppTheme.dark(),
        child: const ActivityScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Swiggy Instamart').first);
    await tester.tap(find.text('Swiggy Instamart').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Edit'));
    await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
    await tester.pumpAndSettle();

    final modal = find.byKey(const ValueKey('metadata-editor-card'));
    expect(modal, findsOneWidget);
    expect(
      find.descendant(of: modal, matching: find.text('Edit metadata')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: modal, matching: find.text('Merchant group')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: modal, matching: find.text('Create category')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: modal, matching: find.text('Suggest')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: modal, matching: find.text('Cancel')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: modal, matching: find.text('Save')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction metadata editor stays usable above keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const ActivityScreen()),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Swiggy Instamart').first);
    await tester.tap(find.text('Swiggy Instamart').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Edit'));
    await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();

    final modal = find.byKey(const ValueKey('metadata-editor-card'));
    expect(modal, findsOneWidget);
    expect(tester.getSize(modal).height, greaterThanOrEqualTo(490));

    final keyboardTop = tester.view.physicalSize.height - 320;
    expect(tester.getBottomRight(modal).dy, lessThanOrEqualTo(keyboardTop + 1));
    expect(
      find.descendant(of: modal, matching: find.text('Merchant group')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: modal, matching: find.text('Save')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings theme selector updates and persists theme mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeFinanceRepository();
    final themeStore = _FakeThemeModeStore(initialMode: AppThemeMode.system);

    await tester.pumpWidget(
      _financeThemeTestApp(
        repository: repository,
        themeStore: themeStore,
        child: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Account & Runtime'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System Environment'), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(themeStore.savedModes, [AppThemeMode.dark]);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    expect(themeStore.savedModes, [AppThemeMode.dark, AppThemeMode.light]);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
  });

  testWidgets('settings creates category and subcategory', (tester) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    await _expandSettingsSection(tester, 'Categories');
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
    await _selectSettingsCategory(tester, 'Travel');

    expect(find.text('Travel'), findsWidgets);
    expect(find.text('Flights'), findsOneWidget);
    expect(find.text('Created Travel'), findsOneWidget);
  });

  testWidgets('settings creates, renames, and deletes labels with impact', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    await _expandSettingsSection(tester, 'Labels');
    expect(find.text('Groceries'), findsWidgets);
    expect(find.text('1 transaction - last used 2026-03-12'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Create').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('label-name-field')),
      'Office',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create').last);
    await tester.pumpAndSettle();

    expect(repository.labelCreateRequests, hasLength(1));
    expect(repository.labelCreateRequests.single.name, 'Office');
    expect(find.text('Office'), findsOneWidget);
    expect(find.text('Created Office'), findsOneWidget);

    await tester.tap(find.byTooltip('Rename label').at(1));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('label-name-field')),
      'Work reimburse',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.labelRenameRequests, hasLength(1));
    expect(repository.labelRenameRequests.single.name, 'Work reimburse');
    expect(find.text('Work reimburse'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete label').first);
    await tester.pumpAndSettle();

    expect(find.text('Delete label'), findsOneWidget);
    expect(find.text('Groceries'), findsWidgets);
    expect(find.text('1 transaction'), findsOneWidget);
    expect(find.textContaining('Transactions stay intact'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository.labelDeleteRequests, hasLength(1));
    expect(repository.labelDeleteRequests.single.labelId, 'label-grocery');
    expect(repository.transactions, hasLength(3));
    expect(
      repository.transactions
          .singleWhere((transaction) => transaction.id == 'txn-1')
          .labels,
      isEmpty,
    );
    expect(
      repository.transactions
          .singleWhere((transaction) => transaction.id == 'txn-1')
          .categoryId,
      'cat-food',
    );
  });

  testWidgets('settings label manager fits long names in a narrow viewport', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository()
      ..labels.add(
        const LabelOption(
          id: 'label-long',
          name: 'Quarterly reimbursement and family settlement planning',
        ),
      );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Labels'));
    expect(find.text('Labels'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings category manager shows usage preview', (tester) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    await _expandSettingsSection(tester, 'Categories');
    await _selectSettingsCategory(tester, 'Food');

    expect(find.text('Food'), findsWidgets);
    expect(find.text('Delivery'), findsWidgets);
    expect(find.text('1 transaction - INR 1,200'), findsWidgets);
    expect(find.text('Swiggy Instamart'), findsOneWidget);
    expect(find.text('2026-03-12 - Food - Delivery'), findsOneWidget);
  });

  testWidgets('settings category detail opens filtered transactions', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();
    final router = _financeTestRouter(
      initialLocation: SettingsScreen.routePath,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _financeRouterTestApp(repository: repository, router: router),
    );
    await tester.pumpAndSettle();

    await _expandSettingsSection(tester, 'Categories');
    await _selectSettingsCategory(tester, 'Food');

    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'View transactions'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'View transactions'));
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/activity');
    expect(uri.queryParameters['categoryId'], 'cat-food');
    expect(repository.lastQuery?.categoryId, 'cat-food');
    expect(repository.lastQuery?.subcategoryId, isNull);
    expect(repository.lastQuery?.startDate, isNull);
    expect(repository.lastQuery?.endDate, isNull);
    expect(repository.lastQuery?.page, 0);
  });

  testWidgets('settings category manager fits a narrow viewport', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    await _expandSettingsSection(tester, 'Categories');
    await _selectSettingsCategory(tester, 'Food');

    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'View transactions'),
    );
    expect(
      find.widgetWithText(FilledButton, 'View transactions'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings edits category taxonomy without replacing ids', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    await _expandSettingsSection(tester, 'Categories');
    await _selectSettingsCategory(tester, 'Food');

    await tester.ensureVisible(find.byTooltip('Edit category').first);
    await tester.tap(find.byTooltip('Edit category').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('category-taxonomy-name')),
      'Groceries',
    );
    await tester.enterText(
      find.byKey(const ValueKey('subcategory-taxonomy-sub-food-delivery')),
      'Delivery & Grocery',
    );
    await tester.tap(find.text('Add subcategory'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Staples');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.taxonomyUpdates, hasLength(1));
    expect(repository.taxonomyUpdates.single.categoryId, 'cat-food');
    expect(repository.taxonomyUpdates.single.categoryName, 'Groceries');
    expect(
      repository.taxonomyUpdates.single.subcategories.first.id,
      'sub-food-delivery',
    );
    expect(
      repository.taxonomyUpdates.single.subcategories.first.name,
      'Delivery & Grocery',
    );
    expect(repository.taxonomyUpdates.single.subcategories.last.id, isNull);
    expect(
      repository.taxonomyUpdates.single.subcategories.last.name,
      'Staples',
    );
    expect(find.text('Groceries'), findsWidgets);
    expect(find.text('Delivery & Grocery'), findsWidgets);
    expect(find.text('Staples'), findsWidgets);
    expect(find.text('Updated Groceries'), findsOneWidget);
  });

  testWidgets('settings deletes subcategory after impact confirmation', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    await _expandSettingsSection(tester, 'Categories');
    await _selectSettingsCategory(tester, 'Food');

    await tester.ensureVisible(find.byTooltip('Delete subcategory').first);
    await tester.tap(find.byTooltip('Delete subcategory').first);
    await tester.pumpAndSettle();

    expect(find.text('Delete subcategory'), findsOneWidget);
    expect(find.text('Delivery'), findsWidgets);
    expect(find.text('1 transaction'), findsOneWidget);
    expect(find.text('1 active rule'), findsOneWidget);
    expect(find.text('0 caps'), findsOneWidget);
    expect(find.text('Swiggy Instamart'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository.deletedSubcategoryRequests, hasLength(1));
    expect(
      repository.deletedSubcategoryRequests.single.subcategoryId,
      'sub-food-delivery',
    );
    expect(
      repository.transactions
          .singleWhere((transaction) => transaction.id == 'txn-1')
          .categoryId,
      'cat-food',
    );
    expect(
      repository.transactions
          .singleWhere((transaction) => transaction.id == 'txn-1')
          .subcategoryId,
      isNull,
    );
    expect(
      find.text('Deleted Delivery; requeued 1 transactions'),
      findsOneWidget,
    );
  });

  testWidgets('settings deletes category after impact confirmation', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    await _expandSettingsSection(tester, 'Categories');

    await tester.ensureVisible(find.byTooltip('Delete category').last);
    await tester.tap(find.byTooltip('Delete category').last);
    await tester.pumpAndSettle();

    expect(find.text('Delete category'), findsOneWidget);
    expect(find.text('Shopping'), findsWidgets);
    expect(find.text('1 transaction'), findsOneWidget);
    expect(find.text('1 active rule'), findsOneWidget);
    expect(find.text('1 cap'), findsOneWidget);
    expect(find.text('CRED Club'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository.deletedCategoryRequests, hasLength(1));
    expect(
      repository.deletedCategoryRequests.single.categoryId,
      'cat-shopping',
    );
    expect(
      repository.transactions
          .singleWhere((transaction) => transaction.id == 'txn-3')
          .categoryId,
      isNull,
    );
    expect(
      repository.transactions
          .singleWhere((transaction) => transaction.id == 'txn-3')
          .subcategoryId,
      isNull,
    );
    expect(
      find.text('Deleted Shopping; requeued 1 transactions'),
      findsOneWidget,
    );
  });

  testWidgets('settings merges categories after explicit subcategory mapping', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    await _expandSettingsSection(tester, 'Categories');

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Merge'));
    await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
    await tester.pumpAndSettle();

    expect(find.text('Merge categories'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );

    await tester.tap(
      find.byKey(const ValueKey('category-merge-source-cat-shopping')),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 transaction'), findsOneWidget);
    expect(find.text('1 active rule'), findsOneWidget);
    expect(find.text('1 cap'), findsOneWidget);
    expect(find.text('CRED Club'), findsWidgets);
    expect(find.text('Map every source subcategory.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );

    final marketplaceMapping = find.byKey(
      const ValueKey('category-merge-map-cat-food-sub-marketplace'),
    );
    await tester.ensureVisible(marketplaceMapping);
    await tester.pumpAndSettle();
    await tester.tap(marketplaceMapping);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New subcategory').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('category-merge-new-sub-marketplace')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('category-merge-new-sub-marketplace')),
      'delivery',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Duplicate destination subcategory names are not allowed.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const ValueKey('category-merge-new-sub-marketplace')),
      'Online Shopping',
    );
    await tester.enterText(
      find.byKey(const ValueKey('category-merge-name')),
      'Food & Dining',
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.mergeRequests, hasLength(1));
    expect(repository.mergeRequests.single.destinationCategoryId, 'cat-food');
    expect(
      repository.mergeRequests.single.destinationCategoryName,
      'Food & Dining',
    );
    expect(repository.mergeRequests.single.sourceCategoryIds, ['cat-shopping']);
    expect(
      repository
          .mergeRequests
          .single
          .subcategoryMappings
          .single
          .sourceSubcategoryId,
      'sub-marketplace',
    );
    expect(
      repository
          .mergeRequests
          .single
          .subcategoryMappings
          .single
          .destinationSubcategoryName,
      'Online Shopping',
    );
    expect(
      repository.categories.map((category) => category.name),
      isNot(contains('Shopping')),
    );
    await _selectSettingsCategory(tester, 'Food & Dining');

    expect(find.text('Food & Dining'), findsWidgets);
    expect(find.text('Online Shopping'), findsWidgets);
    expect(
      repository.transactions
          .singleWhere((transaction) => transaction.id == 'txn-3')
          .categoryId,
      'cat-food',
    );
    expect(
      repository.transactions
          .singleWhere((transaction) => transaction.id == 'txn-3')
          .subcategoryName,
      'Online Shopping',
    );
    expect(
      find.text('Merged into Food & Dining; moved 1 transactions'),
      findsOneWidget,
    );
  });

  testWidgets('settings merchant group manager renders usage and renames', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    await _expandSettingsSection(tester, 'Merchant groups');

    expect(find.text('Merchant groups'), findsOneWidget);
    expect(find.text('Swiggy Instamart'), findsOneWidget);
    expect(find.text('Food / Delivery'), findsOneWidget);
    expect(
      find.text('1 transaction - INR 1,200 - last 2026-03-12'),
      findsOneWidget,
    );
    expect(find.text('1 alias'), findsWidgets);
    expect(find.text('1 active rule'), findsWidgets);

    await tester.tap(find.byTooltip('Rename merchant group').at(1));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('merchant-group-name-field')),
      'Swiggy Market',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.merchantGroupRenameRequests, hasLength(1));
    expect(
      repository.merchantGroupRenameRequests.single.merchantId,
      'merchant-swiggy',
    );
    expect(
      repository.merchantGroupRenameRequests.single.displayName,
      'Swiggy Market',
    );
    expect(find.text('Swiggy Market'), findsOneWidget);
    expect(find.text('Renamed Swiggy Market'), findsOneWidget);
  });

  testWidgets(
    'settings merchant group merge validates and submits preserve strategy',
    (tester) async {
      final repository = _FakeFinanceRepository();

      await tester.pumpWidget(
        _financeTestApp(repository: repository, child: const SettingsScreen()),
      );
      await tester.pumpAndSettle();

      await _expandSettingsSection(tester, 'Merchant groups');
      await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
      await tester.pumpAndSettle();

      expect(find.text('Merge merchant groups'), findsOneWidget);
      expect(
        find.text('Choose at least one source merchant group.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );

      await tester.tap(
        find.byKey(
          const ValueKey('merchant-group-merge-source-merchant-swiggy'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 transaction'), findsWidgets);
      expect(find.text('INR 1,200'), findsOneWidget);
      expect(find.text('Preserve categories'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNotNull,
      );

      await tester.enterText(
        find.byKey(const ValueKey('merchant-group-merge-name')),
        'Amazon Collective',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repository.merchantGroupMergeRequests, hasLength(1));
      expect(
        repository.merchantGroupMergeRequests.single.destinationMerchantId,
        'merchant-amazon',
      );
      expect(
        repository.merchantGroupMergeRequests.single.destinationDisplayName,
        'Amazon Collective',
      );
      expect(repository.merchantGroupMergeRequests.single.sourceMerchantIds, [
        'merchant-swiggy',
      ]);
      expect(
        repository.merchantGroupMergeRequests.single.categoryStrategy,
        MerchantGroupMergeCategoryStrategy.preserve,
      );
      expect(
        repository.transactions
            .singleWhere((transaction) => transaction.id == 'txn-1')
            .categoryId,
        'cat-food',
      );
      expect(
        find.text('Merged into Amazon Collective; moved 1 transaction'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'settings merchant group merge disables destination strategy without taxonomy',
    (tester) async {
      final repository = _FakeFinanceRepository();

      await tester.pumpWidget(
        _financeTestApp(repository: repository, child: const SettingsScreen()),
      );
      await tester.pumpAndSettle();

      await _expandSettingsSection(tester, 'Merchant groups');
      await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('merchant-group-merge-destination')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uber').last);
      await tester.pumpAndSettle();

      final strategySelector = tester
          .widget<SegmentedButton<MerchantGroupMergeCategoryStrategy>>(
            find.byKey(const ValueKey('merchant-group-merge-strategy')),
          );
      expect(strategySelector.selected, {
        MerchantGroupMergeCategoryStrategy.preserve,
      });
      expect(strategySelector.segments.last.enabled, isFalse);
      expect(find.text('Uber has no category to apply.'), findsOneWidget);
    },
  );

  testWidgets('settings merchant group saves refresh dependent providers', (
    tester,
  ) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(
        repository: repository,
        child: const Stack(
          children: [SettingsScreen(), _MerchantGroupRefreshProbe()],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final initialMerchantGroupFetches =
        repository.merchantGroupManagerFetchCount;
    final initialMerchantFetches = repository.merchantFetchCount;
    final initialTransactionFetches = repository.transactionFetchCount;
    final initialTrendFetches = repository.trendReportFetchCount;
    final initialDashboardFetches = repository.dashboardFetchCount;
    final initialReviewFetches = repository.reviewQueueFetchCount;

    await _expandSettingsSection(tester, 'Merchant groups');
    await tester.tap(find.byTooltip('Rename merchant group').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('merchant-group-name-field')),
      'Amazon Mall',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      repository.merchantGroupManagerFetchCount,
      greaterThan(initialMerchantGroupFetches),
    );
    expect(repository.merchantFetchCount, greaterThan(initialMerchantFetches));
    expect(
      repository.transactionFetchCount,
      greaterThan(initialTransactionFetches),
    );
    expect(repository.trendReportFetchCount, greaterThan(initialTrendFetches));
    expect(
      repository.dashboardFetchCount,
      greaterThan(initialDashboardFetches),
    );
    expect(repository.reviewQueueFetchCount, greaterThan(initialReviewFetches));
  });

  testWidgets(
    'settings merchant group manager fits long names in a narrow viewport',
    (tester) async {
      final repository = _FakeFinanceRepository()
        ..merchants.add(
          const MerchantOption(
            id: 'merchant-long',
            displayName:
                'International marketplace subscription groceries and utilities',
            categoryId: 'cat-shopping',
            subcategoryId: 'sub-marketplace',
          ),
        )
        ..merchantAliasCounts['merchant-long'] = 12
        ..transactions.add(
          FinanceTransaction(
            id: 'txn-long-merchant',
            transactionDate: DateTime(2026, 3, 21),
            statementMerchant: 'LONG MARKETPLACE MERCHANT',
            merchantId: 'merchant-long',
            merchantName:
                'International marketplace subscription groceries and utilities',
            categoryId: 'cat-shopping',
            categoryName: 'Shopping',
            subcategoryId: 'sub-marketplace',
            subcategoryName: 'Marketplace',
            sourceAccountId: 'source-1',
            transactionType: 'debit_spend',
            amount: 999,
            grossSpend: 999,
            refundAmount: 0,
            netExpense: 999,
            currencyCode: 'INR',
            confidence: 'high',
          ),
        );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _financeTestApp(repository: repository, child: const SettingsScreen()),
      );
      await tester.pumpAndSettle();

      await _expandSettingsSection(tester, 'Merchant groups');
      await tester.ensureVisible(
        find.text(
          'International marketplace subscription groceries and utilities',
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings shows Gmail connector status', (tester) async {
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gmail Importer'), findsOneWidget);
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

    expect(find.text('AI Core'), findsOneWidget);
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

  testWidgets('ask expenses renders redesigned states in light and dark', (
    tester,
  ) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final repository = _FakeFinanceRepository();

      await tester.pumpWidget(
        _financeTestApp(
          repository: repository,
          theme: theme,
          child: const AiScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Question'), findsOneWidget);
      expect(find.text('Ask about your expenses'), findsOneWidget);
      expect(find.text('AI budget'), findsOneWidget);
      expect(find.text('Monthly cap'), findsOneWidget);
      expect(find.text('Free tier'), findsOneWidget);
      expect(find.text('Search off'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'What did I spend on food in March?',
      );
      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();

      expect(find.text('Answer'), findsOneWidget);
      expect(
        find.text('Food spend was INR 42,000 in Mar 2026.'),
        findsOneWidget,
      );
      expect(find.text('18 input tokens'), findsOneWidget);
      expect(find.text('9 output tokens'), findsOneWidget);
    }
  });

  testWidgets('ask expenses shows redesigned error state', (tester) async {
    final repository = _FakeFinanceRepository()
      ..expenseQuestionError = StateError('AI offline');

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
    expect(find.text('Ask failed'), findsOneWidget);
    expect(find.textContaining('AI offline'), findsWidgets);
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

  testWidgets('vaults create entries and update target progress at 390px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeFinanceRepository();

    await tester.pumpWidget(
      _financeTestApp(repository: repository, child: const PiggyBanksScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vaults'), findsWidgets);
    expect(find.text('Create Vault'), findsOneWidget);
    expect(find.text('No vaults yet'), findsOneWidget);

    await tester.ensureVisible(find.text('Create vault'));
    await tester.tap(find.text('Create vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Vacation');
    await tester.enterText(find.byType(TextFormField).at(1), 'Flights');
    await tester.enterText(find.byType(TextFormField).at(2), '1000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.piggyBanks, hasLength(1));
    expect(find.text('Vacation'), findsWidgets);
    expect(find.text('Current balance'), findsOneWidget);
    expect(find.text('Target INR 1,000'), findsWidgets);
    expect(find.text('No entries yet'), findsOneWidget);

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
  Key? appKey,
  HouseholdContext householdContext = _householdContext,
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode themeMode = ThemeMode.light,
}) {
  return ProviderScope(
    overrides: [
      appBootstrapProvider.overrideWithValue(
        const AppBootstrap(supabaseStatus: SupabaseStatus.ready),
      ),
      householdContextProvider.overrideWithValue(AsyncData(householdContext)),
      financeRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      key: appKey,
      theme: theme ?? AppTheme.light(),
      darkTheme: darkTheme ?? AppTheme.dark(),
      themeMode: themeMode,
      home: Scaffold(body: child),
    ),
  );
}

class _MerchantGroupRefreshProbe extends ConsumerWidget {
  const _MerchantGroupRefreshProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const householdId = 'household-1';
    ref.watch(merchantOptionsProvider(householdId));
    ref.watch(transactionsProvider(TransactionQuery(householdId: householdId)));
    ref.watch(trendReportProvider(TrendQuery(householdId: householdId)));
    ref.watch(
      dashboardSnapshotProvider(FinanceMonthRequest(householdId: householdId)),
    );
    ref.watch(merchantReviewQueueProvider(householdId));

    return const SizedBox.shrink();
  }
}

HouseholdContext _householdContextWithRole(String memberRole) {
  return HouseholdContext(
    profile: _householdContext.profile,
    household: _householdContext.household,
    memberRole: memberRole,
  );
}

Future<void> _openTransactionDetail(
  WidgetTester tester,
  String merchantName,
) async {
  await tester.ensureVisible(find.text(merchantName).first);
  await tester.tap(find.text(merchantName).first);
  await tester.pumpAndSettle();
}

Future<void> _openTransactionMetadataEditor(
  WidgetTester tester,
  String merchantName,
) async {
  await _openTransactionDetail(tester, merchantName);
  final editButton = find.widgetWithText(FilledButton, 'Edit');
  await tester.ensureVisible(editButton);
  await tester.tap(editButton);
  await tester.pumpAndSettle();
}

Future<void> _tapMetadataSave(WidgetTester tester) async {
  final saveButton = find.byKey(const ValueKey('metadata-save-button'));
  await tester.ensureVisible(saveButton);
  await tester.tap(saveButton);
  await tester.pumpAndSettle();
}

Future<void> _tapTransactionDeleteAction(WidgetTester tester) async {
  final deleteButton = find.widgetWithText(FilledButton, 'Delete');
  await tester.ensureVisible(deleteButton);
  await tester.pumpAndSettle();
  await tester.tap(deleteButton);
  await tester.pumpAndSettle();
}

Future<void> _expandSettingsSection(
  WidgetTester tester,
  String sectionTitle,
) async {
  final section = find.text(sectionTitle).first;
  await tester.ensureVisible(section);
  await tester.pumpAndSettle();
  await tester.tap(section);
  await tester.pumpAndSettle();
}

Future<void> _selectSettingsCategory(
  WidgetTester tester,
  String categoryName,
) async {
  final category = find.text(categoryName).first;
  await tester.ensureVisible(category);
  await tester.pumpAndSettle();
  await tester.tap(category);
  await tester.pumpAndSettle();
}

Future<void> _pumpRedesignSurface(
  WidgetTester tester,
  _RedesignQaScenario scenario, {
  required _FakeFinanceRepository repository,
  required Widget child,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = scenario.size;
  tester.platformDispatcher.platformBrightnessTestValue =
      scenario.platformBrightness;

  await tester.pumpWidget(
    _financeTestApp(
      repository: repository,
      appKey: UniqueKey(),
      themeMode: scenario.themeMode,
      child: child,
    ),
  );
  await tester.pumpAndSettle();

  expect(tester.takeException(), isNull, reason: scenario.label);
}

final class _RedesignQaScenario {
  const _RedesignQaScenario(
    this.label,
    this.size,
    this.themeMode,
    this.platformBrightness,
  );

  final String label;
  final Size size;
  final ThemeMode themeMode;
  final Brightness platformBrightness;
}

Widget _financeThemeTestApp({
  required _FakeFinanceRepository repository,
  required _FakeThemeModeStore themeStore,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      appBootstrapProvider.overrideWithValue(
        const AppBootstrap(supabaseStatus: SupabaseStatus.ready),
      ),
      householdContextProvider.overrideWithValue(AsyncData(_householdContext)),
      financeRepositoryProvider.overrideWithValue(repository),
      appThemeModeStoreProvider.overrideWithValue(themeStore),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        return MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ref.watch(themeModeProvider),
          home: Scaffold(body: child),
        );
      },
    ),
  );
}

Future<void> _pumpActivityCharts(
  WidgetTester tester,
  _FakeFinanceRepository repository,
) async {
  await tester.pumpWidget(
    _financeTestApp(repository: repository, child: const ActivityScreen()),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Charts'));
  await tester.pumpAndSettle();
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
        path: ActivityScreen.routePath,
        builder: (_, state) => Scaffold(
          body: ActivityScreen(
            initialFilters: ActivityScreen.initialFiltersFromUri(state.uri),
          ),
        ),
      ),
      GoRoute(
        path: SettingsScreen.routePath,
        builder: (_, _) => const Scaffold(body: SettingsScreen()),
      ),
    ],
  );
}

GoRouter _shellTestRouter({
  String initialLocation = DashboardScreen.routePath,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(
            location: state.uri.path,
            householdContext: _householdContext,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: DashboardScreen.routePath,
            builder: (context, _) => Center(
              child: IconButton(
                tooltip: 'Open settings',
                onPressed: () => context.go(SettingsScreen.routePath),
                icon: const Icon(Icons.settings_outlined),
              ),
            ),
          ),
          GoRoute(
            path: ActivityScreen.routePath,
            builder: (_, _) => const Center(child: Text('Activity shell')),
          ),
          GoRoute(
            path: MerchantReviewScreen.routePath,
            builder: (_, _) => const Center(child: Text('Review shell')),
          ),
          GoRoute(
            path: PiggyBanksScreen.routePath,
            builder: (_, _) => const Center(child: Text('Vaults shell')),
          ),
          GoRoute(
            path: SettingsScreen.routePath,
            builder: (_, _) => const Center(child: Text('Focused settings')),
          ),
        ],
      ),
    ],
  );
}

Future<void> _openAddCapSheet(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Add cap'));
  await tester.tap(find.text('Add cap'));
  await tester.pumpAndSettle();
}

Future<void> _fillCapNameAndAmount(
  WidgetTester tester, {
  required String name,
  required String amount,
}) async {
  await tester.enterText(find.byKey(const ValueKey('cap-name-field')), name);
  await tester.enterText(
    find.byKey(const ValueKey('cap-amount-field')),
    amount,
  );
  await tester.pumpAndSettle();
}

Future<void> _tapTargetChip(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(FilterChip, label);
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _tapCarryForwardSwitch(WidgetTester tester) async {
  final toggle = find.byKey(const ValueKey('cap-carry-forward-switch'));
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

Future<void> _saveCapSheet(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Save'));
  await tester.pumpAndSettle();
}

SwitchListTile _capCarryForwardSwitch(WidgetTester tester) {
  return tester.widget<SwitchListTile>(
    find.byKey(const ValueKey('cap-carry-forward-switch')),
  );
}

FilledButton _capSaveButton(WidgetTester tester) {
  return tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
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

final class _FakeThemeModeStore implements AppThemeModeStore {
  _FakeThemeModeStore({required AppThemeMode initialMode})
    : _storedMode = initialMode;

  AppThemeMode _storedMode;
  final savedModes = <AppThemeMode>[];

  @override
  Future<AppThemeMode> load() async => _storedMode;

  @override
  Future<void> save(AppThemeMode mode) async {
    savedModes.add(mode);
    _storedMode = mode;
  }
}

final class _FakeFinanceRepository implements FinanceRepository {
  final monthlyCapUpsertRequests = <MonthlyCapUpsertRequest>[];
  final monthlyCapDeleteRequests = <MonthlyCapDeleteRequest>[];
  final corrections = <TransactionMetadataCorrectionRequest>[];
  final createdCategoryRequests = <CategoryCreationRequest>[];
  final taxonomyUpdates = <CategoryTaxonomyUpdateRequest>[];
  final deletedSubcategoryRequests = <TaxonomySubcategoryDeleteRequest>[];
  final deletedCategoryRequests = <TaxonomyCategoryDeleteRequest>[];
  final mergeRequests = <CategoryMergeRequest>[];
  final merchantGroupRenameRequests = <MerchantGroupRenameRequest>[];
  final merchantGroupMergeRequests = <MerchantGroupMergeRequest>[];
  final labelCreateRequests = <LabelCreateRequest>[];
  final labelSetRequests = <TransactionLabelsSetRequest>[];
  final labelRenameRequests = <LabelRenameRequest>[];
  final labelDeleteRequests = <LabelDeleteRequest>[];
  final transactionDeleteRequests = <TransactionDeleteRequest>[];
  final expenseQuestions = <ExpenseQuestionRequest>[];
  final metadataSuggestionRequests = <TransactionMetadataSuggestionRequest>[];
  final piggyBanks = <PiggyBankSummary>[];
  final piggyEntries = <PiggyBankEntry>[];
  Object? reviewQueueError;
  Object? gmailParseFailuresError;
  Object? transactionDeleteError;
  int metadataCorrectionFailuresRemaining = 0;
  TransactionMetadataSuggestionResult? nextMetadataSuggestion;
  Object? metadataSuggestionError;
  Object? expenseQuestionError;
  int dashboardFetchCount = 0;
  int availableMonthsFetchCount = 0;
  int labelFetchCount = 0;
  int labelManagerFetchCount = 0;
  int merchantFetchCount = 0;
  int merchantGroupManagerFetchCount = 0;
  int reviewQueueFetchCount = 0;
  int piggyBanksFetchCount = 0;
  int piggyEntriesFetchCount = 0;
  int transactionFetchCount = 0;
  int trendReportFetchCount = 0;
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
  final gmailParseFailures = <GmailParseFailure>[];
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

  final activeMappingRules = <Map<String, dynamic>>[
    {
      'merchant_id': 'merchant-swiggy',
      'category_id': 'cat-food',
      'subcategory_id': 'sub-food-delivery',
      'apply_to_future': true,
    },
    {
      'merchant_id': 'merchant-amazon',
      'category_id': 'cat-shopping',
      'subcategory_id': 'sub-marketplace',
      'apply_to_future': true,
    },
  ];

  final labels = <LabelOption>[
    LabelOption(id: 'label-grocery', name: 'Groceries'),
    LabelOption(id: 'label-reimburse', name: 'Reimburse'),
  ];

  final merchants = <MerchantOption>[
    MerchantOption(
      id: 'merchant-amazon',
      displayName: 'Amazon Shopping',
      categoryId: 'cat-shopping',
      subcategoryId: 'sub-marketplace',
    ),
    MerchantOption(
      id: 'merchant-swiggy',
      displayName: 'Swiggy Instamart',
      categoryId: 'cat-food',
      subcategoryId: 'sub-food-delivery',
    ),
    MerchantOption(id: 'merchant-uber', displayName: 'Uber'),
  ];

  final merchantAliasCounts = <String, int>{
    'merchant-amazon': 1,
    'merchant-swiggy': 1,
    'merchant-uber': 0,
  };

  List<DateTime> availableMonths = [DateTime(2026, 3), DateTime(2026, 2)];

  final monthlyCapProgress = <MonthlyCapProgress>[
    MonthlyCapProgress(
      monthlyCapId: 'cap-food',
      monthlyCapVersionId: 'cap-version-food',
      householdId: 'household-1',
      name: 'Food',
      periodMonth: DateTime(2026, 3),
      capAmount: 50000,
      baseCapAmount: 50000,
      carryForwardEnabled: false,
      carryForwardAmount: 0,
      effectiveCapAmount: 50000,
      spentAmount: 42000,
      remainingAmount: 8000,
      percentUsed: 0.84,
      isOverBudget: false,
      matchedTransactionCount: 8,
      categoryTargets: const [
        MonthlyCapCategoryTarget(id: 'cat-food', name: 'Food'),
      ],
      labelTargets: const [],
    ),
    MonthlyCapProgress(
      monthlyCapId: 'cap-shopping',
      monthlyCapVersionId: 'cap-version-shopping',
      householdId: 'household-1',
      name: 'Shopping',
      periodMonth: DateTime(2026, 3),
      capAmount: 100000,
      baseCapAmount: 100000,
      carryForwardEnabled: false,
      carryForwardAmount: 0,
      effectiveCapAmount: 100000,
      spentAmount: 112937,
      remainingAmount: -12937,
      percentUsed: 1.1294,
      isOverBudget: true,
      matchedTransactionCount: 1,
      categoryTargets: const [
        MonthlyCapCategoryTarget(id: 'cat-shopping', name: 'Shopping'),
      ],
      labelTargets: const [],
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
      labels: const [LabelOption(id: 'label-grocery', name: 'Groceries')],
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
      labels: const [LabelOption(id: 'label-reimburse', name: 'Reimburse')],
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
    dashboardFetchCount += 1;
    final selectedMonth = firstDayOfMonth(requestedMonth ?? DateTime(2026, 3));
    final isMarch2026 = isSameMonth(selectedMonth, DateTime(2026, 3));

    return DashboardSnapshot(
      availableMonths: availableMonths,
      selectedMonth: selectedMonth,
      monthlySpend: isMarch2026
          ? MonthlySpend(
              periodMonth: DateTime(2026, 3),
              transactionCount: 8,
              grossSpend: 43000,
              refundAmount: 1000,
              netSpend: 42000,
              billPayments: 12000,
            )
          : MonthlySpend.empty(selectedMonth),
      previousMonthSpend: isMarch2026
          ? MonthlySpend(
              periodMonth: DateTime(2026, 2),
              transactionCount: 7,
              grossSpend: 40000,
              refundAmount: 0,
              netSpend: 40000,
              billPayments: 8000,
            )
          : null,
      reviewQueueCount: 3,
      monthlyCapProgress: [
        for (final cap in monthlyCapProgress)
          if (isSameMonth(cap.periodMonth, selectedMonth)) cap,
      ],
      categoryOptions: categories,
      labelOptions: labels,
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
  Future<List<DateTime>> fetchAvailableMonths({
    required String householdId,
  }) async {
    availableMonthsFetchCount += 1;
    return availableMonths;
  }

  @override
  Future<List<SubcategoryOption>> fetchSubcategories({
    required String householdId,
  }) async {
    return subcategories;
  }

  @override
  Future<CategoryManagerSnapshot> fetchCategoryManagerSnapshot({
    required String householdId,
  }) async {
    return CategoryManagerSnapshot.fromTransactionRows(
      categories: categories,
      subcategories: subcategories,
      transactionRows: [
        for (final transaction in transactions)
          if (transaction.categoryId != null)
            {
              'category_id': transaction.categoryId,
              'subcategory_id': transaction.subcategoryId,
              'net_expense': transaction.netExpense,
            },
      ],
      activeMappingRuleRows: activeMappingRules,
      capRows: [
        for (final cap in monthlyCapProgress)
          for (final target in cap.categoryTargets) {'category_id': target.id},
      ],
    );
  }

  @override
  Future<List<LabelOption>> fetchLabels({required String householdId}) async {
    labelFetchCount += 1;
    return [...labels]..sort(_compareTestLabels);
  }

  @override
  Future<LabelManagerSnapshot> fetchLabelManagerSnapshot({
    required String householdId,
  }) async {
    labelManagerFetchCount += 1;
    return LabelManagerSnapshot(
      labels: [
        for (final label in labels)
          LabelUsageSummary(
            label: label,
            transactionCount: transactions
                .where(
                  (transaction) => transaction.labels.any(
                    (transactionLabel) => transactionLabel.id == label.id,
                  ),
                )
                .length,
            recentUsedAt: _recentLabelUse(label.id),
          ),
      ]..sort((a, b) => _compareTestLabels(a.label, b.label)),
    );
  }

  @override
  Future<MerchantGroupManagerSnapshot> fetchMerchantGroupManagerSnapshot({
    required String householdId,
  }) async {
    merchantGroupManagerFetchCount += 1;
    final categoriesById = {
      for (final category in categories) category.id: category.name,
    };
    final subcategoriesById = {
      for (final subcategory in subcategories) subcategory.id: subcategory.name,
    };

    return MerchantGroupManagerSnapshot(
      merchantGroups: [
        for (final merchant in merchants)
          MerchantGroupUsageSummary(
            merchantId: merchant.id,
            displayName: merchant.displayName,
            categoryId: merchant.categoryId,
            categoryName: merchant.categoryId == null
                ? null
                : categoriesById[merchant.categoryId],
            subcategoryId: merchant.subcategoryId,
            subcategoryName: merchant.subcategoryId == null
                ? null
                : subcategoriesById[merchant.subcategoryId],
            transactionCount: transactions
                .where((transaction) => transaction.merchantId == merchant.id)
                .length,
            netSpend: transactions
                .where((transaction) => transaction.merchantId == merchant.id)
                .fold<double>(
                  0,
                  (total, transaction) => total + transaction.netExpense,
                ),
            aliasCount: merchantAliasCounts[merchant.id] ?? 0,
            activeMappingRuleCount: activeMappingRules
                .where(
                  (rule) =>
                      rule['merchant_id'] == merchant.id &&
                      rule['apply_to_future'] != false,
                )
                .length,
            openReviewSuggestionCount: reviewItems
                .where((item) => item.suggestedMerchantId == merchant.id)
                .length,
            lastTransactionDate: _latestTransactionDate(merchant.id),
          ),
      ]..sort((a, b) => a.displayName.compareTo(b.displayName)),
    );
  }

  @override
  Future<MerchantOption> renameMerchantGroup(
    MerchantGroupRenameRequest request,
  ) async {
    merchantGroupRenameRequests.add(request);
    final name = request.displayName.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(
        request.displayName,
        'displayName',
        'Merchant group name is required.',
      );
    }
    if (merchants.any(
      (merchant) =>
          merchant.id != request.merchantId &&
          merchant.displayName.toLowerCase() == name.toLowerCase(),
    )) {
      throw StateError('Merchant group already exists.');
    }

    final index = merchants.indexWhere(
      (merchant) => merchant.id == request.merchantId,
    );
    final current = merchants[index];
    final renamed = MerchantOption(
      id: current.id,
      displayName: name,
      categoryId: current.categoryId,
      subcategoryId: current.subcategoryId,
    );
    merchants[index] = renamed;
    for (var index = 0; index < transactions.length; index += 1) {
      final transaction = transactions[index];
      if (transaction.merchantId != renamed.id) continue;

      transactions[index] = _copyTransaction(
        transaction,
        merchantName: renamed.displayName,
      );
    }

    return renamed;
  }

  @override
  Future<MerchantGroupMergeResult> mergeMerchantGroups(
    MerchantGroupMergeRequest request,
  ) async {
    merchantGroupMergeRequests.add(request);
    final destinationIndex = merchants.indexWhere(
      (merchant) => merchant.id == request.destinationMerchantId,
    );
    final destination = merchants[destinationIndex];
    final destinationName = request.destinationDisplayName.trim();
    final renamedDestination = MerchantOption(
      id: destination.id,
      displayName: destinationName,
      categoryId: destination.categoryId,
      subcategoryId: destination.subcategoryId,
    );
    merchants[destinationIndex] = renamedDestination;

    final sourceIds = request.sourceMerchantIds.toSet();
    final movedTransactions = transactions
        .where((transaction) => sourceIds.contains(transaction.merchantId))
        .toList(growable: false);
    final movedAliasCount = sourceIds.fold<int>(
      0,
      (total, merchantId) => total + (merchantAliasCounts[merchantId] ?? 0),
    );
    final movedMappingRuleCount = activeMappingRules
        .where((rule) => sourceIds.contains(rule['merchant_id']))
        .length;
    final categoryUpdatedMappingRuleCount =
        request.categoryStrategy ==
            MerchantGroupMergeCategoryStrategy.destination
        ? movedMappingRuleCount
        : 0;

    for (var index = 0; index < transactions.length; index += 1) {
      final transaction = transactions[index];
      if (!sourceIds.contains(transaction.merchantId)) continue;

      transactions[index] = _copyTransaction(
        transaction,
        merchantId: renamedDestination.id,
        merchantName: renamedDestination.displayName,
        categoryId:
            request.categoryStrategy ==
                MerchantGroupMergeCategoryStrategy.destination
            ? renamedDestination.categoryId
            : null,
        categoryName:
            request.categoryStrategy ==
                MerchantGroupMergeCategoryStrategy.destination
            ? categories
                  .where(
                    (category) => category.id == renamedDestination.categoryId,
                  )
                  .firstOrNull
                  ?.name
            : null,
        subcategoryId:
            request.categoryStrategy ==
                MerchantGroupMergeCategoryStrategy.destination
            ? renamedDestination.subcategoryId
            : null,
        subcategoryName:
            request.categoryStrategy ==
                MerchantGroupMergeCategoryStrategy.destination
            ? subcategories
                  .where(
                    (subcategory) =>
                        subcategory.id == renamedDestination.subcategoryId,
                  )
                  .firstOrNull
                  ?.name
            : null,
      );
    }

    for (final rule in activeMappingRules) {
      if (!sourceIds.contains(rule['merchant_id'])) continue;

      rule['merchant_id'] = renamedDestination.id;
      if (request.categoryStrategy ==
          MerchantGroupMergeCategoryStrategy.destination) {
        rule['category_id'] = renamedDestination.categoryId;
        rule['subcategory_id'] = renamedDestination.subcategoryId;
      }
    }

    merchantAliasCounts[renamedDestination.id] =
        (merchantAliasCounts[renamedDestination.id] ?? 0) + movedAliasCount;
    for (final sourceId in sourceIds) {
      merchantAliasCounts.remove(sourceId);
    }
    merchants.removeWhere((merchant) => sourceIds.contains(merchant.id));

    return MerchantGroupMergeResult(
      destinationMerchantId: renamedDestination.id,
      destinationDisplayName: renamedDestination.displayName,
      destinationCategoryId: renamedDestination.categoryId,
      destinationSubcategoryId: renamedDestination.subcategoryId,
      movedTransactionCount: movedTransactions.length,
      movedAliasCount: movedAliasCount,
      movedMappingRuleCount: movedMappingRuleCount,
      movedReviewSuggestionCount: 0,
      deletedSourceMerchantCount: sourceIds.length,
      categoryUpdatedTransactionCount:
          request.categoryStrategy ==
              MerchantGroupMergeCategoryStrategy.destination
          ? movedTransactions.length
          : 0,
      categoryUpdatedMappingRuleCount: categoryUpdatedMappingRuleCount,
      categoryUpdatedReviewSuggestionCount: 0,
    );
  }

  @override
  Future<LabelOption> createHouseholdLabel(LabelCreateRequest request) async {
    labelCreateRequests.add(request);
    final name = request.name.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(
        request.name,
        'name',
        'Label name is required.',
      );
    }
    if (labels.any((label) => label.name.toLowerCase() == name.toLowerCase())) {
      throw StateError('Label already exists.');
    }

    final label = LabelOption(id: 'label-${labels.length + 1}', name: name);
    labels.add(label);
    labels.sort(_compareTestLabels);
    return label;
  }

  @override
  Future<CategoryUsagePreview> fetchCategoryUsagePreview(
    CategoryUsagePreviewRequest request,
  ) async {
    final page = await fetchTransactions(
      TransactionQuery(
        householdId: request.householdId,
        categoryId: request.categoryId,
        subcategoryId: request.subcategoryId,
        pageSize: 5,
      ),
    );

    return CategoryUsagePreview(
      recentTransactions: page.items.take(5).toList(growable: false),
    );
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
  Future<CategoryTaxonomyUpdateResult> updateCategoryTaxonomy(
    CategoryTaxonomyUpdateRequest request,
  ) async {
    taxonomyUpdates.add(request);
    final category = CategoryOption(
      id: request.categoryId,
      name: request.categoryName.trim(),
    );
    final categoryIndex = categories.indexWhere(
      (candidate) => candidate.id == request.categoryId,
    );
    categories[categoryIndex] = category;

    var insertedCount = 0;
    for (final draft in request.subcategories) {
      final id = draft.id;
      if (id == null) {
        insertedCount += 1;
        subcategories.add(
          SubcategoryOption(
            id: 'sub-taxonomy-${taxonomyUpdates.length}-$insertedCount',
            categoryId: request.categoryId,
            name: draft.name.trim(),
          ),
        );
        continue;
      }

      final subcategoryIndex = subcategories.indexWhere(
        (candidate) => candidate.id == id,
      );
      subcategories[subcategoryIndex] = SubcategoryOption(
        id: id,
        categoryId: request.categoryId,
        name: draft.name.trim(),
      );
    }

    final updatedSubcategories = subcategories
        .where((subcategory) => subcategory.categoryId == request.categoryId)
        .toList(growable: false);

    return CategoryTaxonomyUpdateResult(
      category: category,
      subcategories: updatedSubcategories,
    );
  }

  @override
  Future<TaxonomyDeleteResult> deleteSubcategory(
    TaxonomySubcategoryDeleteRequest request,
  ) async {
    deletedSubcategoryRequests.add(request);
    final affectedTransactions = transactions
        .where(
          (transaction) =>
              transaction.categoryId == request.categoryId &&
              transaction.subcategoryId == request.subcategoryId,
        )
        .toList(growable: false);
    final affectedRules = activeMappingRules
        .where(
          (rule) =>
              rule['category_id'] == request.categoryId &&
              rule['subcategory_id'] == request.subcategoryId,
        )
        .length;

    subcategories.removeWhere(
      (subcategory) => subcategory.id == request.subcategoryId,
    );
    for (var index = 0; index < transactions.length; index += 1) {
      final transaction = transactions[index];
      if (transaction.categoryId != request.categoryId ||
          transaction.subcategoryId != request.subcategoryId) {
        continue;
      }

      transactions[index] = _copyTransaction(
        transaction,
        clearSubcategory: true,
      );
    }
    for (final rule in activeMappingRules) {
      if (rule['category_id'] == request.categoryId &&
          rule['subcategory_id'] == request.subcategoryId) {
        rule['subcategory_id'] = null;
      }
    }

    return TaxonomyDeleteResult(
      affectedTransactionCount: affectedTransactions.length,
      openedReviewItemCount: affectedTransactions.length,
      mappingRuleCount: affectedRules,
      clearedMerchantCount: 1,
      clearedReviewSuggestionCount: 0,
      deletedCapCount: 0,
    );
  }

  @override
  Future<TaxonomyDeleteResult> deleteCategory(
    TaxonomyCategoryDeleteRequest request,
  ) async {
    deletedCategoryRequests.add(request);
    final affectedTransactions = transactions
        .where((transaction) => transaction.categoryId == request.categoryId)
        .toList(growable: false);
    final affectedRules = activeMappingRules
        .where((rule) => rule['category_id'] == request.categoryId)
        .length;
    final affectedCaps = monthlyCapProgress
        .where(
          (cap) => cap.categoryTargets.any(
            (target) => target.id == request.categoryId,
          ),
        )
        .length;

    categories.removeWhere((category) => category.id == request.categoryId);
    subcategories.removeWhere(
      (subcategory) => subcategory.categoryId == request.categoryId,
    );
    activeMappingRules.removeWhere(
      (rule) => rule['category_id'] == request.categoryId,
    );
    for (var index = 0; index < monthlyCapProgress.length; index += 1) {
      final cap = monthlyCapProgress[index];
      if (!cap.categoryTargets.any(
        (target) => target.id == request.categoryId,
      )) {
        continue;
      }

      monthlyCapProgress[index] = _copyMonthlyCapProgress(
        cap,
        categoryTargets: [
          for (final target in cap.categoryTargets)
            if (target.id != request.categoryId) target,
        ],
      );
    }
    monthlyCapProgress.removeWhere(
      (cap) => cap.categoryTargets.isEmpty && cap.labelTargets.isEmpty,
    );
    for (var index = 0; index < transactions.length; index += 1) {
      final transaction = transactions[index];
      if (transaction.categoryId != request.categoryId) continue;

      transactions[index] = _copyTransaction(
        transaction,
        clearCategory: true,
        clearSubcategory: true,
      );
    }

    return TaxonomyDeleteResult(
      affectedTransactionCount: affectedTransactions.length,
      openedReviewItemCount: affectedTransactions.length,
      mappingRuleCount: affectedRules,
      clearedMerchantCount: 1,
      clearedReviewSuggestionCount: 0,
      deletedCapCount: affectedCaps,
    );
  }

  @override
  Future<CategoryMergeResult> mergeCategories(
    CategoryMergeRequest request,
  ) async {
    mergeRequests.add(request);
    final destinationIndex = categories.indexWhere(
      (category) => category.id == request.destinationCategoryId,
    );
    final destinationCategory = CategoryOption(
      id: request.destinationCategoryId,
      name: request.destinationCategoryName.trim(),
    );
    categories[destinationIndex] = destinationCategory;

    var createdSubcategoryCount = 0;
    final mappedSubcategories = <String, SubcategoryOption>{};
    for (final mapping in request.subcategoryMappings) {
      final destinationSubcategoryId = mapping.destinationSubcategoryId;
      if (destinationSubcategoryId != null) {
        mappedSubcategories[mapping.sourceSubcategoryId] = subcategories
            .where((subcategory) => subcategory.id == destinationSubcategoryId)
            .first;
        continue;
      }

      createdSubcategoryCount += 1;
      final subcategory = SubcategoryOption(
        id: 'sub-merged-$createdSubcategoryCount',
        categoryId: request.destinationCategoryId,
        name: mapping.destinationSubcategoryName!.trim(),
      );
      subcategories.add(subcategory);
      mappedSubcategories[mapping.sourceSubcategoryId] = subcategory;
    }

    final affectedTransactions = transactions
        .where(
          (transaction) =>
              transaction.categoryId != null &&
              request.sourceCategoryIds.contains(transaction.categoryId),
        )
        .toList(growable: false);

    for (var index = 0; index < transactions.length; index += 1) {
      final transaction = transactions[index];
      if (transaction.categoryId == null ||
          !request.sourceCategoryIds.contains(transaction.categoryId)) {
        continue;
      }

      final mappedSubcategory = transaction.subcategoryId == null
          ? null
          : mappedSubcategories[transaction.subcategoryId];
      transactions[index] = _copyTransaction(
        transaction,
        categoryId: request.destinationCategoryId,
        categoryName: destinationCategory.name,
        subcategoryId: mappedSubcategory?.id,
        subcategoryName: mappedSubcategory?.name,
        clearSubcategory: mappedSubcategory == null,
      );
    }

    final affectedRules = activeMappingRules
        .where(
          (rule) => request.sourceCategoryIds.contains(rule['category_id']),
        )
        .length;
    for (final rule in activeMappingRules) {
      if (!request.sourceCategoryIds.contains(rule['category_id'])) continue;

      final sourceSubcategoryId = rule['subcategory_id'] as String?;
      final mappedSubcategory = sourceSubcategoryId == null
          ? null
          : mappedSubcategories[sourceSubcategoryId];
      rule['category_id'] = request.destinationCategoryId;
      rule['subcategory_id'] = mappedSubcategory?.id;
    }

    var affectedCaps = 0;
    for (var index = 0; index < monthlyCapProgress.length; index += 1) {
      final cap = monthlyCapProgress[index];
      final hasSourceTarget = cap.categoryTargets.any(
        (target) => request.sourceCategoryIds.contains(target.id),
      );
      if (!hasSourceTarget) continue;

      affectedCaps += cap.categoryTargets
          .where((target) => request.sourceCategoryIds.contains(target.id))
          .length;
      final targetsById = <String, MonthlyCapCategoryTarget>{
        for (final target in cap.categoryTargets)
          if (!request.sourceCategoryIds.contains(target.id)) target.id: target,
        request.destinationCategoryId: MonthlyCapCategoryTarget(
          id: request.destinationCategoryId,
          name: destinationCategory.name,
        ),
      };
      monthlyCapProgress[index] = _copyMonthlyCapProgress(
        cap,
        categoryTargets: targetsById.values.toList(growable: false),
      );
    }

    final deletedSubcategoryCount = subcategories
        .where(
          (subcategory) =>
              request.sourceCategoryIds.contains(subcategory.categoryId),
        )
        .length;
    subcategories.removeWhere(
      (subcategory) =>
          request.sourceCategoryIds.contains(subcategory.categoryId),
    );
    categories.removeWhere(
      (category) => request.sourceCategoryIds.contains(category.id),
    );

    return CategoryMergeResult(
      destinationCategory: destinationCategory,
      changedTransactionCount: affectedTransactions.length,
      changedMerchantCount: 1,
      changedMappingRuleCount: affectedRules,
      changedReviewSuggestionCount: 0,
      mergedCapCount: affectedCaps,
      createdSubcategoryCount: createdSubcategoryCount,
      deletedCategoryCount: request.sourceCategoryIds.length,
      deletedSubcategoryCount: deletedSubcategoryCount,
    );
  }

  @override
  Future<List<MerchantOption>> fetchMerchants({
    required String householdId,
  }) async {
    merchantFetchCount += 1;
    return [...merchants]
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  @override
  Future<List<MerchantReviewItem>> fetchMerchantReviewQueue({
    required String householdId,
  }) async {
    reviewQueueFetchCount += 1;
    final error = reviewQueueError;
    if (error != null) throw error;

    return reviewItems;
  }

  @override
  Future<List<GmailParseFailure>> fetchGmailParseFailures({
    required String householdId,
  }) async {
    final error = gmailParseFailuresError;
    if (error != null) throw error;

    return gmailParseFailures;
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
    final error = expenseQuestionError;
    if (error != null) throw error;

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
    piggyBanksFetchCount += 1;
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
    piggyEntriesFetchCount += 1;
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

  DateTime? _recentLabelUse(String labelId) {
    final dates =
        transactions
            .where(
              (transaction) =>
                  transaction.labels.any((label) => label.id == labelId),
            )
            .map((transaction) => transaction.transactionDate)
            .toList(growable: false)
          ..sort();
    if (dates.isEmpty) return null;

    return dates.last;
  }

  DateTime? _latestTransactionDate(String merchantId) {
    final dates =
        transactions
            .where((transaction) => transaction.merchantId == merchantId)
            .map((transaction) => transaction.transactionDate)
            .toList(growable: false)
          ..sort();
    if (dates.isEmpty) return null;

    return dates.last;
  }

  @override
  Future<PagedTransactions> fetchTransactions(TransactionQuery query) async {
    transactionFetchCount += 1;
    lastQuery = query;
    final search = query.searchText.trim().toLowerCase();
    final merchantId = query.merchantId?.trim();
    final filtered = transactions.where((transaction) {
      final matchesSearch = merchantId != null && merchantId.isNotEmpty
          ? transaction.merchantId == merchantId
          : search.isEmpty ||
                transaction.statementMerchant.toLowerCase().contains(search);
      final matchesCategory =
          query.categoryId == null ||
          transaction.categoryId == query.categoryId;
      final matchesSubcategory =
          query.subcategoryId == null ||
          transaction.subcategoryId == query.subcategoryId;
      final matchesLabel =
          query.labelId == null ||
          transaction.labels.any((label) => label.id == query.labelId);
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
          matchesSubcategory &&
          matchesLabel &&
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
  Future<TransactionLabelsSetResult> setTransactionLabels(
    TransactionLabelsSetRequest request,
  ) async {
    labelSetRequests.add(request);
    final nextLabels = <LabelOption>[
      for (final labelId in request.labelIds)
        labels.where((label) => label.id == labelId).first,
    ];

    for (final rawName in request.newLabelNames) {
      final name = rawName.trim();
      final existing = labels
          .where((label) => label.name.toLowerCase() == name.toLowerCase())
          .firstOrNull;
      if (existing != null) {
        nextLabels.add(existing);
        continue;
      }

      final label = LabelOption(id: 'label-${labels.length + 1}', name: name);
      labels.add(label);
      nextLabels.add(label);
    }

    final distinctLabels = <String, LabelOption>{
      for (final label in nextLabels) label.id: label,
    }.values.toList(growable: false)..sort(_compareTestLabels);

    final index = transactions.indexWhere(
      (transaction) => transaction.id == request.transactionId,
    );
    transactions[index] = _copyTransaction(
      transactions[index],
      labels: distinctLabels,
    );

    return TransactionLabelsSetResult(labels: distinctLabels);
  }

  @override
  Future<TransactionDeleteResult> deleteTransaction(
    TransactionDeleteRequest request,
  ) async {
    transactionDeleteRequests.add(request);
    final error = transactionDeleteError;
    if (error != null) throw error;

    final index = transactions.indexWhere(
      (transaction) => transaction.id == request.transactionId,
    );
    if (index == -1) {
      throw StateError('Transaction not found.');
    }

    final transaction = transactions.removeAt(index);
    final deletedReviewItemCount = reviewItems
        .where((item) => item.transactionId == request.transactionId)
        .length;
    reviewItems.removeWhere(
      (item) => item.transactionId == request.transactionId,
    );
    final unlinkedPiggyBankEntryCount = piggyEntries
        .where((entry) => entry.linkedTransactionId == request.transactionId)
        .length;
    for (var index = 0; index < piggyEntries.length; index += 1) {
      final entry = piggyEntries[index];
      if (entry.linkedTransactionId != request.transactionId) continue;

      piggyEntries[index] = _copyPiggyEntry(
        entry,
        clearLinkedTransaction: true,
      );
    }
    trendTransactions.removeWhere(
      (trendTransaction) =>
          trendTransaction.id == transaction.id ||
          trendTransaction.statementMerchant == transaction.statementMerchant ||
          trendTransaction.merchantGroup ==
              (transaction.merchantName ?? transaction.statementMerchant),
    );

    return TransactionDeleteResult(
      deletedTransactionId: transaction.id,
      sourceType: 'workbook',
      sourceFingerprint: 'workbook:${transaction.id}',
      deletedLabelCount: transaction.labels.length,
      deletedSourceRowCount: 1,
      deletedReviewItemCount: deletedReviewItemCount,
      unlinkedPiggyBankEntryCount: unlinkedPiggyBankEntryCount,
      unlinkedGmailParseAttemptCount: 0,
      deletedAt: DateTime(2026, 3, 20, 12),
    );
  }

  @override
  Future<LabelOption> renameHouseholdLabel(LabelRenameRequest request) async {
    labelRenameRequests.add(request);
    final name = request.name.trim();
    final index = labels.indexWhere((label) => label.id == request.labelId);
    final label = LabelOption(id: request.labelId, name: name);
    labels[index] = label;

    for (
      var transactionIndex = 0;
      transactionIndex < transactions.length;
      transactionIndex += 1
    ) {
      final transaction = transactions[transactionIndex];
      if (!transaction.labels.any((candidate) => candidate.id == label.id)) {
        continue;
      }

      transactions[transactionIndex] = _copyTransaction(
        transaction,
        labels: [
          for (final candidate in transaction.labels)
            candidate.id == label.id ? label : candidate,
        ]..sort(_compareTestLabels),
      );
    }

    return label;
  }

  @override
  Future<LabelDeleteResult> deleteHouseholdLabel(
    LabelDeleteRequest request,
  ) async {
    labelDeleteRequests.add(request);
    var detachedCount = 0;
    labels.removeWhere((label) => label.id == request.labelId);
    for (var index = 0; index < monthlyCapProgress.length; index += 1) {
      final cap = monthlyCapProgress[index];
      if (!cap.labelTargets.any((label) => label.id == request.labelId)) {
        continue;
      }

      monthlyCapProgress[index] = _copyMonthlyCapProgress(
        cap,
        labelTargets: [
          for (final label in cap.labelTargets)
            if (label.id != request.labelId) label,
        ],
      );
    }
    monthlyCapProgress.removeWhere(
      (cap) => cap.categoryTargets.isEmpty && cap.labelTargets.isEmpty,
    );

    for (var index = 0; index < transactions.length; index += 1) {
      final transaction = transactions[index];
      if (!transaction.labels.any((label) => label.id == request.labelId)) {
        continue;
      }

      detachedCount += 1;
      transactions[index] = _copyTransaction(
        transaction,
        labels: [
          for (final label in transaction.labels)
            if (label.id != request.labelId) label,
        ],
      );
    }

    return LabelDeleteResult(
      labelId: request.labelId,
      detachedTransactionCount: detachedCount,
    );
  }

  @override
  Future<TrendReport> fetchTrendReport(TrendQuery query) async {
    trendReportFetchCount += 1;
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
    if (metadataCorrectionFailuresRemaining > 0) {
      metadataCorrectionFailuresRemaining -= 1;
      throw StateError('save unavailable');
    }

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
  Future<MonthlyCapUpsertResult> upsertMonthlyCap(
    MonthlyCapUpsertRequest request,
  ) async {
    monthlyCapUpsertRequests.add(request);
    final categoryTargets = [
      for (final categoryId in request.categoryIds)
        MonthlyCapCategoryTarget(
          id: categoryId,
          name: categories
              .where((category) => category.id == categoryId)
              .first
              .name,
        ),
    ];
    final labelTargets = [
      for (final labelId in request.labelIds)
        MonthlyCapLabelTarget(
          id: labelId,
          name: labels.where((label) => label.id == labelId).first.name,
        ),
    ];
    final monthlyCapId =
        request.monthlyCapId ??
        'cap-created-${monthlyCapUpsertRequests.length}';
    final progress = MonthlyCapProgress(
      monthlyCapId: monthlyCapId,
      monthlyCapVersionId: 'cap-version-$monthlyCapId',
      householdId: request.householdId,
      name: request.name.trim(),
      periodMonth: firstDayOfMonth(request.periodMonth),
      capAmount: request.capAmount,
      baseCapAmount: request.capAmount,
      carryForwardEnabled: request.carryForwardEnabled,
      carryForwardAmount: 0,
      effectiveCapAmount: request.capAmount,
      spentAmount: 0,
      remainingAmount: request.capAmount,
      percentUsed: request.capAmount == 0 ? null : 0,
      isOverBudget: false,
      matchedTransactionCount: 0,
      categoryTargets: categoryTargets,
      labelTargets: labelTargets,
    );
    final index = monthlyCapProgress.indexWhere(
      (cap) => cap.monthlyCapId == monthlyCapId,
    );
    if (index == -1) {
      monthlyCapProgress.add(progress);
    } else {
      monthlyCapProgress[index] = progress;
    }

    return MonthlyCapUpsertResult(
      monthlyCapId: monthlyCapId,
      monthlyCapVersionId: 'cap-version-$monthlyCapId',
      householdId: request.householdId,
      name: request.name.trim(),
      periodMonth: firstDayOfMonth(request.periodMonth),
      capAmount: request.capAmount,
      baseCapAmount: request.capAmount,
      carryForwardEnabled: request.carryForwardEnabled,
      categoryTargets: categoryTargets,
      labelTargets: labelTargets,
    );
  }

  @override
  Future<MonthlyCapDeleteResult> deleteMonthlyCap(
    MonthlyCapDeleteRequest request,
  ) async {
    monthlyCapDeleteRequests.add(request);
    monthlyCapProgress.removeWhere(
      (cap) => cap.monthlyCapId == request.monthlyCapId,
    );
    return MonthlyCapDeleteResult(
      monthlyCapId: request.monthlyCapId,
      stoppedFromMonth: firstDayOfMonth(request.periodMonth),
    );
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

int _compareTestLabels(LabelOption a, LabelOption b) {
  final lowerComparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  if (lowerComparison != 0) return lowerComparison;

  return a.id.compareTo(b.id);
}

FinanceTransaction _copyTransaction(
  FinanceTransaction transaction, {
  String? merchantId,
  String? merchantName,
  String? categoryId,
  String? categoryName,
  String? subcategoryId,
  String? subcategoryName,
  List<LabelOption>? labels,
  bool clearCategory = false,
  bool clearSubcategory = false,
}) {
  return FinanceTransaction(
    id: transaction.id,
    transactionDate: transaction.transactionDate,
    statementMerchant: transaction.statementMerchant,
    merchantId: merchantId ?? transaction.merchantId,
    merchantName: merchantName ?? transaction.merchantName,
    categoryId: clearCategory ? null : categoryId ?? transaction.categoryId,
    categoryName: clearCategory
        ? null
        : categoryName ?? transaction.categoryName,
    subcategoryId: clearSubcategory
        ? null
        : subcategoryId ?? transaction.subcategoryId,
    subcategoryName: clearSubcategory
        ? null
        : subcategoryName ?? transaction.subcategoryName,
    sourceAccountId: transaction.sourceAccountId,
    transactionType: transaction.transactionType,
    amount: transaction.amount,
    grossSpend: transaction.grossSpend,
    refundAmount: transaction.refundAmount,
    netExpense: transaction.netExpense,
    currencyCode: transaction.currencyCode,
    confidence: transaction.confidence,
    cardholderName: transaction.cardholderName,
    notes: transaction.notes,
    labels: labels ?? transaction.labels,
  );
}

PiggyBankEntry _copyPiggyEntry(
  PiggyBankEntry entry, {
  bool clearLinkedTransaction = false,
}) {
  return PiggyBankEntry(
    id: entry.id,
    householdId: entry.householdId,
    piggyBankId: entry.piggyBankId,
    entryType: entry.entryType,
    amount: entry.amount,
    entryDate: entry.entryDate,
    note: entry.note,
    linkedTransactionId: clearLinkedTransaction
        ? null
        : entry.linkedTransactionId,
    createdBy: entry.createdBy,
    createdAt: entry.createdAt,
  );
}

MonthlyCapProgress _copyMonthlyCapProgress(
  MonthlyCapProgress cap, {
  bool? carryForwardEnabled,
  double? carryForwardAmount,
  double? effectiveCapAmount,
  double? remainingAmount,
  double? percentUsed,
  bool? isOverBudget,
  List<MonthlyCapCategoryTarget>? categoryTargets,
  List<MonthlyCapLabelTarget>? labelTargets,
}) {
  return MonthlyCapProgress(
    monthlyCapId: cap.monthlyCapId,
    monthlyCapVersionId: cap.monthlyCapVersionId,
    householdId: cap.householdId,
    name: cap.name,
    periodMonth: cap.periodMonth,
    capAmount: cap.capAmount,
    baseCapAmount: cap.baseCapAmount,
    carryForwardEnabled: carryForwardEnabled ?? cap.carryForwardEnabled,
    carryForwardAmount: carryForwardAmount ?? cap.carryForwardAmount,
    effectiveCapAmount: effectiveCapAmount ?? cap.effectiveCapAmount,
    spentAmount: cap.spentAmount,
    remainingAmount: remainingAmount ?? cap.remainingAmount,
    percentUsed: percentUsed ?? cap.percentUsed,
    isOverBudget: isOverBudget ?? cap.isOverBudget,
    matchedTransactionCount: cap.matchedTransactionCount,
    categoryTargets: categoryTargets ?? cap.categoryTargets,
    labelTargets: labelTargets ?? cap.labelTargets,
  );
}

GmailParseFailure _gmailParseFailure() {
  return GmailParseFailure(
    failureId: 'gmail-failure-1',
    candidateType: 'credit_card',
    sourceReceivedAt: DateTime(2026, 6, 8, 10, 30),
    senderEmail: 'alerts@hdfcbank.bank.in',
    subject: 'A payment was made using your Credit Card',
    parserName: 'hdfc_credit_card_debit',
    parserVersion: '1.0.0',
    reasonCode: 'hdfc_debit_pattern_not_matched',
    sourceMessageId: 'gmail-failure-message-1',
    sourceThreadId: 'gmail-failure-thread-1',
  );
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
