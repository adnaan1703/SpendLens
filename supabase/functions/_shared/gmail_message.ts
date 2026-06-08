import { base64UrlDecode } from "./crypto.ts";

type GmailPart = {
  mimeType?: string;
  body?: { data?: string };
  parts?: GmailPart[];
};

function extractParts(
  part: GmailPart | undefined,
  mimeType: string,
  matches: string[],
): string[] {
  if (!part) {
    return matches;
  }

  if (part.mimeType === mimeType && part.body?.data) {
    matches.push(base64UrlDecode(part.body.data));
  }

  for (const child of part.parts ?? []) {
    extractParts(child, mimeType, matches);
  }

  return matches;
}

function decodeHtmlEntities(value: string): string {
  return value
    .replaceAll(
      /&#(\d+);/g,
      (_match, codePoint) => String.fromCodePoint(Number(codePoint)),
    )
    .replaceAll(
      /&#x([0-9a-f]+);/gi,
      (_match, codePoint) =>
        String.fromCodePoint(Number.parseInt(codePoint, 16)),
    )
    .replaceAll(/&nbsp;/gi, " ")
    .replaceAll(/&amp;/gi, "&")
    .replaceAll(/&quot;/gi, '"')
    .replaceAll(/&#39;/g, "'")
    .replaceAll(/&lt;/gi, "<")
    .replaceAll(/&gt;/gi, ">");
}

function htmlToPlainText(value: string): string {
  return decodeHtmlEntities(
    value
      .replaceAll(/<style[\s\S]*?<\/style>/gi, " ")
      .replaceAll(/<script[\s\S]*?<\/script>/gi, " ")
      .replaceAll(/<(?:br|\/p|\/div|\/tr|\/li)\b[^>]*>/gi, "\n")
      .replaceAll(/<[^>]+>/g, " "),
  )
    .replaceAll(/\s+([.,:;!?])/g, "$1")
    .replaceAll(/[ \t\r\f\v]+/g, " ")
    .replaceAll(/\n\s+/g, "\n")
    .replaceAll(/\n{3,}/g, "\n\n")
    .trim();
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
  const matches = extractParts(payload, "text/plain", []);

  if (matches.length > 0) {
    return matches.join("\n\n");
  }

  const htmlMatches = extractParts(payload, "text/html", [])
    .map(htmlToPlainText)
    .filter((value) => value.length > 0);
  if (htmlMatches.length > 0) {
    return htmlMatches.join("\n\n");
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
