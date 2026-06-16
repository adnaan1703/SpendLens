import { requiredEnv } from "./supabase.ts";
import { assertIsoDate } from "./gmail_range.ts";

export const gmailReadonlyScope =
  "https://www.googleapis.com/auth/gmail.readonly";

export const watchedGmailLabelName = "Banking/HDFC Transactions";

type GoogleTokenResponse = {
  access_token: string;
  expires_in?: number;
  refresh_token?: string;
  scope?: string;
  token_type?: string;
};

export type GmailMessageSummary = {
  id: string;
  threadId?: string;
};

export type GmailLabel = {
  id: string;
  name: string;
};

export type GmailMessageListOptions = {
  query?: string;
  searchStartDate?: string | null;
  searchEndDateExclusive?: string | null;
  maxResults?: number;
  labelIds?: string[];
};

export class GoogleApiError extends Error {
  constructor(message: string, readonly status: number, readonly body: string) {
    super(message);
    this.name = "GoogleApiError";
  }
}

async function checkedGoogleJson<T>(
  response: Response,
  label: string,
): Promise<T> {
  const body = await response.text();
  if (!response.ok) {
    throw new GoogleApiError(
      `${label} failed with ${response.status}`,
      response.status,
      body,
    );
  }

  return JSON.parse(body) as T;
}

export function buildGoogleOAuthUrl(state: string): string {
  const url = new URL("https://accounts.google.com/o/oauth2/v2/auth");
  url.searchParams.set("client_id", requiredEnv("GOOGLE_OAUTH_CLIENT_ID"));
  url.searchParams.set(
    "redirect_uri",
    requiredEnv("GOOGLE_OAUTH_CALLBACK_URL"),
  );
  url.searchParams.set("response_type", "code");
  url.searchParams.set("scope", gmailReadonlyScope);
  url.searchParams.set("access_type", "offline");
  url.searchParams.set("prompt", "consent select_account");
  url.searchParams.set("include_granted_scopes", "true");
  url.searchParams.set("state", state);
  return url.toString();
}

export async function exchangeCodeForTokens(
  code: string,
): Promise<GoogleTokenResponse> {
  const body = new URLSearchParams({
    client_id: requiredEnv("GOOGLE_OAUTH_CLIENT_ID"),
    client_secret: requiredEnv("GOOGLE_OAUTH_CLIENT_SECRET"),
    code,
    grant_type: "authorization_code",
    redirect_uri: requiredEnv("GOOGLE_OAUTH_CALLBACK_URL"),
  });

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  return checkedGoogleJson<GoogleTokenResponse>(
    response,
    "Google OAuth token exchange",
  );
}

export async function refreshAccessToken(
  refreshToken: string,
): Promise<GoogleTokenResponse> {
  const body = new URLSearchParams({
    client_id: requiredEnv("GOOGLE_OAUTH_CLIENT_ID"),
    client_secret: requiredEnv("GOOGLE_OAUTH_CLIENT_SECRET"),
    grant_type: "refresh_token",
    refresh_token: refreshToken,
  });

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  return checkedGoogleJson<GoogleTokenResponse>(
    response,
    "Google OAuth token refresh",
  );
}

export async function fetchGmailProfile(accessToken: string): Promise<{
  emailAddress: string;
  historyId?: string;
}> {
  const response = await fetch(
    "https://gmail.googleapis.com/gmail/v1/users/me/profile",
    {
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  );

  return checkedGoogleJson(response, "Gmail profile fetch");
}

export async function listGmailLabels(
  accessToken: string,
): Promise<GmailLabel[]> {
  const response = await fetch(
    "https://gmail.googleapis.com/gmail/v1/users/me/labels",
    {
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  );

  const body = await checkedGoogleJson<{ labels?: GmailLabel[] }>(
    response,
    "Gmail labels list",
  );
  return body.labels ?? [];
}

export async function resolveWatchedGmailLabel(
  accessToken: string,
): Promise<GmailLabel> {
  const labels = await listGmailLabels(accessToken);
  const label = labels.find((candidate) =>
    candidate.name === watchedGmailLabelName
  );

  if (!label?.id) {
    throw new Error(
      `Gmail label ${watchedGmailLabelName} was not found. Create the nested Gmail label before connecting or renewing Gmail ingestion.`,
    );
  }

  return label;
}

export async function watchGmailMailbox(
  accessToken: string,
  labelId: string,
): Promise<{
  historyId: string;
  expiration?: string;
  expirationDate?: string;
}> {
  const watchedLabelId = labelId.trim();
  if (!watchedLabelId) {
    throw new Error(
      "Watched Gmail label id is required for Gmail watch setup.",
    );
  }

  const response = await fetch(
    "https://gmail.googleapis.com/gmail/v1/users/me/watch",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        topicName: requiredEnv("GOOGLE_PUBSUB_TOPIC"),
        labelIds: [watchedLabelId],
        labelFilterBehavior: "include",
      }),
    },
  );

  const body = await checkedGoogleJson<
    { historyId: string; expiration?: string }
  >(
    response,
    "Gmail watch setup",
  );
  return {
    ...body,
    expirationDate: body.expiration
      ? new Date(Number(body.expiration)).toISOString()
      : undefined,
  };
}

