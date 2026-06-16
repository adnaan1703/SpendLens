import assert from "node:assert/strict";
import test from "node:test";

import {
  classifyGmailTransaction,
  extractGmailSenderEmail,
  hdfcCreditCardDebitParser,
  hdfcNetbankingImpsDebitParser,
  hdfcUpiDebitParser,
  parseGmailTransaction,
} from "../_shared/parsers/gmail_parsers.mjs";

const sampleOne = `Dear Customer,

Greetings from HDFC Bank.

We would like to inform you that Rs. 966.99 has been debited from your HDFC Bank Credit Card ending 3604 towards RAZ*Plazza on 06 Jun, 2026 at 21:42:11.
To check your available balance, outstanding amount, or view recent transactions, you may use:
Mycards:https://mycards.hdfc.bank.in

Thank you for banking with us.

Warm Regards,
HDFC Bank`;

const sampleTwo = `Dear Customer,

Greetings from HDFC Bank.

We would like to inform you that Rs. 55063.06 has been debited from your HDFC Bank Credit Card ending 3604 towards NOBROKER on 05 Jun, 2026 at 13:12:29.
To check your available balance, outstanding amount, or view recent transactions, you may use:
Mycards:https://mycards.hdfc.bank.in

Smart Spend Tip:\tAll your recent HDFC Bank Credit Card spends may be eligible for conversion into SmartEMI, allowing you to pay in smaller monthly amounts.Check here

Thank you for banking with us.

Warm Regards,
HDFC Bank`;

const refreshedCreditCardSamples = [
  {
    id: "msg-thread-cc-1",
    expectedAmount: 2832.24,
    expectedDate: "2026-05-10",
    expectedTime: "18:18:27",
    expectedMerchant: "PTM*TATA 1MG HEALTHCAR",
    body: `Dear Customer,

Greetings from HDFC Bank.

We would like to inform you that Rs. 2832.24 has been debited from your HDFC Bank Credit Card ending 3604 towards PTM*TATA 1MG HEALTHCAR on 10 May, 2026 at 18:18:27.
To check your available balance, outstanding amount, or view recent transactions, you may use:
Mycards:https://mycards.hdfc.bank.in
WhatsApp Banking:https://hdfcbk.io/HDFCBK/K/DUvfZ20acT6

Smart Spend Tip:\tAll your recent HDFC Bank Credit Card spends may be eligible for conversion into SmartEMI, allowing you to pay in smaller monthly amounts.Check here

Thank you for banking with us.

Warm Regards,
HDFC Bank`,
  },
  {
    id: "msg-thread-cc-2",
    expectedAmount: 59,
    expectedDate: "2026-05-10",
    expectedTime: "22:40:22",
    expectedMerchant: "RAZ*Plazza",
    body: `Dear Customer,

Greetings from HDFC Bank.

We would like to inform you that Rs. 59.00 has been debited from your HDFC Bank Credit Card ending 3604 towards RAZ*Plazza on 10 May, 2026 at 22:40:22.
To check your available balance, outstanding amount, or view recent transactions, you may use:
Mycards:https://mycards.hdfc.bank.in
WhatsApp Banking:https://hdfcbk.io/HDFCBK/K/DUvfZ20acT6

Thank you for banking with us.

Warm Regards,
HDFC Bank`,
  },
];

const upiDebitSample = `Dear Customer,

Greetings from HDFC Bank!

Rs.4049.25 is debited from your account ending 0932 towards VPA paytm-8815082@ptys (S V M FUEL STATION) on 28-05-26.

UPI transaction reference no.: 123809697002.

If you did not authorize this transaction, please report it immediately at:
a. When in India (Toll free): 1800 258 6161
b. When abroad: 9122 61606160
c. Or SMS 'BLOCK UPI' to 7308080808.

We're here to support you in every step of the way.

Warm regards,
HDFC Bank`;

