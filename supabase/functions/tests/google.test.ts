import {
  buildGmailTransactionSearchQuery,
  fetchGmailThread,
  listGmailHistory,
  listRecentGmailMessages,
  resolveWatchedGmailLabel,
  watchedGmailLabelName,
  watchGmailMailbox,
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

function withPubsubTopic<T>(run: () => T): T {
  const originalTopic = Deno.env.get("GOOGLE_PUBSUB_TOPIC");
  Deno.env.set("GOOGLE_PUBSUB_TOPIC", "projects/test/topics/gmail");
  try {
    return run();
  } finally {
    if (originalTopic === undefined) {
      Deno.env.delete("GOOGLE_PUBSUB_TOPIC");
    } else {
      Deno.env.set("GOOGLE_PUBSUB_TOPIC", originalTopic);
    }
  }
}

Deno.test("resolveWatchedGmailLabel finds the nested Gmail label by exact name", async () => {
  const originalFetch = globalThis.fetch;
  let requestedUrl: string | null = null;

  globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
    requestedUrl = input.toString();
    const authorization = new Headers(init?.headers).get("Authorization");
    assert(
      authorization === "Bearer access-token",
      `Unexpected authorization header: ${authorization}`,
    );
    return Promise.resolve(
      new Response(
        JSON.stringify({
          labels: [
            { id: "INBOX", name: "INBOX" },
            { id: "Label_123", name: watchedGmailLabelName },
          ],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );
  }) as typeof fetch;

  try {
    const label = await resolveWatchedGmailLabel("access-token");

    assert(
      requestedUrl ===
        "https://gmail.googleapis.com/gmail/v1/users/me/labels",
      `Unexpected Gmail labels URL: ${requestedUrl}`,
    );
    assert(label.id === "Label_123", `Unexpected label id: ${label.id}`);
    assert(
      label.name === watchedGmailLabelName,
      `Unexpected label name: ${label.name}`,
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("watchGmailMailbox configures the resolved label only", async () => {
  const originalFetch = globalThis.fetch;
  const requestBodies: Array<Record<string, unknown>> = [];

  globalThis.fetch = ((_input: string | URL | Request, init?: RequestInit) => {
    requestBodies.push(JSON.parse(String(init?.body ?? "{}")) as Record<
      string,
      unknown
    >);
    return Promise.resolve(
      new Response(JSON.stringify({ historyId: "123", expiration: "456" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    );
  }) as typeof fetch;

  try {
    const watch = await withPubsubTopic(() =>
      watchGmailMailbox("access-token", "Label_123")
    );

    assert(watch.historyId === "123", "Watch history id was not returned.");
    const requestBody = requestBodies[0];
    if (!requestBody) {
      throw new Error("Gmail watch request body was not captured.");
    }
    assert(
      JSON.stringify(requestBody.labelIds) === JSON.stringify(["Label_123"]),
      `Unexpected watched labels: ${JSON.stringify(requestBody.labelIds)}`,
    );
    assert(
      requestBody.labelFilterBehavior === "include",
      `Unexpected label filter behavior: ${requestBody.labelFilterBehavior}`,
    );
    assert(
      requestBody.topicName === "projects/test/topics/gmail",
      `Unexpected Pub/Sub topic: ${requestBody.topicName}`,
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
    !query.includes("from:alerts@hdfcbank.bank.in"),
    `Expected no sender fallback in label-based query: ${query}`,
  );
});

Deno.test("listRecentGmailMessages passes label, range query, and page size", async () => {
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
      labelIds: ["Label_123"],
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
    assert(
      observedUrl.searchParams.get("labelIds") === "Label_123",
      `Unexpected label filter: ${observedUrl.toString()}`,
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("listGmailHistory requests message and label-added changes for the watched label", async () => {
  const originalFetch = globalThis.fetch;
  const requestedUrls: URL[] = [];

  globalThis.fetch = ((input: string | URL | Request) => {
    requestedUrls.push(new URL(input.toString()));
    return Promise.resolve(
      new Response(
        JSON.stringify({
          historyId: "latest",
          history: [
            {
              messagesAdded: [{ message: { id: "m1", threadId: "t1" } }],
              labelsAdded: [{
                message: { id: "m2", threadId: "t2" },
                labelIds: ["Label_123"],
              }],
            },
          ],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );
  }) as typeof fetch;

  try {
    const page = await listGmailHistory(
      "access-token",
      "start-history",
      "next-page",
      "Label_123",
    );

    assert(page.historyId === "latest", "History id was not returned.");
    const observedUrl = requestedUrls[0];
    if (!observedUrl) {
      throw new Error("Gmail history URL was not requested.");
    }
    assert(
      observedUrl.searchParams.get("startHistoryId") === "start-history",
      `Unexpected start history id: ${observedUrl.toString()}`,
    );
    assert(
      observedUrl.searchParams.get("labelId") === "Label_123",
      `Unexpected history label id: ${observedUrl.toString()}`,
    );
    assert(
      observedUrl.searchParams.getAll("historyTypes").includes(
        "messageAdded",
      ) &&
        observedUrl.searchParams.getAll("historyTypes").includes("labelAdded"),
      `Unexpected history types: ${observedUrl.toString()}`,
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
});
