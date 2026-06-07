const monthNumbers = new Map([
  ["jan", 1],
  ["feb", 2],
  ["mar", 3],
  ["apr", 4],
  ["may", 5],
  ["jun", 6],
  ["jul", 7],
  ["aug", 8],
  ["sep", 9],
  ["oct", 10],
  ["nov", 11],
  ["dec", 12],
]);

function parseTwoDigitDate(dayText, monthText, yearText) {
  const day = Number(dayText);
  const month = Number(monthText);
  const shortYear = Number(yearText);
  const year = shortYear >= 70 ? 1900 + shortYear : 2000 + shortYear;

  return [
    year.toString().padStart(4, "0"),
    month.toString().padStart(2, "0"),
    day.toString().padStart(2, "0"),
  ].join("-");
}

export const hdfcCreditCardDebitParser = {
  parserName: "hdfc_credit_card_debit",
  parserVersion: "1.0.0",

  matches(messageMetadata, bodyText) {
    const haystack = `${messageMetadata?.from ?? ""}\n${
      messageMetadata?.subject ?? ""
    }\n${bodyText}`;
    return /HDFC Bank Credit Card ending \d{4}/i.test(haystack) &&
      /has been debited/i.test(haystack);
  },

  parse(messageMetadata, bodyText) {
    const match = bodyText.match(
      /Rs\.\s*([0-9,]+(?:\.[0-9]{1,2})?)\s+has\s+been\s+debited\s+from\s+your\s+HDFC\s+Bank\s+Credit\s+Card\s+ending\s+(\d{4})\s+towards\s+(.+?)\s+on\s+(\d{1,2})\s+([A-Za-z]{3}),\s+(\d{4})\s+at\s+(\d{2}:\d{2}:\d{2})\./is,
    );

    if (!match) {
      return {
        ok: false,
        parser_name: this.parserName,
        parser_version: this.parserVersion,
        diagnostics: {
          reason: "hdfc_debit_pattern_not_matched",
          messageId: messageMetadata?.id ?? null,
        },
      };
    }

    const [
      ,
      amountText,
      maskedIdentifier,
      merchantText,
      dayText,
      monthText,
      yearText,
      timeText,
    ] = match;
    const month = monthNumbers.get(monthText.toLowerCase());
    if (!month) {
      return {
        ok: false,
        parser_name: this.parserName,
        parser_version: this.parserVersion,
        diagnostics: {
          reason: "unsupported_month",
          month: monthText,
          messageId: messageMetadata?.id ?? null,
        },
      };
    }

    const amount = Number(amountText.replaceAll(",", ""));
    const day = Number(dayText);
    const year = Number(yearText);
    const transactionDate = [
      year.toString().padStart(4, "0"),
      month.toString().padStart(2, "0"),
      day.toString().padStart(2, "0"),
    ].join("-");
    const statementMerchant = merchantText.replace(/\s+/g, " ").trim();

    return {
      ok: true,
      parser_name: this.parserName,
      parser_version: this.parserVersion,
      transaction_date: transactionDate,
      transaction_time: timeText,
      amount,
      currency_code: "INR",
      statement_merchant: statementMerchant,
      transaction_type: "debit_spend",
      source_reference: messageMetadata?.id ?? null,
      confidence: "high",
      source_account_hint: {
        type: "credit_card",
        display_name: `HDFC Credit Card ending ${maskedIdentifier}`,
        institution_name: "HDFC Bank",
        masked_identifier: maskedIdentifier,
      },
      diagnostics: {
        template: "hdfc_credit_card_debit_v1",
      },
    };
  },
};

export const hdfcUpiDebitParser = {
  parserName: "hdfc_upi_debit",
  parserVersion: "1.0.0",

  matches(messageMetadata, bodyText) {
    const haystack = `${messageMetadata?.from ?? ""}\n${
      messageMetadata?.subject ?? ""
    }\n${bodyText}`;
    return /HDFC Bank/i.test(haystack) &&
      /UPI txn|UPI transaction/i.test(haystack) &&
      /is debited from your account ending \d{4}/i.test(haystack);
  },

  parse(messageMetadata, bodyText) {
    const transactionMatch = bodyText.match(
      /Rs\.\s*([0-9,]+(?:\.[0-9]{1,2})?)\s+is\s+debited\s+from\s+your\s+account\s+ending\s+(\d{4})\s+towards\s+VPA\s+([^\s(]+)(?:\s+\(([^)]+)\))?\s+on\s+(\d{2})-(\d{2})-(\d{2})\./is,
    );
    const referenceMatch = bodyText.match(
      /UPI\s+transaction\s+reference\s+no\.:\s*([A-Za-z0-9-]+)\./i,
    );

    if (!transactionMatch) {
      return {
        ok: false,
        parser_name: this.parserName,
        parser_version: this.parserVersion,
        diagnostics: {
          reason: "hdfc_upi_debit_pattern_not_matched",
          messageId: messageMetadata?.id ?? null,
        },
      };
    }

    const [
      ,
      amountText,
      maskedIdentifier,
      payeeVpa,
      payeeLabel,
      dayText,
      monthText,
      yearText,
    ] = transactionMatch;
    const statementMerchant = (payeeLabel ?? payeeVpa)
      .replace(/\s+/g, " ")
      .trim();
    const reference = referenceMatch?.[1]?.trim() ?? messageMetadata?.id ??
      null;

    return {
      ok: true,
      parser_name: this.parserName,
      parser_version: this.parserVersion,
      transaction_date: parseTwoDigitDate(dayText, monthText, yearText),
      transaction_time: null,
      amount: Number(amountText.replaceAll(",", "")),
      currency_code: "INR",
      statement_merchant: statementMerchant,
      transaction_type: "debit_spend",
      source_reference: reference,
      confidence: payeeLabel ? "high" : "medium",
      source_account_hint: {
        type: "upi",
        display_name: `HDFC Bank UPI account ending ${maskedIdentifier}`,
        institution_name: "HDFC Bank",
        masked_identifier: maskedIdentifier,
      },
      diagnostics: {
        template: "hdfc_upi_debit_v1",
        has_payee_label: Boolean(payeeLabel),
      },
    };
  },
};

export const gmailParsers = [hdfcCreditCardDebitParser, hdfcUpiDebitParser];

export function parseGmailTransaction(messageMetadata, bodyText) {
  for (const parser of gmailParsers) {
    if (!parser.matches(messageMetadata, bodyText)) {
      continue;
    }

    return parser.parse(messageMetadata, bodyText);
  }

  return {
    ok: false,
    parser_name: "unsupported",
    parser_version: "1.0.0",
    diagnostics: {
      reason: "unsupported_gmail_message",
      messageId: messageMetadata?.id ?? null,
    },
  };
}

export function normalizeFingerprintText(value) {
  return String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}