const upiDebitSampleV2 =
  `Dear Customer, Rs.3278.04 has been debited from account 0932 to VPA cred.telecom@axisb Dreamplug Service Private Limited on 06-05-26. Your UPI transaction reference number is 649208302029. If you did not authorize this transaction, please report it immediately by calling 18002586161 Or SMS BLOCK UPI to 7308080808. Warm Regards, HDFC Bank

For more details on Service charges and Fees, click here.
(c) HDFC Bank`;

const impsDebitSample = `Dear Customer,

INR 33,500.00 has been debited from your HDFC Bank account ending 0932 on 16-06-26 and credited to beneficiary account ending 4428 via IMPS.

IMPS Reference No 616734130236.

If you did not authorize this transaction, please contact HDFC Bank immediately.

Warm Regards,
HDFC Bank`;

const threadedUpiSamples = [
  {
    id: "msg-thread-upi-1",
    expectedAmount: 4049.25,
    expectedDate: "2026-05-28",
    expectedMerchant: "S V M FUEL STATION",
    expectedReference: "123809697002",
    body: upiDebitSample,
  },
  {
    id: "msg-thread-upi-2",
    expectedAmount: 112937,
    expectedDate: "2026-06-05",
    expectedMerchant: "CRED Club",
    expectedReference: "652216925085",
    body: `Dear Customer,

Greetings from HDFC Bank!

Rs.112937.00 is debited from your account ending 0932 towards VPA cred.club@axisb (CRED Club) on 05-06-26.

UPI transaction reference no.: 652216925085.

Warm regards,
HDFC Bank`,
  },
  {
    id: "msg-thread-upi-3",
    expectedAmount: 3278.04,
    expectedDate: "2026-05-06",
    expectedMerchant: "Dreamplug Service Private Limited",
    expectedReference: "649208302029",
    body: upiDebitSampleV2,
  },
];

test("HDFC alert sender is extracted from display-name headers", () => {
  assert.equal(
    extractGmailSenderEmail({
      from: "HDFC Bank InstaAlerts <alerts@hdfcbank.bank.in>",
    }),
    "alerts@hdfcbank.bank.in",
  );
});

test("parser registry classifies credit-card alerts by body template", () => {
  const classified = classifyGmailTransaction({
    id: "msg-cc-candidate",
    from: "alerts@example.test",
    subject: "Generic watched-label message",
  }, sampleOne);

  assert.equal(classified.ok, true);
  assert.equal(classified.candidate_type, "credit_card");
  assert.equal(classified.parser_name, "hdfc_credit_card_debit");
});

test("parser registry classifies UPI alerts by body template", () => {
  const classified = classifyGmailTransaction({
    id: "msg-upi-candidate",
    from: "alerts@example.test",
    subject: "\u2757 Generic watched-label message",
  }, upiDebitSample);

  assert.equal(classified.ok, true);
  assert.equal(classified.candidate_type, "upi");
  assert.equal(classified.parser_name, "hdfc_upi_debit");
});

test("parser registry parses body-only matches without sender or subject gating", () => {
  const parsed = parseGmailTransaction(
    {
      id: "msg-body-only",
      from: "alerts@hdfcbank.net",
      subject: "Credit Card Alert",
    },
    sampleOne,
  );

  assert.equal(parsed.ok, true);
  assert.equal(parsed.parser_name, "hdfc_credit_card_debit");
  assert.equal(parsed.amount, 966.99);
  assert.equal(parsed.statement_merchant, "RAZ*Plazza");
});

test("HDFC debit parser extracts amount merchant card and timestamp", () => {
  const parsed = hdfcCreditCardDebitParser.parse({ id: "msg-1" }, sampleOne);

  assert.equal(parsed.ok, true);
  assert.equal(parsed.amount, 966.99);
  assert.equal(parsed.transaction_date, "2026-06-06");
  assert.equal(parsed.transaction_time, "21:42:11");
  assert.equal(parsed.statement_merchant, "RAZ*Plazza");
  assert.equal(parsed.transaction_type, "debit_spend");
  assert.equal(parsed.source_account_hint.masked_identifier, "3604");
  assert.equal(parsed.source_reference, "msg-1");
});

