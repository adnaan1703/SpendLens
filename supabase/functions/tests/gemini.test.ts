import {
  buildGeminiGenerateRequest,
  callGeminiText,
  estimateGeminiCostUsd,
  parseGeminiTextResponse,
} from "../_shared/gemini.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

Deno.test("Gemini request includes Google Search only when enabled", () => {
  const withoutSearch = buildGeminiGenerateRequest({
    systemInstruction: "system",
    prompt: "prompt",
  });
  assert(
    !("tools" in withoutSearch),
    "Search tools should not be present by default.",
  );

  const withSearch = buildGeminiGenerateRequest({
    systemInstruction: "system",
    prompt: "prompt",
    webSearchEnabled: true,
    responseMimeType: "application/json",
  });
  const tools = withSearch.tools as Array<Record<string, unknown>>;
  const generationConfig = withSearch.generationConfig as Record<
    string,
    unknown
  >;

  assert(
    Boolean(tools[0]?.google_search),
    "Google Search tool was not wired when enabled.",
  );
  assert(
    generationConfig.responseMimeType === "application/json",
    "Response MIME type was not included.",
  );
});

Deno.test("Gemini request includes structured JSON schema when supplied", () => {
  const schema = {
    type: "object",
    properties: {
      merchant_group: { type: "string" },
    },
    required: ["merchant_group"],
  };
  const request = buildGeminiGenerateRequest({
    systemInstruction: "system",
    prompt: "prompt",
    responseMimeType: "application/json",
    responseJsonSchema: schema,
  });
  const generationConfig = request.generationConfig as Record<
    string,
    unknown
  >;

  assert(
    generationConfig.responseMimeType === "application/json",
    "Response MIME type was not included.",
  );
  assert(
    generationConfig.responseJsonSchema === schema,
    "Structured response JSON schema was not included.",
  );
});

Deno.test("Gemini response parsing returns text and token usage", () => {
  const parsed = parseGeminiTextResponse({
    candidates: [{
      finishReason: "STOP",
      content: { parts: [{ text: "Answer" }] },
    }],
    usageMetadata: {
      promptTokenCount: 10,
      candidatesTokenCount: 5,
      totalTokenCount: 15,
    },
  });

  assert(parsed.text === "Answer", "Text was not parsed.");
  assert(parsed.usage.inputTokens === 10, "Input token count was not parsed.");
  assert(parsed.usage.outputTokens === 5, "Output token count was not parsed.");
  assert(parsed.usage.totalTokens === 15, "Total token count was not parsed.");
});

Deno.test("Gemini cost accounting respects free-tier mode", () => {
  const usage = {
    inputTokens: 1_000_000,
    outputTokens: 1_000_000,
    totalTokens: 2_000_000,
  };
  assert(
    estimateGeminiCostUsd(usage, true) === 0,
    "Free-tier accounting should log zero paid cost.",
  );
  assert(
    estimateGeminiCostUsd(usage, false) === 0,
    "Paid cost estimate should stay zero until explicit rates are configured.",
  );
});

Deno.test("callGeminiText sends REST request with API key header", async () => {
  const originalFetch = globalThis.fetch;
  let requestedUrl: string | null = null;
  let apiKey: string | null = null;

  globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
    requestedUrl = input.toString();
    apiKey = new Headers(init?.headers).get("x-goog-api-key");
    return Promise.resolve(
      new Response(
        JSON.stringify({
          candidates: [{ content: { parts: [{ text: "OK" }] } }],
          usageMetadata: { promptTokenCount: 2, candidatesTokenCount: 1 },
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );
  }) as typeof fetch;

  try {
    const response = await callGeminiText({
      apiKey: "test-key",
      model: "gemini-3.5-flash",
      systemInstruction: "system",
      prompt: "prompt",
    });

    assert(
      requestedUrl ===
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent",
      `Unexpected Gemini URL: ${requestedUrl}`,
    );
    assert(apiKey === "test-key", `Unexpected API key header: ${apiKey}`);
    assert(response.text === "OK", "Gemini response text was not returned.");
  } finally {
    globalThis.fetch = originalFetch;
  }
});
