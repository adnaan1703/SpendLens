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
import {
  buildTransactionMetadataSuggestionPrompt,
  parseTransactionMetadataSuggestion,
  transactionMetadataSuggestionFeature,
  transactionMetadataSuggestionSchema,
  transactionMetadataSuggestionSystemInstruction,
  type TransactionMetadataTaxonomyCategory,
} from "../_shared/transaction_metadata_suggestion.ts";

type BudgetStatus = {
  household_id: string;
  provider: string;
  model: string;
  monthly_spend_cap_usd: number;
  current_month_spend_usd: number;
  remaining_monthly_budget_usd: number;
  free_tier_only: boolean;
  web_search_enabled: boolean;
};

type SuggestionContext = {
  transactionFacts: Record<string, unknown>;
  currentEditorValues: Record<string, unknown>;
  reviewItem: Record<string, unknown> | null;
  taxonomy: TransactionMetadataTaxonomyCategory[];
  nearbyMerchantContext: Record<string, unknown>;
};

Deno.serve(async (req: Request) => {
  const options = handleOptions(req);
  if (options) return options;

  let jobId: string | null = null;
  let householdId = "";
  let transactionId = "";
  const serviceClient = createServiceClient();

  try {
    const { userClient, user } = await requireUser(req);
    const body = await readJsonBody(req);
    householdId = String(body.household_id ?? body.householdId ?? "").trim();
    transactionId = String(
      body.transaction_id ?? body.transactionId ?? "",
    ).trim();
    const reviewItemId = optionalString(
      body.review_item_id ?? body.reviewItemId,
    );

    if (!householdId) {
      throw new Error("Household is required.");
    }
    if (!transactionId) {
      throw new Error("Transaction is required.");
    }

    const budget = await checkBudget(userClient, householdId);
    const context = await fetchSuggestionContext(
      userClient,
      householdId,
      transactionId,
      reviewItemId,
    );
    const profileId = await profileIdForUser(serviceClient, user.id);

    const { data: job, error: jobError } = await serviceClient
      .from("ai_jobs")
      .insert({
        household_id: householdId,
        profile_id: profileId,
        job_type: transactionMetadataSuggestionFeature,
        status: "processing",
        input: {
          transaction_id: transactionId,
          review_item_id: reviewItemId,
        },
        provider: budget.provider,
        model: budget.model,
        started_at: new Date().toISOString(),
      })
      .select("id")
      .single();
    if (jobError) throw jobError;
    jobId = job.id as string;

    const response = await callGeminiText({
      apiKey: geminiApiKey(),
      model: budget.model,
      systemInstruction: transactionMetadataSuggestionSystemInstruction,
      prompt: buildTransactionMetadataSuggestionPrompt(context),
      responseMimeType: "application/json",
      responseJsonSchema: transactionMetadataSuggestionSchema,
      webSearchEnabled: budget.web_search_enabled,
    });
    const suggestion = parseTransactionMetadataSuggestion(
      response.text,
      context.taxonomy,
    );
    const estimatedCost = estimateGeminiCostUsd(
      response.usage,
      budget.free_tier_only,
    );
    const usageEventId = await recordUsage(serviceClient, {
      householdId,
      profileId,
      feature: transactionMetadataSuggestionFeature,
      provider: budget.provider,
      model: budget.model,
      inputTokens: response.usage.inputTokens,
      outputTokens: response.usage.outputTokens,
      estimatedCostUsd: estimatedCost,
      status: "completed",
      requestMetadata: {
        job_id: jobId,
        transaction_id: transactionId,
        review_item_id: reviewItemId,
      },
      responseMetadata: response.responseMetadata,
    });

    const { error: updateError } = await serviceClient
      .from("ai_jobs")
      .update({
        status: "completed",
        output: {
          suggestion,
          usage: response.usage,
          estimated_cost_usd: estimatedCost,
        },
        usage_event_id: usageEventId,
        completed_at: new Date().toISOString(),
      })
      .eq("id", jobId);
    if (updateError) throw updateError;

    logOperationalEvent("transaction_metadata_suggestion_completed", {
      householdId,
      transactionId,
      reviewItemId,
      jobId,
      estimatedCostUsd: estimatedCost,
    });

    return jsonResponse({
      suggestion: {
        merchant_group: suggestion.merchantGroup,
        category_id: suggestion.categoryId,
        subcategory_id: suggestion.subcategoryId,
        confidence: suggestion.confidence,
        notes: suggestion.notes,
      },
      job_id: jobId,
      usage_event_id: usageEventId,
      usage: response.usage,
      estimated_cost_usd: estimatedCost,
      budget: {
        monthly_spend_cap_usd: budget.monthly_spend_cap_usd,
        current_month_spend_usd: budget.current_month_spend_usd,
        remaining_monthly_budget_usd: budget.remaining_monthly_budget_usd,
        free_tier_only: budget.free_tier_only,
      },
    });
  } catch (error) {
    const message = errorMessage(
      error,
      "Unable to suggest transaction metadata.",
    );
    if (jobId) {
      const { error: updateError } = await serviceClient
        .from("ai_jobs")
        .update({
          status: "failed",
          error_message: message,
          completed_at: new Date().toISOString(),
        })
        .eq("id", jobId);
      if (updateError) {
        logOperationalEvent(
          "transaction_metadata_suggestion_job_update_failed",
          { householdId, transactionId, jobId, error: updateError.message },
          "error",
        );
      }
    }

    logOperationalEvent(
      "transaction_metadata_suggestion_failed",
      { householdId, transactionId, jobId, error: message },
      "error",
    );
    return errorResponse(message, 400);
  }
});

