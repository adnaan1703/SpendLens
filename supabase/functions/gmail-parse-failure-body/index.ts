import { fetchGmailMessage, refreshAccessToken } from "../_shared/google.ts";
import { extractPlainText, messageMetadata } from "../_shared/gmail_message.ts";
import {
  errorResponse,
  handleOptions,
  jsonResponse,
  readJsonBody,
} from "../_shared/http.ts";
import { errorMessage, logOperationalEvent } from "../_shared/observability.ts";
import {
  createServiceClient,
  requireUser,
  type SupabaseClientLike,
} from "../_shared/supabase.ts";

type AuthorizedParseFailure = {
  failure_id: string;
  household_id: string;
  linked_mailbox_id: string;
  mailbox_email: string;
  candidate_type: string;
  source_message_id: string;
  source_thread_id: string | null;
  source_received_at: string;
  sender_email: string;
  subject: string;
  parser_name: string;
  parser_version: string;
  reason_code: string | null;
};

type RequireUserResult = {
  userClient: SupabaseClientLike;
  user: { id: string; email?: string };
};

type AccessTokenResponse = {
  access_token: string;
};

type GmailParseFailureBodyDependencies = {
  requireUser: (req: Request) => Promise<RequireUserResult>;
  createServiceClient: () => SupabaseClientLike;
  refreshAccessToken: (refreshToken: string) => Promise<AccessTokenResponse>;
  fetchGmailMessage: (
    accessToken: string,
    messageId: string,
  ) => Promise<Record<string, unknown>>;
  extractPlainText: (message: Record<string, unknown>) => string;
  messageMetadata: (
    message: Record<string, unknown>,
  ) => Record<string, unknown>;
  logOperationalEvent: typeof logOperationalEvent;
};

const defaultDependencies: GmailParseFailureBodyDependencies = {
  requireUser,
  createServiceClient,
  refreshAccessToken,
  fetchGmailMessage,
  extractPlainText,
  messageMetadata,
  logOperationalEvent,
};

function bodyFailureId(
  body: Record<string, unknown>,
  req: Request,
): string {
  const url = new URL(req.url);
  return String(
    body.failure_id ?? body.failureId ?? url.searchParams.get("failure_id") ??
      "",
  ).trim();
}

function firstRow<T>(data: unknown): T | null {
  if (Array.isArray(data)) {
    return (data[0] as T | undefined) ?? null;
  }
  return (data as T | null) ?? null;
}

export async function handleGmailParseFailureBody(
  req: Request,
  dependencies: GmailParseFailureBodyDependencies = defaultDependencies,
): Promise<Response> {
  const options = handleOptions(req);
  if (options) return options;

  let failureId = "";

  try {
    const { userClient } = await dependencies.requireUser(req);
    const body = await readJsonBody(req);
    failureId = bodyFailureId(body, req);

    if (!failureId) {
      return errorResponse("failure_id is required.", 400);
    }

    const { data: authorizedRows, error: authorizationError } = await userClient
      .rpc("authorize_gmail_parse_failure_body", {
        p_failure_id: failureId,
      });
    if (authorizationError) {
      throw authorizationError;
    }

    const authorized = firstRow<AuthorizedParseFailure>(authorizedRows);
    if (!authorized) {
      return errorResponse("Visible Gmail parse failure not found.", 403);
    }

    const serviceClient = dependencies.createServiceClient();
    const { data: refreshToken, error: tokenError } = await serviceClient.rpc(
      "get_gmail_refresh_token",
      { p_mailbox_id: authorized.linked_mailbox_id },
    );
    if (tokenError || !refreshToken) {
      throw tokenError ?? new Error("Gmail refresh token unavailable.");
    }

    const token = await dependencies.refreshAccessToken(String(refreshToken));
    const message = await dependencies.fetchGmailMessage(
      token.access_token,
      authorized.source_message_id,
    );
    const metadata = dependencies.messageMetadata(message);

    return jsonResponse({
      failure: {
        failure_id: authorized.failure_id,
        household_id: authorized.household_id,
        mailbox: {
          id: authorized.linked_mailbox_id,
          email: authorized.mailbox_email,
        },
        candidate_type: authorized.candidate_type,
        source_message_id: authorized.source_message_id,
        source_thread_id: authorized.source_thread_id,
        source_received_at: authorized.source_received_at,
        sender_email: authorized.sender_email,
        subject: authorized.subject,
        parser_name: authorized.parser_name,
        parser_version: authorized.parser_version,
        reason_code: authorized.reason_code,
      },
      message: {
        id: metadata.id ?? authorized.source_message_id,
        thread_id: metadata.threadId ?? authorized.source_thread_id,
        received_at: metadata.receivedAt ?? null,
        from: metadata.from ?? null,
        subject: metadata.subject ?? null,
        date: metadata.date ?? null,
      },
      plain_text_body: dependencies.extractPlainText(message),
    });
  } catch (error) {
    const message = errorMessage(
      error,
      "Unable to fetch Gmail parse failure body.",
    );
    dependencies.logOperationalEvent(
      "gmail_parse_failure_body_failed",
      { failureId, error: message },
      "error",
    );
    return errorResponse(message, 400);
  }
}

if (import.meta.main) {
  Deno.serve((req) => handleGmailParseFailureBody(req));
}
