import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import {
  DEFAULT_WORKBOOK_PATH,
  EXPECTED_FIXTURE,
  classifyTransactionsWithBackend,
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

test('backend classification helper classifies workbook transactions and preserves no-match rows', async () => {
  const householdId = '03f00000-0000-5000-8000-000000000003';
  const transactions = [
    {
      statementMerchant: 'AMAZON PRIME',
      merchantGroup: 'Unknown Amazon',
      category: 'Unclear',
      subcategory: 'Needs Review',
      confidence: 'low',
    },
    {
      statementMerchant: 'AMZN MKTP IN',
      merchantGroup: 'Unknown Amazon',
      category: 'Unclear',
      subcategory: 'Needs Review',
      confidence: 'low',
    },
  ];
  const queries = [];
  const client = {
    async query(sql, params) {
      queries.push({ sql, params });
      assert.match(sql, /public\.classify_statement_merchant\(\$1, \$2\)/);
      if (params[1] !== 'AMAZON PRIME') return { rows: [] };
      return {
        rows: [
          {
            rule_id: '11111111-1111-5111-8111-111111111111',
            merchant_id: '22222222-2222-5222-8222-222222222222',
            merchant_name: 'Amazon Shopping',
            category_id: '33333333-3333-5333-8333-333333333333',
            category_name: 'Shopping',
            subcategory_id: '44444444-4444-5444-8444-444444444444',
            subcategory_name: 'Marketplace',
            confidence: 'manual',
            rule_notes: 'Regex-backed backend match',
            rule_created_by: '55555555-5555-5555-8555-555555555555',
          },
        ],
      };
    },
  };

  const classified = await classifyTransactionsWithBackend(client, transactions, { householdId });

  assert.equal(classified[0].merchantGroup, 'Amazon Shopping');
  assert.equal(classified[0].category, 'Shopping');
  assert.equal(classified[0].subcategory, 'Marketplace');
  assert.equal(classified[0].confidence, 'manual');
  assert.equal(classified[0].mappingRuleId, '11111111-1111-5111-8111-111111111111');
  assert.equal(classified[0].mappingRuleMerchantId, '22222222-2222-5222-8222-222222222222');
  assert.equal(classified[0].mappingRuleCategoryId, '33333333-3333-5333-8333-333333333333');
  assert.equal(classified[0].mappingRuleSubcategoryId, '44444444-4444-5444-8444-444444444444');
  assert.equal(classified[0].mappingRuleCreatedBy, '55555555-5555-5555-8555-555555555555');
  assert.equal(classified[0].mappingRuleNotes, 'Regex-backed backend match');

  assert.equal(classified[1].merchantGroup, 'Unknown Amazon');
  assert.equal(classified[1].category, 'Unclear');
  assert.equal(classified[1].mappingRuleId, null);
  assert.equal(classified[1].mappingRuleMerchantId, null);
  assert.equal(classified[1].mappingRuleCategoryId, null);
  assert.equal(classified[1].mappingRuleSubcategoryId, null);
  assert.deepEqual(
    queries.map((query) => query.params),
    [
      [householdId, 'AMAZON PRIME'],
      [householdId, 'AMZN MKTP IN'],
    ],
  );
});

test('workbook importer source does not contain a local merchant rule engine', async () => {
  const source = await readFile(new URL('../src/workbook-importer.mjs', import.meta.url), 'utf8');
  assert.equal(source.includes('new RegExp'), false);
  assert.equal(source.includes('merchant_mapping_rules'), false);
  assert.equal(source.includes('classify_statement_merchant'), true);
});
