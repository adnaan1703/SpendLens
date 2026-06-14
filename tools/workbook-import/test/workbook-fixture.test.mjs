import assert from 'node:assert/strict';
import test from 'node:test';
import {
  DEFAULT_WORKBOOK_PATH,
  EXPECTED_FIXTURE,
  classifyTransactionsWithRules,
  filterWorkbookDataForSuppression,
  formatMoney,
  readWorkbook,
  summarizeTransactions,
  validateWorkbookData,
} from '../src/workbook-importer.mjs';

test('FY 2025-26 workbook fixture totals match the implementation plan', async () => {
  const data = await readWorkbook(DEFAULT_WORKBOOK_PATH);
  const summary = validateWorkbookData(data);

  assert.equal(summary.totals.txnCount, EXPECTED_FIXTURE.transactionCount);
  assert.equal(formatMoney(summary.totals.grossSpendPaise), '1548630.69');
  assert.equal(formatMoney(summary.totals.refundsPaise), '26242.46');
  assert.equal(formatMoney(summary.totals.netSpendPaise), '1522388.23');
  assert.equal(formatMoney(summary.totals.cardBillPaymentsPaise), '1349006.00');
});

test('workbook summaries reconcile to transaction detail rows', async () => {
  const data = await readWorkbook(DEFAULT_WORKBOOK_PATH);
  const summary = summarizeTransactions(data.transactions);

  assert.equal(summary.monthly.length, data.monthlySummaries.length);
  assert.equal(summary.categories.length, data.categorySummaries.length);
  assert.equal(summary.merchants.length, data.merchantSummaries.length);
  assert.equal(summary.cardholders.length, data.cardholderSummaries.length);
});

test('source fingerprints are unique and Needs Review matches non-high confidence rows', async () => {
  const data = await readWorkbook(DEFAULT_WORKBOOK_PATH);
  const fingerprints = new Set(data.transactions.map((transaction) => transaction.sourceFingerprint));
  const reviewFingerprints = new Set(data.needsReviewTransactions.map((transaction) => transaction.sourceFingerprint));
  const nonHighFingerprints = new Set(
    data.transactions
      .filter((transaction) => transaction.confidence !== 'high')
      .map((transaction) => transaction.sourceFingerprint),
  );

  assert.equal(fingerprints.size, EXPECTED_FIXTURE.transactionCount);
  assert.equal(reviewFingerprints.size, EXPECTED_FIXTURE.reviewItemCount);
  assert.deepEqual([...reviewFingerprints].sort(), [...nonHighFingerprints].sort());
});

test('tombstoned workbook fingerprints are skipped and validation totals are adjusted', async () => {
  const data = await readWorkbook(DEFAULT_WORKBOOK_PATH);
  const reviewTransaction = data.needsReviewTransactions[0];
  const highConfidenceTransaction = data.transactions.find(
    (transaction) => transaction.confidence === 'high',
  );
  assert.ok(reviewTransaction, 'Expected at least one Needs Review transaction');
  assert.ok(highConfidenceTransaction, 'Expected at least one high-confidence transaction');

  const { importData, suppression } = filterWorkbookDataForSuppression(
    data,
    new Set([
      reviewTransaction.sourceFingerprint,
      highConfidenceTransaction.sourceFingerprint,
    ]),
  );
  const adjustedSummary = summarizeTransactions(importData.transactions);

  assert.equal(suppression.suppressedCount, 2);
  assert.equal(suppression.importedCount, EXPECTED_FIXTURE.transactionCount - 2);
  assert.equal(
    suppression.suppressedNetExpensePaise,
    reviewTransaction.netExpensePaise + highConfidenceTransaction.netExpensePaise,
  );
  assert.equal(adjustedSummary.totals.txnCount, EXPECTED_FIXTURE.transactionCount - 2);
  assert.equal(
    adjustedSummary.totals.netSpendPaise,
    EXPECTED_FIXTURE.netExpensePaise - suppression.suppressedNetExpensePaise,
  );
  assert.equal(
    importData.needsReviewTransactions.some(
      (transaction) => transaction.sourceFingerprint === reviewTransaction.sourceFingerprint,
    ),
    false,
  );
});

test('manual merchant mapping rules classify future parsed transactions', () => {
  const transactions = [
    {
      statementMerchant: 'AMZN MKTP IN',
      merchantGroup: 'Unknown Amazon',
      category: 'Unclear',
      subcategory: 'Needs Review',
      confidence: 'low',
    },
    {
      statementMerchant: 'AMAZON PRIME',
      merchantGroup: 'Unknown Amazon',
      category: 'Unclear',
      subcategory: 'Needs Review',
      confidence: 'low',
    },
  ];

  const classified = classifyTransactionsWithRules(transactions, [
    {
      id: 'rule-1',
      pattern: 'amzn mktp in',
      matchType: 'exact',
      priority: 10,
      confidence: 'manual',
      createdBy: 'profile-1',
      notes: 'Prefer marketplace category',
      merchantId: 'merchant-shopping',
      merchantGroup: 'Amazon Shopping',
      categoryId: 'category-shopping',
      category: 'Shopping',
      subcategoryId: 'subcategory-marketplace',
      subcategory: 'Marketplace',
    },
  ]);

  assert.equal(classified[0].merchantGroup, 'Amazon Shopping');
  assert.equal(classified[0].category, 'Shopping');
  assert.equal(classified[0].subcategory, 'Marketplace');
  assert.equal(classified[0].confidence, 'manual');
  assert.equal(classified[0].mappingRuleId, 'rule-1');
  assert.equal(classified[0].mappingRuleCreatedBy, 'profile-1');
  assert.equal(classified[0].mappingRuleNotes, 'Prefer marketplace category');

  assert.equal(classified[1].merchantGroup, 'Unknown Amazon');
  assert.equal(classified[1].category, 'Unclear');
  assert.equal(classified[1].mappingRuleId, null);
});
