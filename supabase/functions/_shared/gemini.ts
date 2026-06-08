export type GeminiUsage = {
  inputTokens: number | null;
  outputTokens: number | null;
  totalTokens: number | null;
};

export type GeminiTextResult = {
  text: string;
  usage: GeminiUsage;
  responseMetadata: Record<string, unknown>;
};

export type GeminiGenerateOptions = {
  apiKey: string;
  model: string;
  prompt: string;
  systemInstruction: string;
  responseMimeType?: string;
  webSearchEnabled?: boolean;
};

type GeminiUsageMetadata = {
  promptTokenCount?: number;
  candidatesTokenCount?: number;
  totalTokenCount?: number;
};

type GeminiCandidate = {
  content?: {
    parts?: Array<{ text?: string }>;
  };
  finishReason?: string;
  groundingMetadata?: Record<string, unknown>;
};

type GeminiResponse = {
  candidates?: GeminiCandidate[];
  usageMetadata?: GeminiUsageMetadata;
  promptFeedback?: Record<string, unknown>;
};

export function buildGeminiGenerateRequest(
  options: Omit<GeminiGenerateOptions, "apiKey" | "model">,
): Record<string, unknown> {
  const payload: Record<string, unknown> = {
    system_instruction: {
      parts: [{ text: options.systemInstruction }],
    },
    contents: [
      {
        role: "user",
        parts: [{ text: options.prompt }],
      },
    ],
    generationConfig: {
      temperature: 1,
      ...(options.responseMimeType
        ? { responseMimeType: options.responseMimeType }
        : {}),
    },
  };

  if (options.webSearchEnabled) {
    payload.tools = [{ google_search: {} }];
  }

  return payload;
}

export function parseGeminiTextResponse(
  data: GeminiResponse,
): GeminiTextResult {
  const candidate = data.candidates?.[0];
  const text = candidate?.content?.parts
    ?.map((part) => part.text ?? "")
    .join("")
    .trim() ?? "";

  if (!text) {
    const blockReason = data.promptFeedback?.blockReason;
    if (blockReason) {
      throw new Error(`Gemini blocked the prompt: ${blockReason}`);
    }
    throw new Error("Gemini did not return a text response.");
  }

  const usage = data.usageMetadata ?? {};
  return {
    text,
    usage: {
      inputTokens: usage.promptTokenCount ?? null,
      outputTokens: usage.candidatesTokenCount ?? null,
      totalTokens: usage.totalTokenCount ?? null,
    },
    responseMetadata: {
      finishReason: candidate?.finishReason ?? null,
      groundingMetadata: candidate?.groundingMetadata ?? null,
      promptFeedback: data.promptFeedback ?? null,
    },
  };
}

export async function callGeminiText(
  options: GeminiGenerateOptions,
): Promise<GeminiTextResult> {
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${
      encodeURIComponent(options.model)
    }:generateContent`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": options.apiKey,
      },
      body: JSON.stringify(buildGeminiGenerateRequest(options)),
    },
  );

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = typeof data?.error?.message === "string"
      ? data.error.message
      : "Gemini request failed.";
    throw new Error(message);
  }

  return parseGeminiTextResponse(data as GeminiResponse);
}

export function estimateGeminiCostUsd(
  usage: GeminiUsage,
  freeTierOnly: boolean,
): number {
  if (freeTierOnly) {
    return 0;
  }

  const inputRate = numberEnv("GEMINI_INPUT_COST_PER_MILLION_USD", 0);
  const outputRate = numberEnv("GEMINI_OUTPUT_COST_PER_MILLION_USD", 0);
  const inputCost = ((usage.inputTokens ?? 0) / 1_000_000) * inputRate;
  const outputCost = ((usage.outputTokens ?? 0) / 1_000_000) * outputRate;
  return Number((inputCost + outputCost).toFixed(6));
}

export function geminiApiKey(): string {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    throw new Error("Missing required environment variable: GEMINI_API_KEY");
  }
  return apiKey;
}

export function estimatedPreflightCostUsd(): number {
  return numberEnv("AI_ESTIMATED_COST_USD_PER_CALL", 0);
}

function numberEnv(name: string, fallback: number): number {
  let value: string | undefined;
  try {
    value = Deno.env.get(name);
  } catch {
    return fallback;
  }

  if (!value) {
    return fallback;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
}
