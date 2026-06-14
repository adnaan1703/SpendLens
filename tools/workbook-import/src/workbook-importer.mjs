import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';
import XLSX from '@e965/xlsx';
import pg from 'pg';

const { Client } = pg;

export const DEFAULT_WORKBOOK_PATH = path.resolve(
  fileURLToPath(new URL('../../../docs/Credit Card Spend Analysis - FY 2025-26.xlsx', import.meta.url)),
);

export const DEFAULT_DB_URL = 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';
export const IMPORT_SOURCE_LABEL = 'Credit Card Spend Analysis - FY 2025-26.xlsx';
export const IMPORT_BATCH_SOURCE_LABEL = `FY 2025-26 workbook: ${IMPORT_SOURCE_LABEL}`;
export const PARSER_NAME = 'workbook_fy2025_26_import';
export const PARSER_VERSION = '1';

export const DEFAULT_IDS = {
  authUserId: '03f00000-0000-5000-8000-000000000001',
  profileId: '03f00000-0000-5000-8000-000000000002',
  householdId: '03f00000-0000-5000-8000-000000000003',
  householdMemberId: '03f00000-0000-5000-8000-000000000004',
};

export const EXPECTED_FIXTURE = {
  transactionCount: 475,
  grossSpendPaise: 154863069,
  refundsPaise: 2624246,
  netExpensePaise: 152238823,
  cardBillPaymentsPaise: 134900600,
  reviewItemCount: 29,
};

export function normalizeName(value) {
  return String(value ?? '')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ');
}

function requiredText(value, field, rowNumber) {
  const text = String(value ?? '').trim();
  assert.notEqual(text, '', `${field} is required on workbook row ${rowNumber}`);
  return text;
}

export function moneyToPaise(value) {
  if (value === null || value === undefined || value === '') return 0;
  if (typeof value === 'number') return Math.round(value * 100);
  const cleaned = String(value).replace(/[,\s₹Rs]/gi, '');
  assert.notEqual(cleaned, '', `Invalid money value: ${value}`);
  return Math.round(Number(cleaned) * 100);
}

export function formatMoney(paise) {
  const sign = paise < 0 ? '-' : '';
  const absolute = Math.abs(paise);
  const whole = Math.floor(absolute / 100);
  const cents = String(absolute % 100).padStart(2, '0');
  return `${sign}${whole}.${cents}`;
}

function integerValue(value) {
  return Math.trunc(Number(value ?? 0));
}

function cellValue(value) {
  if (value === null || value === undefined) return null;
  if (value instanceof Date) return value;
  if (typeof value === 'object') {
    if ('result' in value) return value.result;
    if ('text' in value) return value.text;
    if ('richText' in value) return value.richText.map((part) => part.text).join('');
  }
  return value;
}

function worksheetRows(worksheet) {
  const matrix = XLSX.utils.sheet_to_json(worksheet, { header: 1, raw: true, defval: null });
  const headers = matrix[0].map((value) => String(value ?? '').trim());
  const rows = [];
  for (let index = 1; index < matrix.length; index += 1) {
    const rowNumber = index + 1;
    const values = headers.map((_, headerIndex) => cellValue(matrix[index][headerIndex]));
    if (values.every((value) => value === null || value === undefined || value === '')) continue;
    rows.push(Object.fromEntries(headers.map((header, index) => [header, values[index]])));
    rows.at(-1).__rowNumber = rowNumber;
  }
  return rows;
}

function twoDigits(value) {
  return String(value).padStart(2, '0');
}

function toDateString(value, field, rowNumber) {
  if (value instanceof Date) {
    return `${value.getFullYear()}-${twoDigits(value.getMonth() + 1)}-${twoDigits(value.getDate())}`;
  }
  const text = requiredText(value, field, rowNumber);
  const parsed = new Date(text);
  assert.ok(!Number.isNaN(parsed.getTime()), `Invalid date "${text}" on workbook row ${rowNumber}`);
  return `${parsed.getFullYear()}-${twoDigits(parsed.getMonth() + 1)}-${twoDigits(parsed.getDate())}`;
}

function toTimeString(value) {
  if (value === null || value === undefined || value === '') return null;
  if (value instanceof Date) {
    return `${twoDigits(value.getHours())}:${twoDigits(value.getMinutes())}:${twoDigits(value.getSeconds())}`;
  }
  if (typeof value === 'number') {
    const totalSeconds = Math.round(value * 24 * 60 * 60);
    const hours = Math.floor(totalSeconds / 3600) % 24;
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;
    return `${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}`;
  }
  const text = String(value).trim();
  const match = text.match(/^(\d{1,2}):(\d{2})(?::(\d{2}))?$/);
  assert.ok(match, `Invalid time value "${text}"`);
  return `${twoDigits(match[1])}:${match[2]}:${match[3] ?? '00'}`;
}

function mapTransactionType(value, rowNumber) {
  const text = requiredText(value, 'Transaction Type', rowNumber).toLowerCase();
  if (text === 'debit/spend') return 'debit_spend';
  if (text === 'refund/reversal/credit') return 'refund_reversal';
  if (text === 'bill payment/credit') return 'bill_payment_credit';
  throw new Error(`Unsupported transaction type "${value}" on workbook row ${rowNumber}`);
}

function mapConfidence(value, rowNumber) {
  const text = requiredText(value, 'Confidence', rowNumber).toLowerCase();
  if (['high', 'medium', 'low', 'manual'].includes(text)) return text;
  throw new Error(`Unsupported confidence "${value}" on workbook row ${rowNumber}`);
}

function monthKeyFromDate(dateString) {
  return dateString.slice(0, 7);
}

export function createSourceFingerprint(transaction) {
  const parts = [
    'fy2025-26',
    transaction.transactionDate,
    transaction.transactionTime ?? '',
    normalizeName(transaction.cardholderName),
    normalizeName(transaction.statementMerchant),
    transaction.transactionType,
    formatMoney(transaction.amountPaise),
  ];
  const digest = createHash('sha256').update(parts.join('|')).digest('hex').slice(0, 32);
  return `workbook:fy2025-26:${digest}`;
}

export function merchantRuleMatches(rule, statementMerchant) {
  const normalizedName = normalizeName(statementMerchant);
  const pattern = normalizeName(rule.pattern);
  if (!pattern || !normalizedName) return false;

  switch (rule.matchType) {
    case 'exact':
      return normalizedName === pattern;
    case 'contains':
      return normalizedName.includes(pattern);
    case 'prefix':
      return normalizedName.startsWith(pattern);
    case 'suffix':
      return normalizedName.endsWith(pattern);
    case 'regex':
      try {
        return new RegExp(rule.pattern).test(normalizedName);
      } catch {
        return false;
      }
    default:
      return false;
  }
}

function ruleMatchRank(matchType) {
  switch (matchType) {
    case 'exact':
      return 0;
    case 'prefix':
      return 1;
    case 'suffix':
      return 2;
    case 'contains':
      return 3;
    default:
      return 4;
  }
}

function sortMerchantRules(rules) {
  return [...rules].sort((a, b) => {
    const rankDifference = ruleMatchRank(a.matchType) - ruleMatchRank(b.matchType);
    if (rankDifference !== 0) return rankDifference;

    const priorityDifference = (a.priority ?? 100) - (b.priority ?? 100);
    if (priorityDifference !== 0) return priorityDifference;

    return String(b.createdAt ?? '').localeCompare(String(a.createdAt ?? ''));
  });
}

export function findMerchantMappingRule(rules, statementMerchant) {
  return sortMerchantRules(rules).find((rule) => merchantRuleMatches(rule, statementMerchant)) ?? null;
}

