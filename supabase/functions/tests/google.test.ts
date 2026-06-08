import {
  buildGmailTransactionSearchQuery,
  fetchGmailThread,
  listRecentGmailMessages,
} from "../_shared/google.ts";

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

Deno.test("buildGmailTransactionSearchQuery uses buffered date bounds", () => {
  const query = buildGmailTransactionSearchQuery({
    searchStartDate: "2026-04-30",
    searchEndDateExclusive: "2026-05-02",
  });

  assert(
    query.includes("after:2026/04/30"),
    `Expected Gmail after bound in query: ${query}`,
  );
  assert(
    query.includes("before:2026/05/02"),
    `Expected Gmail before bound in query: ${query}`,
  );
  assert(
    query.includes("from:alerts@hdfcbank.bank.in"),
    `Expected HDFC alert sender in query: ${query}`,
  );
});

Deno.test("listRecentGmailMessages passes range query and page size", async () => {
  const originalFetch = globalThis.fetch;
  const requestedUrls: URL[] = [];

  globalThis.fetch = ((input: string | URL | Request) => {
    requestedUrls.push(new URL(input.toString()));
    return Promise.resolve(
      new Response(
        JSON.stringify({
          messages: [{ id: "message-1", threadId: "thread-1" }],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );
  }) as typeof fetch;

  try {
    const page = await listRecentGmailMessages("access-token", "next-page", {
      searchStartDate: "2026-04-30",
      searchEndDateExclusive: "2026-05-02",
      maxResults: 200,
    });

    assert(page.messages?.[0]?.id === "message-1", "Messages were not read.");
    const observedUrl = requestedUrls[0];
    if (!observedUrl) {
      throw new Error("Gmail list URL was not requested.");
    }
    assert(
      observedUrl.searchParams.get("pageToken") === "next-page",
      `Unexpected page token: ${observedUrl.toString()}`,
    );
    assert(
      observedUrl.searchParams.get("maxResults") === "200",
      `Unexpected maxResults: ${observedUrl.toString()}`,
    );
    const query = observedUrl.searchParams.get("q") ?? "";
    assert(
      query.includes("after:2026/04/30") &&
        query.includes("before:2026/05/02"),
      `Unexpected Gmail query: ${query}`,
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
});