async function checkBudget(
  userClient: ReturnType<typeof createServiceClient>,
  householdId: string,
): Promise<BudgetStatus> {
  const { data, error } = await userClient.rpc("check_ai_budget", {
    p_household_id: householdId,
    p_feature: transactionMetadataSuggestionFeature,
    p_estimated_cost_usd: estimatedPreflightCostUsd(),
  });
  if (error) throw error;
  const row = Array.isArray(data) ? data[0] : data;
  if (!row) {
    throw new Error("AI budget status was not returned.");
  }
  return row as BudgetStatus;
}

async function fetchSuggestionContext(
  userClient: ReturnType<typeof createServiceClient>,
  householdId: string,
  transactionId: string,
  reviewItemId: string | null,
): Promise<SuggestionContext> {
  const { data: transaction, error: transactionError } = await userClient
    .from("transactions")
    .select(
      "id, household_id, transaction_date, statement_merchant, normalized_statement_merchant, merchant_id, category_id, subcategory_id, source_type, transaction_type, amount, gross_spend, refund_amount, net_expense, currency_code, confidence, notes, cardholder_name",
    )
    .eq("household_id", householdId)
    .eq("id", transactionId)
    .maybeSingle();
  if (transactionError) throw transactionError;
  if (!transaction) {
    throw new Error("Transaction not found.");
  }

  const reviewItem = reviewItemId
    ? await fetchReviewItem(
      userClient,
      householdId,
      transactionId,
      reviewItemId,
    )
    : null;
  const normalizedStatementMerchant = optionalString(
    transaction.normalized_statement_merchant,
  );
  const statementMerchant = String(transaction.statement_merchant ?? "");
  const merchantId = optionalString(transaction.merchant_id);

  const [
    categories,
    subcategories,
    merchant,
    sameStatementTransactions,
    merchantSummaries,
  ] = await Promise.all([
    userClient
      .from("categories")
      .select("id, name")
      .eq("household_id", householdId)
      .order("sort_order")
      .order("name"),
    userClient
      .from("subcategories")
      .select("id, category_id, name")
      .eq("household_id", householdId)
      .order("sort_order")
      .order("name"),
    merchantId
      ? userClient
        .from("merchants")
        .select("id, display_name")
        .eq("household_id", householdId)
        .eq("id", merchantId)
        .maybeSingle()
      : Promise.resolve({ data: null, error: null }),
    normalizedStatementMerchant
      ? userClient
        .from("transactions")
        .select(
          "transaction_date, statement_merchant, category_id, subcategory_id, transaction_type, net_expense, confidence, notes",
        )
        .eq("household_id", householdId)
        .eq("normalized_statement_merchant", normalizedStatementMerchant)
        .order("transaction_date", { ascending: false })
        .limit(10)
      : Promise.resolve({ data: [], error: null }),
    userClient
      .from("v_merchant_summary")
      .select(
        "merchant_name, category_id, category_name, subcategory_id, subcategory_name, transaction_count, first_transaction_date, last_transaction_date, net_spend, refund_amount",
      )
      .eq("household_id", householdId)
      .ilike("merchant_name", `%${statementMerchant}%`)
      .limit(10),
  ]);

  for (
    const result of [
      categories,
      subcategories,
      merchant,
      sameStatementTransactions,
      merchantSummaries,
    ]
  ) {
    if (result.error) throw result.error;
  }

  const categoryRows = categories.data ?? [];
  const subcategoryRows = subcategories.data ?? [];
  const taxonomy = buildTaxonomy(categoryRows, subcategoryRows);
  if (taxonomy.length === 0) {
    throw new Error("No household categories are available for suggestions.");
  }
  if (!taxonomy.some((category) => category.subcategories.length > 0)) {
    throw new Error(
      "No household subcategories are available for suggestions.",
    );
  }

  const categoryNameById = new Map(
    categoryRows.map((row) => [String(row.id), String(row.name)]),
  );
  const subcategoryNameById = new Map(
    subcategoryRows.map((row) => [String(row.id), String(row.name)]),
  );
  const currentCategoryId = optionalString(transaction.category_id);
  const currentSubcategoryId = optionalString(transaction.subcategory_id);
  const currentMerchantName = optionalString(merchant.data?.display_name) ??
    statementMerchant;

  return {
    transactionFacts: {
      transaction_id: transaction.id,
      transaction_date: transaction.transaction_date,
      statement_merchant: transaction.statement_merchant,
      normalized_statement_merchant: transaction.normalized_statement_merchant,
      source_type: transaction.source_type,
      transaction_type: transaction.transaction_type,
      amount: transaction.amount,
      gross_spend: transaction.gross_spend,
      refund_amount: transaction.refund_amount,
      net_expense: transaction.net_expense,
      currency_code: transaction.currency_code,
      cardholder_name: transaction.cardholder_name,
    },
    currentEditorValues: {
      merchant_group: currentMerchantName,
      category_id: currentCategoryId,
      category_name: currentCategoryId
        ? categoryNameById.get(currentCategoryId) ?? null
        : null,
      subcategory_id: currentSubcategoryId,
      subcategory_name: currentSubcategoryId
        ? subcategoryNameById.get(currentSubcategoryId) ?? null
        : null,
      confidence: transaction.confidence,
      notes: transaction.notes,
    },
    reviewItem,
    taxonomy,
    nearbyMerchantContext: {
      same_statement_merchant_transactions:
        (sameStatementTransactions.data ?? []).map((row) => ({
          transaction_date: row.transaction_date,
          statement_merchant: row.statement_merchant,
          category_id: row.category_id,
          category_name: row.category_id
            ? categoryNameById.get(String(row.category_id)) ?? null
            : null,
          subcategory_id: row.subcategory_id,
          subcategory_name: row.subcategory_id
            ? subcategoryNameById.get(String(row.subcategory_id)) ?? null
            : null,
          transaction_type: row.transaction_type,
          net_expense: row.net_expense,
          confidence: row.confidence,
          notes: row.notes,
        })),
      related_merchant_summaries: merchantSummaries.data ?? [],
    },
  };
}