export function classifyTransactionsWithRules(transactions, rules) {
  return transactions.map((transaction) => {
    const rule = findMerchantMappingRule(rules, transaction.statementMerchant);
    if (!rule) {
      return {
        ...transaction,
        mappingRuleId: null,
        mappingRuleCreatedBy: null,
        mappingRuleNotes: null,
      };
    }

    return {
      ...transaction,
      merchantGroup: rule.merchantGroup,
      category: rule.category,
      subcategory: rule.subcategory,
      confidence: rule.confidence ?? 'manual',
      mappingRuleId: rule.id,
      mappingRuleCreatedBy: rule.createdBy ?? null,
      mappingRuleNotes: rule.notes ?? null,
      mappingRuleMerchantId: rule.merchantId,
      mappingRuleCategoryId: rule.categoryId,
      mappingRuleSubcategoryId: rule.subcategoryId,
    };
  });
}

export function deterministicUuid(scope, input) {
  const bytes = createHash('sha1').update(`${scope}:${input}`).digest().subarray(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

function parseTransactionRow(row) {
  const transaction = {
    rowNumber: row.__rowNumber,
    transactionDate: toDateString(row.Date, 'Date', row.__rowNumber),
    transactionTime: toTimeString(row.Time),
    statementMonth: requiredText(row['Statement Month'], 'Statement Month', row.__rowNumber),
    cardholderName: requiredText(row.Cardholder, 'Cardholder', row.__rowNumber),
    statementMerchant: requiredText(row['Statement Merchant'], 'Statement Merchant', row.__rowNumber),
    merchantGroup: requiredText(row['Merchant Group'], 'Merchant Group', row.__rowNumber),
    category: requiredText(row.Category, 'Category', row.__rowNumber),
    subcategory: requiredText(row.Subcategory, 'Subcategory', row.__rowNumber),
    transactionType: mapTransactionType(row['Transaction Type'], row.__rowNumber),
    amountPaise: moneyToPaise(row.Amount),
    grossSpendPaise: moneyToPaise(row['Gross Spend']),
    refundPaise: moneyToPaise(row['Refund/Reversal']),
    netExpensePaise: moneyToPaise(row['Net Expense']),
    confidence: mapConfidence(row.Confidence, row.__rowNumber),
    notes: row.Notes ? String(row.Notes).trim() : null,
  };
  transaction.sourceFingerprint = createSourceFingerprint(transaction);
  transaction.monthKey = monthKeyFromDate(transaction.transactionDate);
  assert.equal(
    transaction.netExpensePaise,
    transaction.grossSpendPaise - transaction.refundPaise,
    `Net Expense does not match gross minus refunds on workbook row ${transaction.rowNumber}`,
  );
  return transaction;
}

function parseSummaryMoneyRows(rows, config) {
  return rows.map((row) => Object.fromEntries(
    Object.entries(config).map(([targetKey, source]) => [
      targetKey,
      source.kind === 'money' ? moneyToPaise(row[source.header]) : row[source.header],
    ]),
  ));
}

export async function readWorkbook(workbookPath = DEFAULT_WORKBOOK_PATH) {
  const workbookBuffer = await fs.readFile(workbookPath);
  const workbook = XLSX.read(workbookBuffer, { type: 'buffer', cellDates: true });
  const sheetRows = (name) => {
    const worksheet = workbook.Sheets[name];
    assert.ok(worksheet, `Workbook sheet not found: ${name}`);
    return worksheetRows(worksheet);
  };

  const transactions = sheetRows('Transactions').map(parseTransactionRow);
  const needsReviewTransactions = sheetRows('Needs Review').map(parseTransactionRow);
  const categorySummaries = parseSummaryMoneyRows(sheetRows('Category Summary'), {
    category: { header: 'Category' },
    txnCount: { header: 'Txn Count' },
    debitCount: { header: 'Debit Count' },
    grossSpendPaise: { header: 'Gross Spend', kind: 'money' },
    refundsPaise: { header: 'Refunds', kind: 'money' },
    netSpendPaise: { header: 'Net Spend', kind: 'money' },
  }).map((row) => ({
    ...row,
    category: String(row.category).trim(),
    txnCount: integerValue(row.txnCount),
    debitCount: integerValue(row.debitCount),
  }));

  const merchantSummaries = parseSummaryMoneyRows(sheetRows('Merchant Summary'), {
    merchantGroup: { header: 'Merchant Group' },
    category: { header: 'Category' },
    subcategory: { header: 'Subcategory' },
    txnCount: { header: 'Txn Count' },
    debitCount: { header: 'Debit Count' },
    grossSpendPaise: { header: 'Gross Spend', kind: 'money' },
    refundsPaise: { header: 'Refunds', kind: 'money' },
    netSpendPaise: { header: 'Net Spend', kind: 'money' },
    confidence: { header: 'Confidence' },
    notes: { header: 'Notes' },
    sourceUrl: { header: 'Source URL' },
  }).map((row) => ({
    ...row,
    merchantGroup: String(row.merchantGroup).trim(),
    category: String(row.category).trim(),
    subcategory: String(row.subcategory).trim(),
    txnCount: integerValue(row.txnCount),
    debitCount: integerValue(row.debitCount),
    confidence: String(row.confidence).trim().toLowerCase(),
    notes: row.notes ? String(row.notes).trim() : null,
    sourceUrl: row.sourceUrl ? String(row.sourceUrl).trim() : null,
  }));

  const monthlySummaries = parseSummaryMoneyRows(sheetRows('Monthly'), {
    month: { header: 'Month' },
    grossSpendPaise: { header: 'Gross Spend', kind: 'money' },
    refundsPaise: { header: 'Refunds', kind: 'money' },
    netSpendPaise: { header: 'Net Spend', kind: 'money' },
    cardBillPaymentsPaise: { header: 'Card Bill Payments', kind: 'money' },
  }).map((row) => ({ ...row, month: String(row.month).trim() }));

  const cardholderSummaries = parseSummaryMoneyRows(sheetRows('Cardholders'), {
    cardholderName: { header: 'Cardholder' },
    grossSpendPaise: { header: 'Gross Spend', kind: 'money' },
    refundsPaise: { header: 'Refunds', kind: 'money' },
    netSpendPaise: { header: 'Net Spend', kind: 'money' },
    cardBillPaymentsPaise: { header: 'Card Bill Payments', kind: 'money' },
  }).map((row) => ({ ...row, cardholderName: String(row.cardholderName).trim() }));

  const statementValidationRows = sheetRows('Validation')
    .filter((row) => row['Statement PDF'] && row['Parsed Purchase/Debits'] !== null)
    .map((row) => ({
      statementPdf: String(row['Statement PDF']).trim(),
      parsedDebitsPaise: moneyToPaise(row['Parsed Purchase/Debits']),
      statementDebitsPaise: moneyToPaise(row['Statement Purchase/Debits']),
      debitDifferencePaise: moneyToPaise(row['Debit Difference']),
      parsedCreditsPaise: moneyToPaise(row['Parsed Payment/Credits']),
      statementCreditsPaise: moneyToPaise(row['Statement Payment/Credits']),
      creditDifferencePaise: moneyToPaise(row['Credit Difference']),
    }));

  return {
    workbookPath,
    transactions,
    needsReviewTransactions,
    categorySummaries,
    merchantSummaries,
    monthlySummaries,
    cardholderSummaries,
    statementValidationRows,
  };
}

function emptyMoneySummary() {
  return {
    txnCount: 0,
    debitCount: 0,
    grossSpendPaise: 0,
    refundsPaise: 0,
    netSpendPaise: 0,
    cardBillPaymentsPaise: 0,
  };
}

function addMoneySummary(target, transaction) {
  target.txnCount += 1;
  if (transaction.transactionType === 'debit_spend') target.debitCount += 1;
  target.grossSpendPaise += transaction.grossSpendPaise;
  target.refundsPaise += transaction.refundPaise;
  target.netSpendPaise += transaction.netExpensePaise;
  if (transaction.transactionType === 'bill_payment_credit') {
    target.cardBillPaymentsPaise += Math.abs(transaction.amountPaise);
  }
}

function mapToRows(map, keyName) {
  return [...map.entries()].map(([key, value]) => ({ [keyName]: key, ...value }));
}

export function summarizeTransactions(transactions) {
  const totals = emptyMoneySummary();
  const monthly = new Map();
  const categories = new Map();
  const merchants = new Map();
  const cardholders = new Map();

  for (const transaction of transactions) {
    addMoneySummary(totals, transaction);

    const monthlySummary = monthly.get(transaction.monthKey) ?? emptyMoneySummary();
    addMoneySummary(monthlySummary, transaction);
    monthly.set(transaction.monthKey, monthlySummary);

    const cardholderSummary = cardholders.get(transaction.cardholderName) ?? emptyMoneySummary();
    addMoneySummary(cardholderSummary, transaction);
    cardholders.set(transaction.cardholderName, cardholderSummary);

    if (transaction.transactionType !== 'bill_payment_credit') {
      const categorySummary = categories.get(transaction.category) ?? emptyMoneySummary();
      addMoneySummary(categorySummary, transaction);
      categories.set(transaction.category, categorySummary);

      const merchantKey = [
        transaction.merchantGroup,
        transaction.category,
        transaction.subcategory,
      ].join('|');
      const merchantSummary = merchants.get(merchantKey) ?? {
        merchantGroup: transaction.merchantGroup,
        category: transaction.category,
        subcategory: transaction.subcategory,
        ...emptyMoneySummary(),
      };
      addMoneySummary(merchantSummary, transaction);
      merchants.set(merchantKey, merchantSummary);
    }
  }

  return {
    totals,
    monthly: mapToRows(monthly, 'month').sort((a, b) => a.month.localeCompare(b.month)),
    categories: mapToRows(categories, 'category').sort((a, b) => a.category.localeCompare(b.category)),
    merchants: [...merchants.values()].sort((a, b) => a.merchantGroup.localeCompare(b.merchantGroup)),
    cardholders: mapToRows(cardholders, 'cardholderName').sort((a, b) => a.cardholderName.localeCompare(b.cardholderName)),
  };
}

export function filterWorkbookDataForSuppression(data, tombstonedFingerprints) {
  const tombstones = tombstonedFingerprints instanceof Set
    ? tombstonedFingerprints
    : new Set(tombstonedFingerprints);
  const transactions = [];
  const suppressedTransactions = [];

  for (const transaction of data.transactions) {
    if (tombstones.has(transaction.sourceFingerprint)) {
      suppressedTransactions.push(transaction);
    } else {
      transactions.push(transaction);
    }
  }

  const importedFingerprints = new Set(
    transactions.map((transaction) => transaction.sourceFingerprint),
  );
  const suppressedSummary = summarizeTransactions(suppressedTransactions);

  return {
    importData: {
      ...data,
      transactions,
      needsReviewTransactions: data.needsReviewTransactions.filter((transaction) =>
        importedFingerprints.has(transaction.sourceFingerprint)
      ),
    },
    suppression: {
      suppressedCount: suppressedTransactions.length,
      importedCount: transactions.length,
      suppressedGrossSpendPaise: suppressedSummary.totals.grossSpendPaise,
      suppressedRefundsPaise: suppressedSummary.totals.refundsPaise,
      suppressedNetExpensePaise: suppressedSummary.totals.netSpendPaise,
      suppressedCardBillPaymentsPaise: suppressedSummary.totals.cardBillPaymentsPaise,
    },
  };
}

function compareRows(name, expectedRows, actualRows, keyFields, moneyFields, countFields = []) {
  const keyFor = (row) => keyFields.map((field) => row[field]).join('|');
  const expected = new Map(expectedRows.map((row) => [keyFor(row), row]));
  const actual = new Map(actualRows.map((row) => [keyFor(row), row]));

  assert.deepEqual([...actual.keys()].sort(), [...expected.keys()].sort(), `${name} keys match workbook`);
  for (const [key, expectedRow] of expected.entries()) {
    const actualRow = actual.get(key);
    for (const field of countFields) {
      assert.equal(actualRow[field], expectedRow[field], `${name} ${key} ${field}`);
    }
    for (const field of moneyFields) {
      assert.equal(actualRow[field], expectedRow[field], `${name} ${key} ${field}`);
    }
  }
}

export function validateWorkbookData(data) {
  const summary = summarizeTransactions(data.transactions);
  assert.equal(summary.totals.txnCount, EXPECTED_FIXTURE.transactionCount, 'workbook transaction count');
  assert.equal(summary.totals.grossSpendPaise, EXPECTED_FIXTURE.grossSpendPaise, 'workbook gross spend');
  assert.equal(summary.totals.refundsPaise, EXPECTED_FIXTURE.refundsPaise, 'workbook refunds');
  assert.equal(summary.totals.netSpendPaise, EXPECTED_FIXTURE.netExpensePaise, 'workbook net expense');
  assert.equal(summary.totals.cardBillPaymentsPaise, EXPECTED_FIXTURE.cardBillPaymentsPaise, 'workbook card bill payments');

  const fingerprints = new Set(data.transactions.map((transaction) => transaction.sourceFingerprint));
  assert.equal(fingerprints.size, data.transactions.length, 'source fingerprints are unique');

  compareRows(
    'monthly summary',
    data.monthlySummaries,
    summary.monthly,
    ['month'],
    ['grossSpendPaise', 'refundsPaise', 'netSpendPaise', 'cardBillPaymentsPaise'],
  );
  compareRows(
    'category summary',
    data.categorySummaries,
    summary.categories,
    ['category'],
    ['grossSpendPaise', 'refundsPaise', 'netSpendPaise'],
    ['txnCount', 'debitCount'],
  );
  compareRows(
    'merchant summary',
    data.merchantSummaries,
    summary.merchants,
    ['merchantGroup', 'category', 'subcategory'],
    ['grossSpendPaise', 'refundsPaise', 'netSpendPaise'],
    ['txnCount', 'debitCount'],
  );
  compareRows(
    'cardholder summary',
    data.cardholderSummaries,
    summary.cardholders,
    ['cardholderName'],
    ['grossSpendPaise', 'refundsPaise', 'netSpendPaise', 'cardBillPaymentsPaise'],
  );

  const needsReviewFingerprints = new Set(
    data.needsReviewTransactions.map((transaction) => transaction.sourceFingerprint),
  );
  const nonHighConfidenceFingerprints = new Set(
    data.transactions
      .filter((transaction) => transaction.confidence !== 'high')
      .map((transaction) => transaction.sourceFingerprint),
  );
  assert.equal(needsReviewFingerprints.size, EXPECTED_FIXTURE.reviewItemCount, 'Needs Review row count');
  assert.deepEqual(
    [...needsReviewFingerprints].sort(),
    [...nonHighConfidenceFingerprints].sort(),
    'Needs Review rows match non-high-confidence transactions',
  );

  for (const row of data.statementValidationRows) {
    assert.equal(row.debitDifferencePaise, 0, `${row.statementPdf} debit reconciliation`);
    assert.equal(row.creditDifferencePaise, 0, `${row.statementPdf} credit reconciliation`);
  }

  return summary;
}

function uniqueInOrder(values) {
  const seen = new Set();
  return values.filter((value) => {
    const key = normalizeName(value);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function categoryNames(data) {
  return uniqueInOrder([
    ...data.categorySummaries.map((row) => row.category),
    ...data.transactions.map((transaction) => transaction.category),
  ]);
}

function subcategoryRows(data) {
  return uniqueInOrder([
    ...data.merchantSummaries.map((row) => `${row.category}|${row.subcategory}`),
    ...data.transactions.map((transaction) => `${transaction.category}|${transaction.subcategory}`),
  ]).map((value) => {
    const [category, subcategory] = value.split('|');
    return { category, subcategory };
  });
}

function merchantRows(data) {
  const byName = new Map();
  for (const row of data.merchantSummaries) {
    byName.set(row.merchantGroup, row);
  }
  for (const transaction of data.transactions) {
    if (!byName.has(transaction.merchantGroup)) {
      byName.set(transaction.merchantGroup, {
        merchantGroup: transaction.merchantGroup,
        category: transaction.category,
        subcategory: transaction.subcategory,
        confidence: transaction.confidence,
        notes: transaction.notes,
        sourceUrl: null,
      });
    }
  }
  return [...byName.values()];
}

function sourceAccountRows(data) {
  return data.cardholderSummaries.map((row) => ({
    cardholderName: row.cardholderName,
    displayName: `${row.cardholderName} HDFC Infinia`,
    institutionName: 'HDFC Bank',
  }));
}

async function queryOne(client, sql, params = []) {
  const result = await client.query(sql, params);
  assert.equal(result.rows.length, 1, `Expected one row from query: ${sql}`);
  return result.rows[0];
}

async function seedHousehold(client, options) {
  await client.query('insert into auth.users (id) values ($1) on conflict (id) do nothing', [options.authUserId]);
  await client.query(
    `insert into public.profiles (id, auth_user_id, display_name, email)
     values ($1, $2, $3, $4)
     on conflict (id) do update
       set display_name = excluded.display_name,
           email = excluded.email`,
    [options.profileId, options.authUserId, 'SpendLens Workbook Import', 'workbook-import@example.test'],
  );
  await client.query(
    `insert into public.households (id, name, created_by)
     values ($1, $2, $3)
     on conflict (id) do update
       set name = excluded.name`,
    [options.householdId, options.householdName, options.profileId],
  );
  await client.query(
    `insert into public.household_members (id, household_id, profile_id, role, is_active)
     values ($1, $2, $3, 'owner', true)
     on conflict (household_id, profile_id) do update
       set role = excluded.role,
           is_active = excluded.is_active`,
    [options.householdMemberId, options.householdId, options.profileId],
  );
}

async function upsertImportBatch(client, options) {
  const batchId = deterministicUuid('import_batch', `${options.householdId}:${IMPORT_BATCH_SOURCE_LABEL}`);
  await client.query(
    `insert into public.import_batches (
       id, household_id, source_type, source_label, status, started_at, row_count, created_by
     )
     values ($1, $2, 'workbook', $3, 'processing', now(), 0, $4)
     on conflict (id) do update
       set status = 'processing',
           started_at = now(),
           completed_at = null,
           row_count = 0,
           inserted_count = 0,
           updated_count = 0,
           duplicate_count = 0,
           validation_summary = '{}'::jsonb,
           error_message = null`,
    [batchId, options.householdId, IMPORT_BATCH_SOURCE_LABEL, options.profileId],
  );
  return batchId;
}

async function upsertCategories(client, data, options) {
  const categories = new Map();
  const names = categoryNames(data);
  for (let index = 0; index < names.length; index += 1) {
    const name = names[index];
    const id = deterministicUuid('category', `${options.householdId}:${normalizeName(name)}`);
    const row = await queryOne(
      client,
      `insert into public.categories (id, household_id, name, sort_order, is_system)
       values ($1, $2, $3, $4, true)
       on conflict (household_id, (lower(name))) do update
         set sort_order = excluded.sort_order,
             is_system = excluded.is_system
       returning id`,
      [id, options.householdId, name, index + 1],
    );
    categories.set(name, row.id);
  }
  return categories;
}

async function upsertSubcategories(client, data, options, categories) {
  const subcategories = new Map();
  const sortOrders = new Map();
  for (const row of subcategoryRows(data)) {
    const categoryId = categories.get(row.category);
    assert.ok(categoryId, `Category missing for subcategory ${row.category} / ${row.subcategory}`);
    const categorySortOrder = (sortOrders.get(row.category) ?? 0) + 1;
    sortOrders.set(row.category, categorySortOrder);
    const id = deterministicUuid(
      'subcategory',
      `${options.householdId}:${normalizeName(row.category)}:${normalizeName(row.subcategory)}`,
    );
    const saved = await queryOne(
      client,
      `insert into public.subcategories (id, household_id, category_id, name, sort_order)
       values ($1, $2, $3, $4, $5)
       on conflict (category_id, (lower(name))) do update
         set sort_order = excluded.sort_order
       returning id`,
      [id, options.householdId, categoryId, row.subcategory, categorySortOrder],
    );
    subcategories.set(`${row.category}|${row.subcategory}`, saved.id);
  }
  return subcategories;
}

async function upsertSourceAccounts(client, data, options) {
  const accounts = new Map();
  for (const row of sourceAccountRows(data)) {
    const id = deterministicUuid('source_account', `${options.householdId}:${normalizeName(row.cardholderName)}`);
    await client.query(
      `insert into public.source_accounts (
         id, household_id, type, display_name, institution_name, cardholder_name, is_active
       )
       values ($1, $2, 'credit_card', $3, $4, $5, true)
       on conflict (id) do update
         set display_name = excluded.display_name,
             institution_name = excluded.institution_name,
             cardholder_name = excluded.cardholder_name,
             is_active = excluded.is_active`,
      [id, options.householdId, row.displayName, row.institutionName, row.cardholderName],
    );
    accounts.set(row.cardholderName, id);
  }
  return accounts;
}

async function fetchMerchantMappingRules(client, options) {
  const result = await client.query(
    `select
       mmr.id,
       mmr.pattern,
       mmr.match_type,
       mmr.priority,
       mmr.confidence,
       mmr.created_by,
       mmr.created_at,
       mmr.notes,
       mmr.merchant_id,
       m.display_name as merchant_group,
       mmr.category_id,
       c.name as category,
       mmr.subcategory_id,
       sc.name as subcategory
     from public.merchant_mapping_rules mmr
     join public.merchants m on m.id = mmr.merchant_id and m.household_id = mmr.household_id
     join public.categories c on c.id = mmr.category_id and c.household_id = mmr.household_id
     join public.subcategories sc on sc.id = mmr.subcategory_id and sc.household_id = mmr.household_id
     where mmr.household_id = $1
       and mmr.apply_to_future
     order by
       case mmr.match_type
         when 'exact' then 0
         when 'prefix' then 1
         when 'suffix' then 2
         when 'contains' then 3
         else 4
       end,
       mmr.priority,
       mmr.created_at desc`,
    [options.householdId],
  );

  return result.rows.map((row) => ({
    id: row.id,
    pattern: row.pattern,
    matchType: row.match_type,
    priority: integerValue(row.priority),
    confidence: row.confidence,
    createdBy: row.created_by,
    createdAt: row.created_at,
    notes: row.notes,
    merchantId: row.merchant_id,
    merchantGroup: row.merchant_group,
    categoryId: row.category_id,
    category: row.category,
    subcategoryId: row.subcategory_id,
    subcategory: row.subcategory,
  }));
}

async function upsertMerchants(client, data, options, categories, subcategories) {
  const merchants = new Map();
  for (const row of merchantRows(data)) {
    const categoryId = categories.get(row.category);
    const subcategoryId = subcategories.get(`${row.category}|${row.subcategory}`);
    assert.ok(categoryId, `Category missing for merchant ${row.merchantGroup}`);
    assert.ok(subcategoryId, `Subcategory missing for merchant ${row.merchantGroup}`);
    const id = deterministicUuid('merchant', `${options.householdId}:${normalizeName(row.merchantGroup)}`);
    await client.query(
      `insert into public.merchants (
         id, household_id, display_name, category_id, subcategory_id, confidence, notes, source_url
       )
       values ($1, $2, $3, $4, $5, $6, $7, $8)
       on conflict (id) do update
         set display_name = excluded.display_name,
             category_id = excluded.category_id,
             subcategory_id = excluded.subcategory_id,
             confidence = excluded.confidence,
             notes = excluded.notes,
             source_url = excluded.source_url`,
      [
        id,
        options.householdId,
        row.merchantGroup,
        categoryId,
        subcategoryId,
        row.confidence,
        row.notes,
        row.sourceUrl,
      ],
    );
    merchants.set(row.merchantGroup, id);
  }
  return merchants;
}

async function upsertMerchantAliases(client, data, options, merchants) {
  const aliases = new Map();
  for (const transaction of data.transactions) {
    const normalizedName = normalizeName(transaction.statementMerchant);
    const merchantId = transaction.mappingRuleMerchantId ?? merchants.get(transaction.merchantGroup);
    assert.ok(merchantId, `Missing merchant id for alias ${transaction.statementMerchant}`);
    const existing = aliases.get(normalizedName) ?? {
      rawName: transaction.statementMerchant,
      merchantId,
      sourceType: transaction.mappingRuleId ? 'manual' : 'workbook',
      firstSeenAt: `${transaction.transactionDate}T00:00:00+05:30`,
      lastSeenAt: `${transaction.transactionDate}T00:00:00+05:30`,
    };
    if (transaction.mappingRuleId) {
      existing.merchantId = merchantId;
      existing.sourceType = 'manual';
    }
    const currentSeenAt = `${transaction.transactionDate}T00:00:00+05:30`;
    if (currentSeenAt < existing.firstSeenAt) existing.firstSeenAt = currentSeenAt;
    if (currentSeenAt > existing.lastSeenAt) existing.lastSeenAt = currentSeenAt;
    aliases.set(normalizedName, existing);
  }

  for (const [normalizedName, alias] of aliases.entries()) {
    const id = deterministicUuid('merchant_alias', `${options.householdId}:${normalizedName}`);
    await client.query(
      `insert into public.merchant_aliases (
         id, household_id, merchant_id, raw_name, normalized_name, source_type, first_seen_at, last_seen_at
       )
       values ($1, $2, $3, $4, $5, $6, $7, $8)
       on conflict (household_id, normalized_name) do update
         set merchant_id = excluded.merchant_id,
             raw_name = excluded.raw_name,
             source_type = excluded.source_type,
             first_seen_at = coalesce(
               least(public.merchant_aliases.first_seen_at, excluded.first_seen_at),
               public.merchant_aliases.first_seen_at,
               excluded.first_seen_at
             ),
             last_seen_at = coalesce(
               greatest(public.merchant_aliases.last_seen_at, excluded.last_seen_at),
               public.merchant_aliases.last_seen_at,
               excluded.last_seen_at
             )`,
      [
        id,
        options.householdId,
        alias.merchantId,
        alias.rawName,
        normalizedName,
        alias.sourceType,
        alias.firstSeenAt,
        alias.lastSeenAt,
      ],
    );
  }
  return aliases;
}

function transactionId(options, transaction) {
  return deterministicUuid('transaction', `${options.householdId}:${transaction.sourceFingerprint}`);
}

function occurredAt(transaction) {
  if (!transaction.transactionTime) return null;
  return `${transaction.transactionDate}T${transaction.transactionTime}+05:30`;
}

async function existingFingerprints(client, options) {
  const result = await client.query(
    `select source_fingerprint
     from public.transactions
     where household_id = $1
       and source_type = 'workbook'`,
    [options.householdId],
  );
  return new Set(result.rows.map((row) => row.source_fingerprint));
}

async function tombstonedWorkbookFingerprints(client, options) {
  const result = await client.query(
    `select source_fingerprint
     from public.deleted_transaction_sources
     where household_id = $1
       and source_type = 'workbook'`,
    [options.householdId],
  );
  return new Set(result.rows.map((row) => row.source_fingerprint));
}

function transactionClassificationIds(transaction, lookups) {
  const categoryId = transaction.mappingRuleCategoryId ?? lookups.categories.get(transaction.category);
  const subcategoryId = transaction.mappingRuleSubcategoryId
    ?? lookups.subcategories.get(`${transaction.category}|${transaction.subcategory}`);
  const merchantId = transaction.mappingRuleMerchantId ?? lookups.merchants.get(transaction.merchantGroup);

  return { categoryId, subcategoryId, merchantId };
}

async function upsertTransactions(client, data, options, lookups) {
  const existing = await existingFingerprints(client, options);
  let insertedCount = 0;
  let updatedCount = 0;

  for (const transaction of data.transactions) {
    const { categoryId, subcategoryId, merchantId } = transactionClassificationIds(transaction, lookups);
    const sourceAccountId = lookups.sourceAccounts.get(transaction.cardholderName);
    assert.ok(categoryId, `Missing category id for ${transaction.category}`);
    assert.ok(subcategoryId, `Missing subcategory id for ${transaction.subcategory}`);
    assert.ok(merchantId, `Missing merchant id for ${transaction.merchantGroup}`);
    assert.ok(sourceAccountId, `Missing source account id for ${transaction.cardholderName}`);

    await client.query(
      `insert into public.transactions (
         id,
         household_id,
         source_account_id,
         source_type,
         occurred_at,
         transaction_date,
         transaction_time,
         statement_month,
         cardholder_name,
         statement_merchant,
         normalized_statement_merchant,
         merchant_id,
         category_id,
         subcategory_id,
         transaction_type,
         amount,
         gross_spend,
         refund_amount,
         net_expense,
         currency_code,
         confidence,
         notes,
         source_fingerprint,
         classification_rule_id,
         classification_updated_by,
         classification_updated_at,
         classification_note
       )
       values (
         $1, $2, $3, 'workbook', $4, $5, $6, $7, $8, $9, $10, $11,
         $12, $13, $14, $15, $16, $17, $18, 'INR', $19, $20, $21,
         $22, $23, case when $22::uuid is null then null else now() end, $24
       )
       on conflict (household_id, source_fingerprint) do update
         set source_account_id = excluded.source_account_id,
             occurred_at = excluded.occurred_at,
             transaction_date = excluded.transaction_date,
             transaction_time = excluded.transaction_time,
             statement_month = excluded.statement_month,
             cardholder_name = excluded.cardholder_name,
             statement_merchant = excluded.statement_merchant,
             normalized_statement_merchant = excluded.normalized_statement_merchant,
             merchant_id = excluded.merchant_id,
             category_id = excluded.category_id,
             subcategory_id = excluded.subcategory_id,
             transaction_type = excluded.transaction_type,
             amount = excluded.amount,
             gross_spend = excluded.gross_spend,
             refund_amount = excluded.refund_amount,
             net_expense = excluded.net_expense,
             currency_code = excluded.currency_code,
             confidence = excluded.confidence,
             notes = excluded.notes,
             classification_rule_id = excluded.classification_rule_id,
             classification_updated_by = excluded.classification_updated_by,
             classification_updated_at = excluded.classification_updated_at,
             classification_note = excluded.classification_note`,
      [
        transactionId(options, transaction),
        options.householdId,
        sourceAccountId,
        occurredAt(transaction),
        transaction.transactionDate,
        transaction.transactionTime,
        transaction.statementMonth,
        transaction.cardholderName,
        transaction.statementMerchant,
        normalizeName(transaction.statementMerchant),
        merchantId,
        categoryId,
        subcategoryId,
        transaction.transactionType,
        formatMoney(transaction.amountPaise),
        formatMoney(transaction.grossSpendPaise),
        formatMoney(transaction.refundPaise),
        formatMoney(transaction.netExpensePaise),
        transaction.confidence,
        transaction.notes,
        transaction.sourceFingerprint,
        transaction.mappingRuleId,
        transaction.mappingRuleId ? (transaction.mappingRuleCreatedBy ?? options.profileId) : null,
        transaction.mappingRuleId ? transaction.mappingRuleNotes : null,
      ],
    );

    if (existing.has(transaction.sourceFingerprint)) updatedCount += 1;
    else insertedCount += 1;
  }

  return {
    rowCount: data.transactions.length,
    insertedCount,
    updatedCount,
    duplicateCount: updatedCount,
  };
}

async function upsertTransactionSources(client, data, options, batchId) {
  for (const transaction of data.transactions) {
    const id = deterministicUuid('transaction_source', `${batchId}:${transaction.sourceFingerprint}`);
    await client.query(
      `insert into public.transaction_sources (
         id,
         household_id,
         transaction_id,
         import_batch_id,
         source_type,
         source_reference,
         parser_name,
         parser_version,
         parse_status,
         diagnostics
       )
       values ($1, $2, $3, $4, 'workbook', $5, $6, $7, 'parsed', $8::jsonb)
       on conflict (id) do update
         set import_batch_id = excluded.import_batch_id,
             source_reference = excluded.source_reference,
             parser_name = excluded.parser_name,
             parser_version = excluded.parser_version,
             parse_status = excluded.parse_status,
             diagnostics = excluded.diagnostics`,
      [
        id,
        options.householdId,
        transactionId(options, transaction),
        batchId,
        `Transactions!${transaction.rowNumber}`,
        PARSER_NAME,
        PARSER_VERSION,
        JSON.stringify({
          workbook: IMPORT_SOURCE_LABEL,
          sheet: 'Transactions',
          row_number: transaction.rowNumber,
          source_fingerprint: transaction.sourceFingerprint,
        }),
      ],
    );
  }
}

function reviewReason(transaction, needsReviewFingerprints) {
  if (transaction.confidence === 'low') {
    return transaction.notes ? `Low confidence: ${transaction.notes}` : 'Low confidence workbook classification';
  }
  if (needsReviewFingerprints.has(transaction.sourceFingerprint)) {
    return transaction.notes ? `Needs review: ${transaction.notes}` : 'Needs workbook review';
  }
  return null;
}

async function upsertReviewItems(client, data, options, lookups) {
  const needsReviewFingerprints = new Set(
    data.needsReviewTransactions.map((transaction) => transaction.sourceFingerprint),
  );
  let reviewItemCount = 0;
  const reviewItemIds = [];

  for (const transaction of data.transactions) {
    const reason = reviewReason(transaction, needsReviewFingerprints);
    if (!reason) continue;
    reviewItemCount += 1;
    const id = deterministicUuid('review_item', `${options.householdId}:${transaction.sourceFingerprint}:workbook_review`);
    reviewItemIds.push(id);
    await client.query(
      `insert into public.review_items (
         id,
         household_id,
         transaction_id,
         reason,
         status,
         suggested_merchant_id,
         suggested_category_id,
         suggested_subcategory_id
       )
       values ($1, $2, $3, $4, 'open', $5, $6, $7)
       on conflict (id) do update
         set transaction_id = excluded.transaction_id,
             reason = excluded.reason,
             suggested_merchant_id = excluded.suggested_merchant_id,
             suggested_category_id = excluded.suggested_category_id,
             suggested_subcategory_id = excluded.suggested_subcategory_id`,
      [
        id,
        options.householdId,
        transactionId(options, transaction),
        reason,
        transactionClassificationIds(transaction, lookups).merchantId,
        transactionClassificationIds(transaction, lookups).categoryId,
        transactionClassificationIds(transaction, lookups).subcategoryId,
      ],
    );
  }

  return { reviewItemCount, reviewItemIds };
}

function moneyRowFromDb(row, fields) {
  return Object.fromEntries(fields.map((field) => [field, moneyToPaise(row[field])]));
}

function countRowFromDb(row, fields) {
  return Object.fromEntries(fields.map((field) => [field, integerValue(row[field])]));
}

async function databaseTotals(client, options) {
  const row = await queryOne(
    client,
    `select
       count(*)::integer as transaction_count,
       coalesce(sum(gross_spend), 0)::text as gross_spend,
       coalesce(sum(refund_amount), 0)::text as refunds,
       coalesce(sum(net_expense), 0)::text as net_expense,
       coalesce(sum(case when transaction_type = 'bill_payment_credit' then abs(amount) else 0 end), 0)::text as card_bill_payments
     from public.transactions
     where household_id = $1
       and source_type = 'workbook'`,
    [options.householdId],
  );
  return {
    transactionCount: integerValue(row.transaction_count),
    grossSpendPaise: moneyToPaise(row.gross_spend),
    refundsPaise: moneyToPaise(row.refunds),
    netExpensePaise: moneyToPaise(row.net_expense),
    cardBillPaymentsPaise: moneyToPaise(row.card_bill_payments),
  };
}

async function databaseMonthlyRows(client, options) {
  const result = await client.query(
    `select
       to_char(date_trunc('month', transaction_date), 'YYYY-MM') as month,
       count(*)::integer as txn_count,
       count(*) filter (where transaction_type = 'debit_spend')::integer as debit_count,
       coalesce(sum(gross_spend), 0)::text as gross_spend,
       coalesce(sum(refund_amount), 0)::text as refunds,
       coalesce(sum(net_expense), 0)::text as net_spend,
       coalesce(sum(case when transaction_type = 'bill_payment_credit' then abs(amount) else 0 end), 0)::text as card_bill_payments
     from public.transactions
     where household_id = $1
       and source_type = 'workbook'
     group by date_trunc('month', transaction_date)
     order by month`,
    [options.householdId],
  );
  return result.rows.map((row) => ({
    month: row.month,
    ...countRowFromDb(row, ['txn_count', 'debit_count']),
    ...moneyRowFromDb(row, ['gross_spend', 'refunds', 'net_spend', 'card_bill_payments']),
    txnCount: integerValue(row.txn_count),
    debitCount: integerValue(row.debit_count),
    grossSpendPaise: moneyToPaise(row.gross_spend),
    refundsPaise: moneyToPaise(row.refunds),
    netSpendPaise: moneyToPaise(row.net_spend),
    cardBillPaymentsPaise: moneyToPaise(row.card_bill_payments),
  }));
}

async function databaseCategoryRows(client, options) {
  const result = await client.query(
    `select
       c.name as category,
       count(*)::integer as txn_count,
       count(*) filter (where t.transaction_type = 'debit_spend')::integer as debit_count,
       coalesce(sum(t.gross_spend), 0)::text as gross_spend,
       coalesce(sum(t.refund_amount), 0)::text as refunds,
       coalesce(sum(t.net_expense), 0)::text as net_spend
     from public.transactions t
     join public.categories c on c.id = t.category_id and c.household_id = t.household_id
     where t.household_id = $1
       and t.source_type = 'workbook'
       and t.transaction_type <> 'bill_payment_credit'
     group by c.name
     order by c.name`,
    [options.householdId],
  );
  return result.rows.map((row) => ({
    category: row.category,
    txnCount: integerValue(row.txn_count),
    debitCount: integerValue(row.debit_count),
    grossSpendPaise: moneyToPaise(row.gross_spend),
    refundsPaise: moneyToPaise(row.refunds),
    netSpendPaise: moneyToPaise(row.net_spend),
  }));
}

async function databaseMerchantRows(client, options) {
  const result = await client.query(
    `select
       m.display_name as merchant_group,
       c.name as category,
       sc.name as subcategory,
       count(*)::integer as txn_count,
       count(*) filter (where t.transaction_type = 'debit_spend')::integer as debit_count,
       coalesce(sum(t.gross_spend), 0)::text as gross_spend,
       coalesce(sum(t.refund_amount), 0)::text as refunds,
       coalesce(sum(t.net_expense), 0)::text as net_spend
     from public.transactions t
     join public.merchants m on m.id = t.merchant_id and m.household_id = t.household_id
     join public.categories c on c.id = t.category_id and c.household_id = t.household_id
     join public.subcategories sc on sc.id = t.subcategory_id and sc.household_id = t.household_id
     where t.household_id = $1
       and t.source_type = 'workbook'
       and t.transaction_type <> 'bill_payment_credit'
     group by m.display_name, c.name, sc.name
     order by m.display_name`,
    [options.householdId],
  );
  return result.rows.map((row) => ({
    merchantGroup: row.merchant_group,
    category: row.category,
    subcategory: row.subcategory,
    txnCount: integerValue(row.txn_count),
    debitCount: integerValue(row.debit_count),
    grossSpendPaise: moneyToPaise(row.gross_spend),
    refundsPaise: moneyToPaise(row.refunds),
    netSpendPaise: moneyToPaise(row.net_spend),
  }));
}

async function databaseCardholderRows(client, options) {
  const result = await client.query(
    `select
       cardholder_name,
       coalesce(sum(gross_spend), 0)::text as gross_spend,
       coalesce(sum(refund_amount), 0)::text as refunds,
       coalesce(sum(net_expense), 0)::text as net_spend,
       coalesce(sum(case when transaction_type = 'bill_payment_credit' then abs(amount) else 0 end), 0)::text as card_bill_payments
     from public.transactions
     where household_id = $1
       and source_type = 'workbook'
     group by cardholder_name
     order by cardholder_name`,
    [options.householdId],
  );
  return result.rows.map((row) => ({
    cardholderName: row.cardholder_name,
    grossSpendPaise: moneyToPaise(row.gross_spend),
    refundsPaise: moneyToPaise(row.refunds),
    netSpendPaise: moneyToPaise(row.net_spend),
    cardBillPaymentsPaise: moneyToPaise(row.card_bill_payments),
  }));
}

async function databaseMetadataCounts(client, options, batchId, reviewItemIds) {
  const row = await queryOne(
    client,
    `select
       (select count(*) from public.source_accounts where household_id = $1 and type = 'credit_card')::integer as source_accounts,
       (select count(*) from public.merchant_aliases where household_id = $1 and source_type = 'workbook')::integer as merchant_aliases,
       (select count(*) from public.transaction_sources where household_id = $1 and import_batch_id = $2 and source_type = 'workbook')::integer as transaction_sources,
       (select count(*) from public.review_items where household_id = $1 and id = any($3::uuid[]))::integer as review_items,
       (select count(*) from public.review_items where household_id = $1 and id = any($3::uuid[]) and status = 'open')::integer as open_review_items,
       (select count(*) from public.import_batches where id = $2 and household_id = $1)::integer as import_batches`,
    [options.householdId, batchId, reviewItemIds],
  );
  return {
    sourceAccounts: integerValue(row.source_accounts),
    merchantAliases: integerValue(row.merchant_aliases),
    transactionSources: integerValue(row.transaction_sources),
    reviewItems: integerValue(row.review_items),
    openReviewItems: integerValue(row.open_review_items),
    importBatches: integerValue(row.import_batches),
  };
}

async function validateDatabaseImport(client, data, options, batchId, reviewItemIds) {
  const expectedSummary = summarizeTransactions(data.transactions);
  const totals = await databaseTotals(client, options);
  assert.equal(totals.transactionCount, expectedSummary.totals.txnCount, 'database transaction count');
  assert.equal(totals.grossSpendPaise, expectedSummary.totals.grossSpendPaise, 'database gross spend');
  assert.equal(totals.refundsPaise, expectedSummary.totals.refundsPaise, 'database refunds');
  assert.equal(totals.netExpensePaise, expectedSummary.totals.netSpendPaise, 'database net expense');
  assert.equal(
    totals.cardBillPaymentsPaise,
    expectedSummary.totals.cardBillPaymentsPaise,
    'database card bill payments',
  );

  compareRows(
    'database monthly summary',
    expectedSummary.monthly,
    await databaseMonthlyRows(client, options),
    ['month'],
    ['grossSpendPaise', 'refundsPaise', 'netSpendPaise', 'cardBillPaymentsPaise'],
  );
  compareRows(
    'database category summary',
    expectedSummary.categories,
    await databaseCategoryRows(client, options),
    ['category'],
    ['grossSpendPaise', 'refundsPaise', 'netSpendPaise'],
    ['txnCount', 'debitCount'],
  );
  compareRows(
    'database merchant summary',
    expectedSummary.merchants,
    await databaseMerchantRows(client, options),
    ['merchantGroup', 'category', 'subcategory'],
    ['grossSpendPaise', 'refundsPaise', 'netSpendPaise'],
    ['txnCount', 'debitCount'],
  );
  compareRows(
    'database cardholder summary',
    expectedSummary.cardholders,
    await databaseCardholderRows(client, options),
    ['cardholderName'],
    ['grossSpendPaise', 'refundsPaise', 'netSpendPaise', 'cardBillPaymentsPaise'],
  );

  const metadata = await databaseMetadataCounts(client, options, batchId, reviewItemIds);
  assert.equal(metadata.importBatches, 1, 'one deterministic import batch exists');
  assert.equal(metadata.sourceAccounts, data.cardholderSummaries.length, 'source account count');
  assert.equal(metadata.transactionSources, data.transactions.length, 'transaction source metadata count');
  assert.equal(metadata.reviewItems, reviewItemIds.length, 'review item count');

  return { totals, metadata };
}

function validationSummary(workbookSummary, databaseSummary, importCounts, adjustedSummary = workbookSummary) {
  return {
    status: 'passed',
    workbook: {
      transaction_count: workbookSummary.totals.txnCount,
      gross_spend: formatMoney(workbookSummary.totals.grossSpendPaise),
      refunds: formatMoney(workbookSummary.totals.refundsPaise),
      net_expense: formatMoney(workbookSummary.totals.netSpendPaise),
      card_bill_payments: formatMoney(workbookSummary.totals.cardBillPaymentsPaise),
      monthly_rows: workbookSummary.monthly.length,
      category_rows: workbookSummary.categories.length,
      merchant_rows: workbookSummary.merchants.length,
      cardholder_rows: workbookSummary.cardholders.length,
    },
    adjusted_expected: {
      transaction_count: adjustedSummary.totals.txnCount,
      gross_spend: formatMoney(adjustedSummary.totals.grossSpendPaise),
      refunds: formatMoney(adjustedSummary.totals.refundsPaise),
      net_expense: formatMoney(adjustedSummary.totals.netSpendPaise),
      card_bill_payments: formatMoney(adjustedSummary.totals.cardBillPaymentsPaise),
    },
    database: {
      transaction_count: databaseSummary.totals.transactionCount,
      gross_spend: formatMoney(databaseSummary.totals.grossSpendPaise),
      refunds: formatMoney(databaseSummary.totals.refundsPaise),
      net_expense: formatMoney(databaseSummary.totals.netExpensePaise),
      card_bill_payments: formatMoney(databaseSummary.totals.cardBillPaymentsPaise),
      source_accounts: databaseSummary.metadata.sourceAccounts,
      merchant_aliases: databaseSummary.metadata.merchantAliases,
      transaction_sources: databaseSummary.metadata.transactionSources,
      review_items: databaseSummary.metadata.reviewItems,
      open_review_items: databaseSummary.metadata.openReviewItems,
      import_batches: databaseSummary.metadata.importBatches,
    },
    import: importCounts,
    suppression: {
      suppressed_count: importCounts.suppressedCount ?? 0,
      imported_transaction_count: importCounts.importedCount ?? importCounts.rowCount,
      suppressed_gross_spend: formatMoney(importCounts.suppressedGrossSpendPaise ?? 0),
      suppressed_refunds: formatMoney(importCounts.suppressedRefundsPaise ?? 0),
      suppressed_net_expense: formatMoney(importCounts.suppressedNetExpensePaise ?? 0),
      suppressed_card_bill_payments: formatMoney(importCounts.suppressedCardBillPaymentsPaise ?? 0),
    },
    checks: {
      totals: true,
      monthly: true,
      category: true,
      merchant: true,
      cardholder: true,
      transaction_sources: true,
      review_queue: true,
    },
  };
}

export async function runImport(options = {}) {
  const resolvedOptions = {
    workbookPath: options.workbookPath ?? process.env.SPENDLENS_WORKBOOK_PATH ?? DEFAULT_WORKBOOK_PATH,
    dbUrl: options.dbUrl ?? process.env.SPENDLENS_DB_URL ?? process.env.DATABASE_URL ?? DEFAULT_DB_URL,
    householdId: options.householdId ?? process.env.SPENDLENS_IMPORT_HOUSEHOLD_ID ?? DEFAULT_IDS.householdId,
    profileId: options.profileId ?? process.env.SPENDLENS_IMPORT_PROFILE_ID ?? DEFAULT_IDS.profileId,
    authUserId: options.authUserId ?? process.env.SPENDLENS_IMPORT_AUTH_USER_ID ?? DEFAULT_IDS.authUserId,
    householdMemberId: options.householdMemberId ?? DEFAULT_IDS.householdMemberId,
    householdName: options.householdName ?? process.env.SPENDLENS_IMPORT_HOUSEHOLD_NAME ?? 'SpendLens Workbook Seed Household',
    dryRun: Boolean(options.dryRun),
  };

  const data = await readWorkbook(resolvedOptions.workbookPath);
  const workbookSummary = validateWorkbookData(data);

  if (resolvedOptions.dryRun) {
    return {
      dryRun: true,
      workbookSummary,
      validationSummary: validationSummary(workbookSummary, {
        totals: {
          transactionCount: 0,
          grossSpendPaise: 0,
          refundsPaise: 0,
          netExpensePaise: 0,
          cardBillPaymentsPaise: 0,
        },
        metadata: {
          sourceAccounts: 0,
          merchantAliases: 0,
          transactionSources: 0,
          reviewItems: 0,
          openReviewItems: 0,
          importBatches: 0,
        },
      }, {
        rowCount: data.transactions.length,
        importedCount: data.transactions.length,
        suppressedCount: 0,
        insertedCount: 0,
        updatedCount: 0,
        duplicateCount: 0,
      }),
    };
  }

  const client = new Client({ connectionString: resolvedOptions.dbUrl });
  await client.connect();
  try {
    await client.query('begin');
    await seedHousehold(client, resolvedOptions);
    const batchId = await upsertImportBatch(client, resolvedOptions);
    const categories = await upsertCategories(client, data, resolvedOptions);
    const subcategories = await upsertSubcategories(client, data, resolvedOptions, categories);
    const sourceAccounts = await upsertSourceAccounts(client, data, resolvedOptions);
    const merchants = await upsertMerchants(client, data, resolvedOptions, categories, subcategories);
    const merchantMappingRules = await fetchMerchantMappingRules(client, resolvedOptions);
    const classifiedData = {
      ...data,
      transactions: classifyTransactionsWithRules(data.transactions, merchantMappingRules),
    };
    const tombstonedFingerprints = await tombstonedWorkbookFingerprints(client, resolvedOptions);
    const { importData, suppression } = filterWorkbookDataForSuppression(classifiedData, tombstonedFingerprints);
    await upsertMerchantAliases(client, classifiedData, resolvedOptions, merchants);
    const transactionCounts = await upsertTransactions(client, importData, resolvedOptions, {
      categories,
      subcategories,
      sourceAccounts,
      merchants,
    });
    const importCounts = {
      ...transactionCounts,
      rowCount: data.transactions.length,
      importedCount: suppression.importedCount,
      suppressedCount: suppression.suppressedCount,
      suppressedGrossSpendPaise: suppression.suppressedGrossSpendPaise,
      suppressedRefundsPaise: suppression.suppressedRefundsPaise,
      suppressedNetExpensePaise: suppression.suppressedNetExpensePaise,
      suppressedCardBillPaymentsPaise: suppression.suppressedCardBillPaymentsPaise,
    };
    await upsertTransactionSources(client, importData, resolvedOptions, batchId);
    const reviewResult = await upsertReviewItems(client, importData, resolvedOptions, {
      categories,
      subcategories,
      merchants,
    });
    const databaseSummary = await validateDatabaseImport(
      client,
      importData,
      resolvedOptions,
      batchId,
      reviewResult.reviewItemIds,
    );
    const summary = validationSummary(
      workbookSummary,
      databaseSummary,
      importCounts,
      summarizeTransactions(importData.transactions),
    );
    await client.query(
      `update public.import_batches
       set status = 'completed',
           completed_at = now(),
           row_count = $2,
           inserted_count = $3,
           updated_count = $4,
           duplicate_count = $5,
           validation_summary = $6::jsonb,
           error_message = null
       where id = $1`,
      [
        batchId,
        importCounts.rowCount,
        importCounts.insertedCount,
        importCounts.updatedCount,
        importCounts.duplicateCount,
        JSON.stringify(summary),
      ],
    );
    await client.query('commit');
    return {
      dryRun: false,
      batchId,
      householdId: resolvedOptions.householdId,
      importCounts,
      validationSummary: summary,
    };
  } catch (error) {
    await client.query('rollback');
    throw error;
  } finally {
    await client.end();
  }
}

function printHelp() {
  console.log(`Usage: pnpm run import -- [options]

Options:
  --workbook <path>      Workbook path. Defaults to docs/Credit Card Spend Analysis - FY 2025-26.xlsx.
  --db-url <url>         Postgres connection string. Defaults to local Supabase DB.
  --household-id <uuid>  Target household id. Defaults to deterministic local seed household.
  --profile-id <uuid>    Created-by profile id for the deterministic local seed household.
  --auth-user-id <uuid>  Auth user id for the deterministic local seed profile.
  --household-name <s>   Local seed household name.
  --dry-run              Parse and validate the workbook without writing to Postgres.
  --json                 Print the result as JSON.
  --help                 Show this help.

Environment alternatives:
  SPENDLENS_DB_URL, DATABASE_URL, SPENDLENS_WORKBOOK_PATH,
  SPENDLENS_IMPORT_HOUSEHOLD_ID, SPENDLENS_IMPORT_PROFILE_ID,
  SPENDLENS_IMPORT_AUTH_USER_ID, SPENDLENS_IMPORT_HOUSEHOLD_NAME
`);
}

function parseArgs(argv) {
  const options = {};
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    const next = () => {
      index += 1;
      assert.ok(argv[index], `Missing value for ${arg}`);
      return argv[index];
    };
    if (arg === '--workbook') options.workbookPath = path.resolve(next());
    else if (arg === '--db-url') options.dbUrl = next();
    else if (arg === '--household-id') options.householdId = next();
    else if (arg === '--profile-id') options.profileId = next();
    else if (arg === '--auth-user-id') options.authUserId = next();
    else if (arg === '--household-name') options.householdName = next();
    else if (arg === '--dry-run') options.dryRun = true;
    else if (arg === '--json') options.json = true;
    else if (arg === '--help' || arg === '-h') options.help = true;
    else throw new Error(`Unknown option: ${arg}`);
  }
  return options;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    printHelp();
  } else {
    runImport(options)
      .then((result) => {
        if (options.json) {
          console.log(JSON.stringify(result, null, 2));
          return;
        }
        const summary = result.validationSummary;
        console.log(`Workbook validation: ${summary.status}`);
        console.log(`Transactions: ${summary.workbook.transaction_count}`);
        console.log(`Gross spend: ${summary.workbook.gross_spend}`);
        console.log(`Refunds: ${summary.workbook.refunds}`);
        console.log(`Net expense: ${summary.workbook.net_expense}`);
        console.log(`Card bill payments: ${summary.workbook.card_bill_payments}`);
        if (result.dryRun) {
          console.log('Dry run only; no database writes performed.');
        } else {
          console.log(`Import batch: ${result.batchId}`);
          console.log(`Inserted: ${result.importCounts.insertedCount}`);
          console.log(`Updated: ${result.importCounts.updatedCount}`);
          console.log(`Suppressed: ${result.importCounts.suppressedCount}`);
          console.log(`Review items: ${summary.database.review_items} (${summary.database.open_review_items} open)`);
        }
      })
      .catch((error) => {
        console.error(error.stack ?? error.message);
        process.exitCode = 1;
      });
  }
}