test("parser registry handles HDFC SmartEMI footer without changing merchant", () => {
  const parsed = parseGmailTransaction(
    {
      id: "msg-2",
      from: "HDFC Bank InstaAlerts <alerts@hdfcbank.bank.in>",
      subject: "A payment was made using your Credit Card",
    },
    sampleTwo,
  );

  assert.equal(parsed.ok, true);
  assert.equal(parsed.amount, 55063.06);
  assert.equal(parsed.transaction_date, "2026-06-05");
  assert.equal(parsed.transaction_time, "13:12:29");
  assert.equal(parsed.statement_merchant, "NOBROKER");
  assert.equal(
    parsed.source_account_hint.display_name,
    "HDFC Credit Card ending 3604",
  );
  assert.equal(parsed.candidate_type, "credit_card");
});

test("thread-expanded HDFC credit-card messages parse independently", () => {
  for (const fixture of refreshedCreditCardSamples) {
    const parsed = parseGmailTransaction(
      {
        id: fixture.id,
        threadId: "gmail-credit-card-thread-1",
        from: "HDFC Bank InstaAlerts <alerts@hdfcbank.bank.in>",
        subject: "A payment was made using your Credit Card",
      },
      fixture.body,
    );

    assert.equal(parsed.ok, true);
    assert.equal(parsed.amount, fixture.expectedAmount);
    assert.equal(parsed.transaction_date, fixture.expectedDate);
    assert.equal(parsed.transaction_time, fixture.expectedTime);
    assert.equal(parsed.statement_merchant, fixture.expectedMerchant);
    assert.equal(parsed.source_reference, fixture.id);
  }
});

test("HDFC UPI debit parser extracts amount payee account and reference", () => {
  const parsed = hdfcUpiDebitParser.parse(
    {
      id: "msg-upi-1",
      from: "HDFC Bank InstaAlerts <alerts@hdfcbank.bank.in>",
      subject: "You have done a UPI txn. Check details!",
    },
    upiDebitSample,
  );

  assert.equal(parsed.ok, true);
  assert.equal(parsed.parser_name, "hdfc_upi_debit");
  assert.equal(parsed.amount, 4049.25);
  assert.equal(parsed.transaction_date, "2026-05-28");
  assert.equal(parsed.transaction_time, null);
  assert.equal(parsed.statement_merchant, "S V M FUEL STATION");
  assert.equal(parsed.source_reference, "123809697002");
  assert.equal(parsed.candidate_type, "upi");
  assert.equal(parsed.source_account_hint.type, "upi");
  assert.equal(
    parsed.source_account_hint.display_name,
    "HDFC Bank UPI account ending 0932",
  );
  assert.equal(parsed.source_account_hint.masked_identifier, "0932");
  assert.deepEqual(parsed.diagnostics, {
    template: "hdfc_upi_debit_v1",
    has_payee_label: true,
  });
});

test("HDFC UPI debit parser handles account-to-VPA body template", () => {
  const parsed = hdfcUpiDebitParser.parse(
    {
      id: "msg-upi-v2",
      from: "HDFC Bank InstaAlerts <alerts@hdfcbank.bank.in>",
      subject: "You have done a UPI txn. Check details!",
    },
    upiDebitSampleV2,
  );

  assert.equal(parsed.ok, true);
  assert.equal(parsed.parser_name, "hdfc_upi_debit");
  assert.equal(parsed.amount, 3278.04);
  assert.equal(parsed.transaction_date, "2026-05-06");
  assert.equal(parsed.transaction_time, null);
  assert.equal(parsed.statement_merchant, "Dreamplug Service Private Limited");
  assert.equal(parsed.source_reference, "649208302029");
  assert.equal(parsed.candidate_type, "upi");
  assert.equal(parsed.source_account_hint.type, "upi");
  assert.equal(parsed.source_account_hint.masked_identifier, "0932");
  assert.deepEqual(parsed.diagnostics, {
    template: "hdfc_upi_debit_v2",
    has_payee_label: true,
  });
});