async function fetchReviewItem(
  userClient: ReturnType<typeof createServiceClient>,
  householdId: string,
  transactionId: string,
  reviewItemId: string,
): Promise<Record<string, unknown>> {
  const { data, error } = await userClient
    .from("v_review_queue")
    .select(
      "id, transaction_id, reason, created_at, transaction_confidence, current_merchant_name, current_category_name, current_subcategory_name, suggested_merchant_name, suggested_category_name, suggested_subcategory_name",
    )
    .eq("household_id", householdId)
    .eq("id", reviewItemId)
    .maybeSingle();
  if (error) throw error;
  if (!data) {
    throw new Error("Open review item not found for this transaction.");
  }
  if (data.transaction_id !== transactionId) {
    throw new Error("Review item does not belong to this transaction.");
  }

  return data;
}

function buildTaxonomy(
  categories: Array<Record<string, unknown>>,
  subcategories: Array<Record<string, unknown>>,
): TransactionMetadataTaxonomyCategory[] {
  return categories.map((category) => {
    const categoryId = String(category.id);
    return {
      id: categoryId,
      name: String(category.name),
      subcategories: subcategories
        .filter((subcategory) => subcategory.category_id === categoryId)
        .map((subcategory) => ({
          id: String(subcategory.id),
          name: String(subcategory.name),
        })),
    };
  });
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
