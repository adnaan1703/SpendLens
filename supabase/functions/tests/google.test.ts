import { fetchGmailThread } from "../_shared/google.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

Deno.test("fetchGmailThread requests a full Gmail thread", async () => {
  const originalFetch = globalThis.fetch;
  let requestedUrl: string | null = null;
  let authorization: string | null = null;

  globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
    requestedUrl = input.toString();
    authorization = new Headers(init?.headers).get("Authorization");
    return Promise.resolve(
      new Response(
        JSON.stringify({
          id: "thread-1",
          messages: [{ id: "message-1", threadId: "thread-1" }],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );
  }) as typeof fetch;

  try {
    const thread = await fetchGmailThread("access-token", "thread-1");

    assert(
      requestedUrl ===
        "https://gmail.googleapis.com/gmail/v1/users/me/threads/thread-1?format=full",
      `Unexpected Gmail thread URL: ${requestedUrl}`,
    );
    assert(
      authorization === "Bearer access-token",
      `Unexpected authorization header: ${authorization}`,
    );
    assert(thread.id === "thread-1", "Thread response id was not returned.");
    assert(
      thread.messages?.[0]?.id === "message-1",
      "Thread messages were not returned.",
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
});