test("parser registry routes HDFC UPI debit alerts to the UPI parser", () => {
  const parsed = parseGmailTransaction(
    {
      id: "msg-upi-2",
      from: "HDFC Bank InstaAlerts <alerts@hdfcbank.bank.in>",
      subject: "You have done a UPI txn. Check details!",
    },
    `Dear Customer,

Greetings from HDFC Bank!

Rs.112937.00 is debited from your account ending 0932 towards VPA cred.club@axisb (CRED Club) on 05-06-26.

UPI transaction reference no.: 652216925085.

Warm regards,
HDFC Bank`,
  );

  assert.equal(parsed.ok, true);
  assert.equal(parsed.parser_name, "hdfc_upi_debit");
  assert.equal(parsed.amount, 112937);
  assert.equal(parsed.transaction_date, "2026-06-05");
  assert.equal(parsed.statement_merchant, "CRED Club");
  assert.equal(parsed.source_reference, "652216925085");
});

test("HDFC Netbanking IMPS debit parser extracts account reference and destination", () => {
  const parsed = hdfcNetbankingImpsDebitParser.parse(
    { id: "msg-imps-1" },
    impsDebitSample,
  );

  assert.equal(parsed.ok, true);
  assert.equal(parsed.parser_name, "hdfc_netbanking_imps_debit");
  assert.equal(parsed.parser_version, "1.0.0");
  assert.equal(parsed.candidate_type, "netbanking_imps");
  assert.equal(parsed.amount, 33500.00);
  assert.equal(parsed.transaction_date, "2026-06-16");
  assert.equal(parsed.transaction_type, "debit_spend");
  assert.equal(parsed.statement_merchant, "IMPS to ending 4428");
  assert.equal(parsed.source_reference, "616734130236");
  assert.equal(parsed.source_account_hint.type, "netbanking_imps");
  assert.equal(
    parsed.source_account_hint.display_name,
    "HDFC Netbanking IMPS account ending 0932",
  );
  assert.equal(parsed.source_account_hint.institution_name, "HDFC Bank");
  assert.equal(parsed.source_account_hint.masked_identifier, "0932");
  assert.deepEqual(parsed.diagnostics, {
    template: "hdfc_netbanking_imps_debit_v1",
    destination_account_ending: "4428",
  });
});

test("parser registry routes Netbanking IMPS by body template", () => {
  const parsed = parseGmailTransaction(
    {
      id: "msg-imps-2",
      from: "bank@example.test",
      subject: "Watched label import",
    },
    impsDebitSample,
  );

  assert.equal(parsed.ok, true);
  assert.equal(parsed.parser_name, "hdfc_netbanking_imps_debit");
  assert.equal(parsed.amount, 33500.00);
  assert.equal(parsed.transaction_date, "2026-06-16");
  assert.equal(parsed.statement_merchant, "IMPS to ending 4428");
  assert.equal(parsed.source_reference, "616734130236");
});

test("thread-expanded HDFC UPI debit messages parse independently", () => {
  for (const fixture of threadedUpiSamples) {
    const parsed = parseGmailTransaction(
      {
        id: fixture.id,
        threadId: "gmail-upi-thread-1",
        from: "HDFC Bank InstaAlerts <alerts@hdfcbank.bank.in>",
        subject: "You have done a UPI txn. Check details!",
      },
      fixture.body,
    );

    assert.equal(parsed.ok, true);
    assert.equal(parsed.parser_name, "hdfc_upi_debit");
    assert.equal(parsed.amount, fixture.expectedAmount);
    assert.equal(parsed.transaction_date, fixture.expectedDate);
    assert.equal(parsed.statement_merchant, fixture.expectedMerchant);
    assert.equal(parsed.source_reference, fixture.expectedReference);
  }
});

test("unsupported messages do not produce transactions", () => {
  const parsed = parseGmailTransaction({ id: "msg-3" }, "Generic newsletter");

  assert.equal(parsed.ok, false);
  assert.equal(parsed.candidate_type, "other");
  assert.equal(parsed.parser_name, "unsupported_labeled_gmail_message");
  assert.equal(parsed.diagnostics.reason, "no_supported_body_template_matched");
});
