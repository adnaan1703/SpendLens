import { base64UrlDecode } from "./crypto.ts";

type GmailPart = {
  mimeType?: string;
  body?: { data?: string };
  parts?: GmailPart[];
};

function extractParts(
  part: GmailPart | undefined,
  matches: string[],
): string[] {
  if (!part) {
    return matches;
  }

  if (part.mimeType === "text/plain" && part.body?.data) {
    matches.push(base64UrlDecode(part.body.data));
  }

  for (const child of part.parts ?? []) {
    extractParts(child, matches);
  }

  return matches;
}

function headerValue(
  message: Record<string, unknown>,
  name: string,
): string | null {
  const payload = message.payload as {
    headers?: Array<{ name?: string; value?: string }>;
  } | undefined;
  const header = payload?.headers?.find((candidate) =>
    candidate.name?.toLowerCase() === name.toLowerCase()
  );
  return header?.value ?? null;
}

export function extractPlainText(message: Record<string, unknown>): string {
  const payload = message.payload as GmailPart | undefined;
  const matches = extractParts(payload, []);

  if (matches.length > 0) {
    return matches.join("\n\n");
  }

  if (payload?.body?.data) {
    return base64UrlDecode(payload.body.data);
  }

  return String(message.snippet ?? "");
}

export function messageMetadata(
  message: Record<string, unknown>,
): Record<string, unknown> {
  const internalDate = message.internalDate
    ? Number(message.internalDate)
    : null;
  return {
    id: message.id,
    threadId: message.threadId,
    receivedAt: internalDate ? new Date(internalDate).toISOString() : null,
    from: headerValue(message, "From"),
    subject: headerValue(message, "Subject"),
    date: headerValue(message, "Date"),
  };
}
