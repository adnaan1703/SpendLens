import {
  errorResponse,
  handleOptions,
  jsonResponse,
  readJsonBody,
} from "../_shared/http.ts";
import { errorMessage, logOperationalEvent } from "../_shared/observability.ts";
import { createServiceClient, requireUser } from "../_shared/supabase.ts";
import {
  callGeminiText,
  estimatedPreflightCostUsd,
  estimateGeminiCostUsd,
  geminiApiKey,
} from "../_shared/gemini.ts";

type BudgetStatus = {
  provider: string;
  model: string;
  free_tier_only: boolean;
  web_search_enabled: boolean;
};

type MerchantSuggestion = {
  suggested_display_name?: string | null;
  suggested_category_name?: string | null;
  suggested_subcategory_name?: string | null;
  confidence?: "high" | "medium" | "low";
  rationale?: string | null;
};

const systemInstruction = [
  "You research merchant statement names for a household finance app.",
  "Return JSON only.",
  "Do not change mappings directly.",
  "Prefer conservative suggestions and mark confidence low when unsure.",
  "Use web knowledge only if search grounding was explicitly enabled.",
].join(" ");

Deno.serve(async (req: Request) => {
  const options = handleOptions(req);
  if (options) return options;

  let householdId = "";
  let normalizedName = "";
  const serviceClient = createServiceClient();

  try {
    const { userClient, user } = await requireUser(req);
    const body = await readJsonBody(req);
    householdId = String(body.household_id ?? body.householdId ?? "").trim();
    const reviewItemId = optionalString(
      body.review_item_id ?? body.reviewItemId,
    );
    const statementMerchant = String(
      body.statement_merchant ?? body.statementMerchant ?? "",
    ).trim();

    if (!householdId) {
      throw new Error("Household is required.");
    }
    if (!statementMerchant) {
      throw new Error("Statement merchant is required.");
    }

    normalizedName = await normalizeMerchantName(userClient, statementMerchant);
    const cached = await cachedSuggestion(
      userClient,
      householdId,
      normalizedName,
    );
    if (cached) {
      await recordCachedUsage(
        serviceClient,
        householdId,
        user.id,
        normalizedName,
      );
      return jsonResponse({ suggestion: cached, cached: true });
    }

    const budget = await checkBudget(userClient, householdId);
    const context = await fetchMerchantContext(
      userClient,
      householdId,
      reviewItemId,
      statementMerchant,
    );
    const profileId = await profileIdForUser(serviceClient, user.id);
    const startedAt = new Date().toISOString();
    const { data: job, error: jobError } = await serviceClient
      .from("ai_jobs")
      .insert({
        household_id: householdId,
        profile_id: profileId,
        job_type: "merchant_research",
        status: "processing",
        input: {
          review_item_id: reviewItemId,
          statement_merchant: statementMerchant,
        },
        provider: budget.provider,
        model: budget.model,
        started_at: startedAt,
      })
      .select("id")
      .single();
    if (jobError) throw jobError;

    const prompt = JSON.stringify({
      statement_merchant: statementMerchant,
      normalized_merchant_name: normalizedName,
      household_context: context,
      required_json_shape: {
        suggested_display_name: "string or null",
        suggested_category_name: "string or null",
        suggested_subcategory_name: "string or null",
        confidence: "high | medium | low",
        rationale: "short string",
      },
    });
    const response = await callGeminiText({
      apiKey: geminiApiKey(),
      model: budget.model,
      systemInstruction,
      prompt,
      responseMimeType: "application/json",
      webSearchEnabled: budget.web_search_enabled,
    });
    const parsed = parseSuggestion(response.text);
    const estimatedCost = estimateGeminiCostUsd(
      response.usage,
      budget.free_tier_only,
    );
    const usageEventId = await recordUsage(serviceClient, {
      householdId,
      profileId,
      feature: "merchant_research",
      provider: budget.provider,
      model: budget.model,
      inputTokens: response.usage.inputTokens,
      outputTokens: response.usage.outputTokens,
      estimatedCostUsd: estimatedCost,
      status: "completed",
      requestMetadata: {
        job_id: job.id,
        normalized_merchant_name: normalizedName,
        web_search_enabled: budget.web_search_enabled,
      },
      responseMetadata: response.responseMetadata,
    });
    const category = await categoryMatch(
      userClient,
      householdId,
      parsed.suggested_category_name,
      parsed.suggested_subcategory_name,
    );
    const suggestionRows = await serviceClient.rpc(
      "upsert_merchant_research_suggestion",
      {
        p_household_id: householdId,
        p_review_item_id: reviewItemId,
        p_normalized_merchant_name: normalizedName,
        p_statement_merchant: statementMerchant,
        p_suggested_display_name: parsed.suggested_display_name ?? null,
        p_suggested_category_id: category.categoryId,
        p_suggested_subcategory_id: category.subcategoryId,
        p_evidence: {
          provider: budget.provider,
          model: budget.model,
          rationale: parsed.rationale ?? null,
          web_search_enabled: budget.web_search_enabled,
          grounding: response.responseMetadata.groundingMetadata ?? null,
        },
        p_confidence: parsed.confidence ?? "low",
        p_ai_job_id: job.id,
        p_usage_event_id: usageEventId,
      },
    );
    if (suggestionRows.error) throw suggestionRows.error;

    await serviceClient
      .from("ai_jobs")
      .update({
        status: "completed",
        output: {
          suggestion: parsed,
          usage: response.usage,
          estimated_cost_usd: estimatedCost,
        },
        usage_event_id: usageEventId,
        completed_at: new Date().toISOString(),
      })
      .eq("id", job.id);

    logOperationalEvent("merchant_research_completed", {
      householdId,
      jobId: job.id,
      normalizedName,
      webSearchEnabled: budget.web_search_enabled,
      estimatedCostUsd: estimatedCost,
    });

    const { data: freshSuggestion, error: freshSuggestionError } =
      await userClient
        .from("v_open_merchant_research_suggestions")
        .select("*")
        .eq("household_id", householdId)
        .eq("normalized_merchant_name", normalizedName)
        .maybeSingle();
    if (freshSuggestionError) throw freshSuggestionError;

    return jsonResponse({
      suggestion: freshSuggestion ?? (suggestionRows.data as unknown[])[0],
      cached: false,
      usage_event_id: usageEventId,
      estimated_cost_usd: estimatedCost,
    });
  } catch (error) {
    const message = errorMessage(error, "Unable to research merchant.");
    logOperationalEvent(
      "merchant_research_failed",
      { householdId, normalizedName, error: message },
      "error",
    );
    return errorResponse(message, 400);
  }
});

