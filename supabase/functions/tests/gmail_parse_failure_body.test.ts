import { base64UrlEncode } from "../_shared/crypto.ts";
import { extractPlainText, messageMetadata } from "../_shared/gmail_message.ts";
import {
  handleGmailParseFailureBody,
} from "../gmail-parse-failure-body/index.ts";
import { type SupabaseClientLike } from "../_shared/supabase.ts";
import { logOperationalEvent } from "../_shared/observability.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

function encodeText(value: string): string {
  return base64UrlEncode(new TextEncoder().encode(value));
}

function rpcClient(
  handler: (
    name: string,
    params: Record<string, unknown>,
  ) =>
    | { data: unknown; error: Error | null }
    | Promise<
      { data: unknown; error: Error | null }
    >,
): SupabaseClientLike {
  return {
    rpc: handler,
  } as unknown as SupabaseClientLike;
}

const authorizedFailure = {
  failure_id: "93000000-0000-0000-0000-000000000001",
  household_id: "33000000-0000-0000-0000-000000000001",
  linked_mailbox_id: "53000000-0000-0000-0000-000000000001",
  mailbox_email: "parse-a@example.test",
  candidate_type: "credit_card",
  source_message_id: "gmail-failure-message-1",
  source_thread_id: "gmail-failure-thread-1",
  source_received_at: "2026-06-08T05:00:00.000Z",
  sender_email: "alerts@hdfcbank.bank.in",
  subject: "A payment was made using your Credit Card",
  parser_name: "hdfc_credit_card_debit",
  parser_version: "1.0.0",
  reason_code: "hdfc_debit_pattern_not_matched",
};

Deno.test("Gmail parse-failure body handler returns plain text without diagnostics", async () => {
  let refreshedToken = "";
  let fetchedMessageId = "";
  const userClient = rpcClient((name, params) => {
    assert(
      name === "authorize_gmail_parse_failure_body",
      `Unexpected user RPC ${name}.`,
    );
    assert(
      params.p_failure_id === authorizedFailure.failure_id,
      "Body fetch must authorize by failure id.",
    );
    return { data: [authorizedFailure], error: null };
  });
  const serviceClient = rpcClient((name, params) => {
    assert(
      name === "get_gmail_refresh_token",
      `Unexpected service RPC ${name}.`,
    );
    assert(
      params.p_mailbox_id === authorizedFailure.linked_mailbox_id,
      "Refresh token lookup must use the authorized mailbox id.",
    );
    return { data: "refresh-token-1", error: null };
  });

  const response = await handleGmailParseFailureBody(
    new Request("http://localhost/gmail-parse-failure-body", {
      method: "POST",
      headers: {
        Authorization: "Bearer user-jwt",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ failure_id: authorizedFailure.failure_id }),
    }),
    {
      requireUser: () =>
        Promise.resolve({
          userClient,
          user: { id: "13000000-0000-0000-0000-000000000001" },
        }),
      createServiceClient: () => serviceClient,
      refreshAccessToken: (refreshToken) => {
        refreshedToken = refreshToken;
        return Promise.resolve({ access_token: "gmail-access-token" });
      },
      fetchGmailMessage: (accessToken, messageId) => {
        assert(
          accessToken === "gmail-access-token",
          "Gmail fetch must use the refreshed access token.",
        );
        fetchedMessageId = messageId;
        return Promise.resolve({
          id: messageId,
          threadId: "gmail-failure-thread-1",
          internalDate: String(new Date("2026-06-08T05:00:00Z").getTime()),
          snippet: "Do not expose snippet.",
          payload: {
            mimeType: "text/plain",
            headers: [
              { name: "From", value: "HDFC Bank <alerts@hdfcbank.bank.in>" },
              {
                name: "Subject",
                value: "A payment was made using your Credit Card",
              },
              { name: "Date", value: "Mon, 08 Jun 2026 10:30:00 +0530" },
            ],
            body: {
              data: encodeText("Full plain-text transaction alert body."),
            },
          },
        });
      },
      extractPlainText,
      messageMetadata,
      logOperationalEvent,
    },
  );

  assert(response.status === 200, `Unexpected status ${response.status}.`);
  const json = await response.json();
  assert(
    refreshedToken === "refresh-token-1",
    "Gmail refresh token was not used.",
  );
  assert(
    fetchedMessageId === authorizedFailure.source_message_id,
    "Authorized source message id was not fetched.",
  );
  assert(
    json.plain_text_body === "Full plain-text transaction alert body.",
    "Plain text body was not returned.",
  );
  assert(
    !("body_parts" in json),
    "Body part diagnostics must not be returned.",
  );
  assert(!("snippet" in json.message), "Gmail snippets must not be returned.");
  assert(
    json.failure.mailbox.id === authorizedFailure.linked_mailbox_id,
    "Failure metadata should include the authorized mailbox id.",
  );
  assert(
    json.failure.candidate_type === authorizedFailure.candidate_type,
    "Failure metadata should include the sanitized candidate type.",
  );
});

Deno.test("Gmail parse-failure body handler rejects inaccessible rows before Gmail fetch", async () => {
  let serviceClientCreated = false;
  const userClient = rpcClient((name) => {
    assert(
      name === "authorize_gmail_parse_failure_body",
      `Unexpected user RPC ${name}.`,
    );
    return { data: [], error: null };
  });

  const response = await handleGmailParseFailureBody(
    new Request("http://localhost/gmail-parse-failure-body", {
      method: "POST",
      headers: {
        Authorization: "Bearer user-jwt",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ failure_id: "inaccessible-failure" }),
    }),
    {
      requireUser: () =>
        Promise.resolve({
          userClient,
          user: { id: "13000000-0000-0000-0000-000000000002" },
        }),
      createServiceClient: () => {
        serviceClientCreated = true;
        throw new Error("Service client should not be created.");
      },
      refreshAccessToken: () => Promise.resolve({ access_token: "" }),
      fetchGmailMessage: () =>
        Promise.reject(new Error("Gmail should not be fetched.")),
      extractPlainText,
      messageMetadata,
      logOperationalEvent,
    },
  );

  assert(response.status === 403, `Unexpected status ${response.status}.`);
  assert(!serviceClientCreated, "Service client should not be used.");
  const json = await response.json();
  assert(
    json.error === "Visible Gmail parse failure not found.",
    "Unauthorized row should return the row-scoped authorization error.",
  );
});