export async function stopGmailMailbox(accessToken: string): Promise<void> {
  const response = await fetch(
    "https://gmail.googleapis.com/gmail/v1/users/me/stop",
    {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  );

  if (!response.ok) {
    throw new GoogleApiError(
      `Gmail watch stop failed with ${response.status}`,
      response.status,
      await response.text(),
    );
  }
}

export async function listGmailHistory(
  accessToken: string,
  startHistoryId: string,
  pageToken?: string,
  labelId?: string,
): Promise<{
  history?: Array<
    {
      messagesAdded?: Array<{ message?: GmailMessageSummary }>;
      labelsAdded?: Array<{
        message?: GmailMessageSummary;
        labelIds?: string[];
      }>;
    }
  >;
  nextPageToken?: string;
  historyId?: string;
}> {
  const url = new URL("https://gmail.googleapis.com/gmail/v1/users/me/history");
  url.searchParams.set("startHistoryId", startHistoryId);
  url.searchParams.append("historyTypes", "messageAdded");
  url.searchParams.append("historyTypes", "labelAdded");
  if (labelId?.trim()) {
    url.searchParams.set("labelId", labelId.trim());
  }
  if (pageToken) {
    url.searchParams.set("pageToken", pageToken);
  }

  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  return checkedGoogleJson(response, "Gmail history list");
}

function gmailSearchDate(date: string): string {
  return assertIsoDate(date, "Gmail search date").replaceAll("-", "/");
}

export function buildGmailTransactionSearchQuery(
  options: GmailMessageListOptions = {},
): string {
  const query = options.query?.trim();
  if (query) {
    return query;
  }

  const dateParts: string[] = [];

  if (options.searchStartDate) {
    dateParts.push(`after:${gmailSearchDate(options.searchStartDate)}`);
  }

  if (options.searchEndDateExclusive) {
    dateParts.push(
      `before:${gmailSearchDate(options.searchEndDateExclusive)}`,
    );
  }

  if (dateParts.length === 0) {
    dateParts.push("newer_than:30d");
  }

  return dateParts.join(" ");
}

export async function listRecentGmailMessages(
  accessToken: string,
  pageToken?: string,
  options: GmailMessageListOptions = {},
): Promise<{
  messages?: GmailMessageSummary[];
  nextPageToken?: string;
}> {
  const url = new URL(
    "https://gmail.googleapis.com/gmail/v1/users/me/messages",
  );
  const maxResults = Math.min(
    Math.max(Number(options.maxResults ?? 25), 1),
    500,
  );
  url.searchParams.set("maxResults", String(maxResults));
  url.searchParams.set("q", buildGmailTransactionSearchQuery(options));
  for (const labelId of options.labelIds ?? []) {
    const normalizedLabelId = labelId.trim();
    if (normalizedLabelId) {
      url.searchParams.append("labelIds", normalizedLabelId);
    }
  }
  if (pageToken) {
    url.searchParams.set("pageToken", pageToken);
  }

  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  return checkedGoogleJson(response, "Gmail messages list");
}

export async function fetchGmailMessage(
  accessToken: string,
  id: string,
): Promise<Record<string, unknown>> {
  const url = new URL(
    `https://gmail.googleapis.com/gmail/v1/users/me/messages/${id}`,
  );
  url.searchParams.set("format", "full");

  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  return checkedGoogleJson<Record<string, unknown>>(
    response,
    "Gmail message fetch",
  );
}

export async function fetchGmailThread(
  accessToken: string,
  id: string,
): Promise<{ id?: string; messages?: Array<Record<string, unknown>> }> {
  const url = new URL(
    `https://gmail.googleapis.com/gmail/v1/users/me/threads/${id}`,
  );
  url.searchParams.set("format", "full");

  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  return checkedGoogleJson(response, "Gmail thread fetch");
}

export function tokenExpiryTimestamp(expiresIn?: number): string | null {
  if (!expiresIn) {
    return null;
  }

  return new Date(Date.now() + expiresIn * 1000).toISOString();
}
