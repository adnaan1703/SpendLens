import { fetchGmailMessage, refreshAccessToken } from "../_shared/google.ts";
import { base64UrlDecode } from "../_shared/crypto.ts";
import { extractPlainText, messageMetadata } from "../_shared/gmail_message.ts";
import {
  errorResponse,
  handleOptions,
  jsonResponse,
  readJsonBody,
} from "../_shared/http.ts";
import {
  createServiceClient,
  requireServiceRequest,
} from "../_shared/supabase.ts";
import { errorMessage, logOperationalEvent } from "../_shared/observability.ts";

function requiredString(
  value: unknown,
  label: string,
): string {
  const text = String(value ?? "").trim();
  if (!text) {
    throw new Error(`${label} is required.`);
  }
  return text;
}

type GmailPart = {
  mimeType?: string;
  filename?: string;
  body?: { data?: string; size?: number };
  parts?: GmailPart[];
};

function strippedPreview(value: string): string {
  return value.replaceAll(/<style[\s\S]*?<\/style>/gi, " ")
    .replaceAll(/<script[\s\S]*?<\/script>/gi, " ")
    .replaceAll(/<[^>]+>/g, " ")
    .replaceAll(/&nbsp;/gi, " ")
    .replaceAll(/&amp;/gi, "&")
    .replaceAll(/\s+/g, " ")
    .trim()
    .slice(0, 300);
}

function bodyPartSummaries(
  part: GmailPart | undefined,
  path = "payload",
): Array<Record<string, unknown>> {
  if (!part) {
    return [];
  }

  const summaries: Array<Record<string, unknown>> = [];
  const data = part.body?.data;
  let decodedPreview: string | null = null;

  if (
    data &&
    (part.mimeType === "text/plain" || part.mimeType === "text/html")
  ) {
    decodedPreview = strippedPreview(base64UrlDecode(data));
  }

  summaries.push({
    path,
    mime_type: part.mimeType ?? null,
    filename: part.filename ?? null,
    body_size: part.body?.size ?? null,
    has_data: Boolean(data),
    decoded_preview: decodedPreview,
  });

  for (const [index, child] of (part.parts ?? []).entries()) {
    summaries.push(...bodyPartSummaries(child, `${path}.parts[${index}]`));
  }

  return summaries;
}

Deno.serve(async (req: Request) => {
  const options = handleOptions(req);
  if (options) return options;

  try {
    requireServiceRequest(req);

    const body = await readJsonBody(req);
    const mailboxId = requiredString(
      body.mailbox_id ?? body.linked_mailbox_id,
      "mailbox_id",
    );
    const sourceMessageId = requiredString(
      body.source_message_id ?? body.message_id,
      "source_message_id",
    );

    const serviceClient = createServiceClient();
    const { data: mailbox, error: mailboxError } = await serviceClient
      .from("linked_mailboxes")
      .select("id, household_id, email, provider, is_active")
      .eq("id", mailboxId)
      .maybeSingle();

    if (mailboxError || !mailbox) {
      throw mailboxError ?? new Error("Mailbox not found.");
    }

    if (mailbox.provider !== "gmail") {
      throw new Error("Mailbox is not a Gmail mailbox.");
    }

    if (!mailbox.is_active) {
      throw new Error("Mailbox is not active.");
    }

    const { data: refreshToken, error: tokenError } = await serviceClient.rpc(
      "get_gmail_refresh_token",
      { p_mailbox_id: mailbox.id },
    );
    if (tokenError || !refreshToken) {
      throw tokenError ?? new Error("Gmail refresh token unavailable.");
    }

    const token = await refreshAccessToken(String(refreshToken));
    const message = await fetchGmailMessage(
      token.access_token,
      sourceMessageId,
    );
    const metadata = messageMetadata(message);
    const plainTextBody = extractPlainText(message);

    return jsonResponse({
      mailbox: {
        id: mailbox.id,
        household_id: mailbox.household_id,
        email: mailbox.email,
      },
      source_message_id: sourceMessageId,
      message: {
        id: metadata.id,
        thread_id: metadata.threadId,
        received_at: metadata.receivedAt,
        from: metadata.from,
        subject: metadata.subject,
        date: metadata.date,
        snippet: String(message.snippet ?? ""),
      },
      plain_text_body: plainTextBody,
      body_parts: bodyPartSummaries(message.payload as GmailPart | undefined),
    });
  } catch (error) {
    logOperationalEvent(
      "gmail_message_body_failed",
      { error: errorMessage(error, "Unable to fetch Gmail message body.") },
      "error",
    );
    return errorResponse(
      errorMessage(error, "Unable to fetch Gmail message body."),
      400,
    );
  }
});
