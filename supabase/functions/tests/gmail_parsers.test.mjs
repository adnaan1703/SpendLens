import assert from "node:assert/strict";
import test from "node:test";

import {
  hdfcCreditCardDebitParser,
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
    { id: "msg-2", from: "alerts@hdfcbank.net", subject: "Credit Card Alert" },
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

test("unsupported messages do not produce transactions", () => {
  const parsed = parseGmailTransaction({ id: "msg-3" }, "Generic newsletter");

  assert.equal(parsed.ok, false);
  assert.equal(parsed.parser_name, "unsupported");
  assert.equal(parsed.diagnostics.reason, "unsupported_gmail_message");
});
