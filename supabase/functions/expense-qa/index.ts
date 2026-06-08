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
  household_id: string;
  provider: string;
  model: string;
  monthly_spend_cap_usd: number;
  current_month_spend_usd: number;
  remaining_monthly_budget_usd: number;
  free_tier_only: boolean;
};

const systemInstruction = [
  "You are SpendLens, a personal finance assistant.",
  "Answer only from the scoped household data supplied in the prompt.",
  "Use INR amounts and concise, factual language.",
  "If the provided data is insufficient, say what is missing.",
  "Do not infer data from other households, external sources, or raw emails.",
].join(" ");

Deno.serve(async (req: Request) => {
  const options = handleOptions(req);
  if (options) return options;

  let jobId: string | null = null;
  let householdId = "";
  let question = "";
  const serviceClient = createServiceClient();

  try {
    const { userClient, user } = await requireUser(req);
    const body = await readJsonBody(req);
    householdId = String(body.household_id ?? body.householdId ?? "").trim();
    question = String(body.question ?? "").trim();

    if (!householdId) {
      throw new Error("Household is required.");
    }
    if (question.length < 4) {
      throw new Error("Question is too short.");
    }
    if (question.length > 1000) {
      throw new Error("Question is too long.");
    }

    const budget = await checkBudget(userClient, householdId, "expense_qa");
    const scopedData = await fetchScopedExpenseContext(userClient, householdId);

    const { data: job, error: jobError } = await serviceClient
      .from("ai_jobs")
      .insert({
        household_id: householdId,
        profile_id: await profileIdForUser(serviceClient, user.id),
        job_type: "expense_qa",
        status: "processing",
        input: { question },
        provider: budget.provider,
        model: budget.model,
        started_at: new Date().toISOString(),
      })
      .select("id")
      .single();
    if (jobError) throw jobError;
    jobId = job.id as string;

    const prompt = JSON.stringify({
      question,
      household_id: householdId,
      finance_context: scopedData,
    });
    const response = await callGeminiText({
      apiKey: geminiApiKey(),
      model: budget.model,
      systemInstruction,
      prompt,
    });
    const estimatedCost = estimateGeminiCostUsd(
      response.usage,
      budget.free_tier_only,
    );
    const usageEventId = await recordUsage(serviceClient, {
      householdId,
      profileId: await profileIdForUser(serviceClient, user.id),
      feature: "expense_qa",
      provider: budget.provider,
      model: budget.model,
      inputTokens: response.usage.inputTokens,
      outputTokens: response.usage.outputTokens,
      estimatedCostUsd: estimatedCost,
      status: "completed",
      requestMetadata: { job_id: jobId, question_length: question.length },
      responseMetadata: response.responseMetadata,
    });

    await serviceClient
      .from("ai_jobs")
      .update({
        status: "completed",
        output: {
          answer: response.text,
          usage: response.usage,
          estimated_cost_usd: estimatedCost,
        },
        usage_event_id: usageEventId,
        completed_at: new Date().toISOString(),
      })
      .eq("id", jobId);

    logOperationalEvent("expense_qa_completed", {
      householdId,
      jobId,
      model: budget.model,
      estimatedCostUsd: estimatedCost,
    });

    return jsonResponse({
      answer: response.text,
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
    const message = errorMessage(error, "Unable to answer expense question.");
    if (jobId) {
      await serviceClient
        .from("ai_jobs")
        .update({
          status: "failed",
          error_message: message,
          completed_at: new Date().toISOString(),
        })
        .eq("id", jobId);
    }
    logOperationalEvent(
      "expense_qa_failed",
      { householdId, questionLength: question.length, error: message },
      "error",
    );
    return errorResponse(message, 400);
  }
});

async function checkBudget(
  userClient: ReturnType<typeof createServiceClient>,
  householdId: string,
  feature: string,
): Promise<BudgetStatus> {
  const { data, error } = await userClient.rpc("check_ai_budget", {
    p_household_id: householdId,
    p_feature: feature,
    p_estimated_cost_usd: estimatedPreflightCostUsd(),
  });
  if (error) throw error;
  const row = Array.isArray(data) ? data[0] : data;
  if (!row) {
    throw new Error("AI budget status was not returned.");
  }
  return row as BudgetStatus;
}

async function fetchScopedExpenseContext(
  userClient: ReturnType<typeof createServiceClient>,
  householdId: string,
): Promise<Record<string, unknown>> {
  const [monthly, categories, merchants, reviewQueue] = await Promise.all([
    userClient
      .from("v_monthly_spend")
      .select(
        "period_month, transaction_count, gross_spend, refund_amount, net_spend, bill_payments",
      )
      .eq("household_id", householdId)
      .order("period_month", { ascending: false })
      .limit(12),
    userClient
      .from("v_category_monthly_spend")
      .select(
        "period_month, category_name, transaction_count, gross_spend, refund_amount, net_spend",
      )
      .eq("household_id", householdId)
      .order("period_month", { ascending: false })
      .order("net_spend", { ascending: false })
      .limit(30),
    userClient
      .from("v_merchant_summary")
      .select(
        "merchant_name, category_name, subcategory_name, transaction_count, net_spend, refund_amount",
      )
      .eq("household_id", householdId)
      .order("net_spend", { ascending: false })
      .limit(20),
    userClient
      .from("v_review_queue")
      .select(
        "reason, transaction_date, statement_merchant, net_expense, transaction_confidence, current_category_name",
      )
      .eq("household_id", householdId)
      .order("created_at")
      .limit(10),
  ]);

  for (const result of [monthly, categories, merchants, reviewQueue]) {
    if (result.error) throw result.error;
  }

  return {
    monthly_spend: monthly.data ?? [],
    category_spend: categories.data ?? [],
    merchant_summary: merchants.data ?? [],
    review_queue: reviewQueue.data ?? [],
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