async function normalizeMerchantName(
  userClient: ReturnType<typeof createServiceClient>,
  value: string,
): Promise<string> {
  const { data, error } = await userClient.rpc("normalize_merchant_name", {
    value,
  });
  if (error) throw error;
  return String(data);
}

async function cachedSuggestion(
  userClient: ReturnType<typeof createServiceClient>,
  householdId: string,
  normalizedName: string,
): Promise<Record<string, unknown> | null> {
  const { data, error } = await userClient
    .from("v_open_merchant_research_suggestions")
    .select("*")
    .eq("household_id", householdId)
    .eq("normalized_merchant_name", normalizedName)
    .maybeSingle();
  if (error) throw error;
  return data ?? null;
}

async function checkBudget(
  userClient: ReturnType<typeof createServiceClient>,
  householdId: string,
): Promise<BudgetStatus> {
  const { data, error } = await userClient.rpc("check_ai_budget", {
    p_household_id: householdId,
    p_feature: "merchant_research",
    p_estimated_cost_usd: estimatedPreflightCostUsd(),
  });
  if (error) throw error;
  const row = Array.isArray(data) ? data[0] : data;
  if (!row) throw new Error("AI budget status was not returned.");
  return row as BudgetStatus;
}

async function fetchMerchantContext(
  userClient: ReturnType<typeof createServiceClient>,
  householdId: string,
  reviewItemId: string | null,
  statementMerchant: string,
): Promise<Record<string, unknown>> {
  const normalizedSearch = statementMerchant.trim();
  const [reviewItem, categories, merchants] = await Promise.all([
    reviewItemId
      ? userClient
        .from("v_review_queue")
        .select("*")
        .eq("household_id", householdId)
        .eq("id", reviewItemId)
        .maybeSingle()
      : Promise.resolve({ data: null, error: null }),
    userClient
      .from("categories")
      .select("id, name")
      .eq("household_id", householdId)
      .order("name"),
    userClient
      .from("v_merchant_summary")
      .select(
        "merchant_name, category_name, subcategory_name, transaction_count, net_spend",
      )
      .eq("household_id", householdId)
      .ilike("merchant_name", `%${normalizedSearch}%`)
      .limit(10),
  ]);
  for (const result of [reviewItem, categories, merchants]) {
    if (result.error) throw result.error;
  }
  return {
    review_item: reviewItem.data,
    categories: categories.data ?? [],
    related_merchants: merchants.data ?? [],
  };
}

