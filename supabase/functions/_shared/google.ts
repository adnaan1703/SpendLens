import { requiredEnv } from "./supabase.ts";

export const gmailReadonlyScope =
  "https://www.googleapis.com/auth/gmail.readonly";

type GoogleTokenResponse = {
  access_token: string;
  expires_in?: number;
  refresh_token?: string;
  scope?: string;
  token_type?: string;
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
  url.searchParams.set("prompt", "consent");
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

export async function watchGmailMailbox(accessToken: string): Promise<{
  historyId: string;
  expiration?: string;
  expirationDate?: string;
}> {
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
        labelIds: ["INBOX"],
        labelFilterBehavior: "INCLUDE",
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
): Promise<{
  history?: Array<
    { messagesAdded?: Array<{ message?: { id?: string; threadId?: string } }> }
  >;
  nextPageToken?: string;
  historyId?: string;
}> {
  const url = new URL("https://gmail.googleapis.com/gmail/v1/users/me/history");
  url.searchParams.set("startHistoryId", startHistoryId);
  url.searchParams.set("historyTypes", "messageAdded");
  if (pageToken) {
    url.searchParams.set("pageToken", pageToken);
  }

  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  return checkedGoogleJson(response, "Gmail history list");
}

export async function listRecentGmailMessages(
  accessToken: string,
  pageToken?: string,
): Promise<
  {
    messages?: Array<{ id: string; threadId?: string }>;
    nextPageToken?: string;
  }
> {
  const url = new URL(
    "https://gmail.googleapis.com/gmail/v1/users/me/messages",
  );
  url.searchParams.set("maxResults", "25");
  url.searchParams.set(
    "q",
    [
      "newer_than:30d",
      '("HDFC Bank Credit Card"',
      'OR "has been debited"',
      'OR "UPI transaction reference no"',
      'OR "You have done a UPI txn")',
    ].join(" "),
  );
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

export function tokenExpiryTimestamp(expiresIn?: number): string | null {
  if (!expiresIn) {
    return null;
  }

  return new Date(Date.now() + expiresIn * 1000).toISOString();
}
