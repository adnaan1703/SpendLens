import { base64UrlEncode } from "../_shared/crypto.ts";
import { extractPlainText, messageMetadata } from "../_shared/gmail_message.ts";
import { parseGmailTransaction } from "../_shared/parsers/gmail_parsers.mjs";

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

function encodeText(value: string): string {
  return base64UrlEncode(new TextEncoder().encode(value));
}

Deno.test("HTML-only Gmail alerts use decoded HTML instead of the snippet", () => {
  const html = `
    <html>
      <body>
        <p>Dear Customer,</p>
        <p>Greetings from HDFC Bank.</p>
        <p>We would like to inform you that Rs. 5695.86 has been debited from your
        HDFC Bank Credit Card ending 3604 towards VELS STUDIOS AND ENTER on
        30 May, 2026 at 22:52:23 .</p>
      </body>
    </html>
  `;
  const message = {
    id: "19e79e8af35c7bcc",
    threadId: "19e788625e7c979f",
    internalDate: String(new Date("2026-05-30T17:22:31.000Z").getTime()),
    snippet:
      "Dear Customer, Greetings from HDFC Bank. We would like to inform you that Rs. 5695.86 has been debited from your HDFC Bank Credit Card ending 3604 towards VELS STUDIOS AND ENTER on 30 May, 2026 at 22:",
    payload: {
      mimeType: "multipart/alternative",
      headers: [
        {
          name: "From",
          value: "HDFC Bank InstaAlerts <alerts@hdfcbank.bank.in>",
        },
        {
          name: "Subject",
          value: "A payment was made using your Credit Card",
        },
      ],
      parts: [
        {
          mimeType: "text/html",
          body: { data: encodeText(html), size: html.length },
        },
      ],
    },
  };

  const bodyText = extractPlainText(message);
  assert(
    bodyText.includes("at 22:52:23."),
    `Expected full HTML timestamp in body text: ${bodyText}`,
  );

  const parsed = parseGmailTransaction(messageMetadata(message), bodyText);
  assert(parsed.ok === true, `Expected HTML-only alert to parse: ${parsed}`);
  const parsedRecord = parsed as Record<string, unknown>;
  assert(
    parsedRecord.statement_merchant === "VELS STUDIOS AND ENTER",
    `Unexpected merchant: ${parsedRecord.statement_merchant}`,
  );
  assert(
    parsedRecord.transaction_time === "22:52:23",
    "Unexpected transaction time.",
  );
});
