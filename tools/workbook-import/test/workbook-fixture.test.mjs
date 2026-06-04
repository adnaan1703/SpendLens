import assert from 'node:assert/strict';
import test from 'node:test';
import {
  DEFAULT_WORKBOOK_PATH,
  EXPECTED_FIXTURE,
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