async function categoryMatch(
  userClient: ReturnType<typeof createServiceClient>,
  householdId: string,
  categoryName: string | null | undefined,
  subcategoryName: string | null | undefined,
): Promise<{ categoryId: string | null; subcategoryId: string | null }> {
  if (!categoryName) {
    return { categoryId: null, subcategoryId: null };
  }

  const { data: category, error: categoryError } = await userClient
    .from("categories")
    .select("id")
    .eq("household_id", householdId)
    .ilike("name", categoryName)
    .maybeSingle();
  if (categoryError) throw categoryError;
  if (!category?.id) {
    return { categoryId: null, subcategoryId: null };
  }

  if (!subcategoryName) {
    return { categoryId: category.id as string, subcategoryId: null };
  }

  const { data: subcategory, error: subcategoryError } = await userClient
    .from("subcategories")
    .select("id")
    .eq("household_id", householdId)
    .eq("category_id", category.id)
    .ilike("name", subcategoryName)
    .maybeSingle();
  if (subcategoryError) throw subcategoryError;

  return {
    categoryId: category.id as string,
    subcategoryId: subcategory?.id as string | undefined ?? null,
  };
}

function parseSuggestion(text: string): MerchantSuggestion {
  const parsed = JSON.parse(text) as MerchantSuggestion;
  const confidence = parsed.confidence;
  return {
    suggested_display_name: optionalString(parsed.suggested_display_name),
    suggested_category_name: optionalString(parsed.suggested_category_name),
    suggested_subcategory_name: optionalString(
      parsed.suggested_subcategory_name,
    ),
    confidence: confidence === "high" || confidence === "medium" ||
        confidence === "low"
      ? confidence
      : "low",
    rationale: optionalString(parsed.rationale),
  };
}

async function profileIdForUser(
  serviceClient: ReturnType<typeof createServiceClient>,
  authUserId: string,
): Promise<string | null> {
  const { data, error } = await serviceClient
    .from("profiles")
    .select("id")
    .eq("auth_user_id", authUserId)
    .maybeSingle();
  if (error) throw error;
  return data?.id ?? null;
}

async function recordCachedUsage(
  serviceClient: ReturnType<typeof createServiceClient>,
  householdId: string,
  authUserId: string,
  normalizedName: string,
): Promise<void> {
  await recordUsage(serviceClient, {
    householdId,
    profileId: await profileIdForUser(serviceClient, authUserId),
    feature: "merchant_research",
    provider: "gemini",
    model: "gemini-3.5-flash",
    inputTokens: null,
    outputTokens: null,
    estimatedCostUsd: 0,
    status: "cached",
    requestMetadata: { normalized_merchant_name: normalizedName },
    responseMetadata: { cache_hit: true },
  });
}

async function recordUsage(
  serviceClient: ReturnType<typeof createServiceClient>,
  params: {
    householdId: string;
    profileId: string | null;
    feature: string;
    provider: string;
    model: string;
    inputTokens: number | null;
    outputTokens: number | null;
    estimatedCostUsd: number;
    status: string;
    requestMetadata: Record<string, unknown>;
    responseMetadata: Record<string, unknown>;
  },
): Promise<string> {
  const { data, error } = await serviceClient.rpc("record_ai_usage_event", {
    p_household_id: params.householdId,
    p_profile_id: params.profileId,
    p_feature: params.feature,
    p_provider: params.provider,
    p_model: params.model,
    p_input_tokens: params.inputTokens,
    p_output_tokens: params.outputTokens,
    p_estimated_cost_usd: params.estimatedCostUsd,
    p_status: params.status,
    p_request_metadata: params.requestMetadata,
    p_response_metadata: params.responseMetadata,
  });
  if (error) throw error;
  return String(data);
}

function optionalString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed === "" ? null : trimmed;
}
