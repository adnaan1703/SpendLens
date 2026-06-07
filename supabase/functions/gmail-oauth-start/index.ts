import { randomState, sha256Hex } from "../_shared/crypto.ts";
import { buildGoogleOAuthUrl, gmailReadonlyScope } from "../_shared/google.ts";
import {
  errorResponse,
  handleOptions,
  jsonResponse,
  readJsonBody,
} from "../_shared/http.ts";
import { createServiceClient, requireUser } from "../_shared/supabase.ts";

Deno.serve(async (req: Request) => {
  const options = handleOptions(req);
  if (options) return options;

  try {
    const { userClient, user } = await requireUser(req);
    const body = await readJsonBody(req);
    const householdId = String(body.household_id ?? body.householdId ?? "")
      .trim();

    if (!householdId) {
      return errorResponse("household_id is required.", 400);
    }

    const { data: profile, error: profileError } = await userClient
      .from("profiles")
      .select("id")
      .eq("auth_user_id", user.id)
      .maybeSingle();

    if (profileError || !profile) {
      return errorResponse("Signed-in profile not found.", 403);
    }

    const { data: household, error: householdError } = await userClient
      .from("households")
      .select("id")
      .eq("id", householdId)
      .maybeSingle();

    if (householdError || !household) {
      return errorResponse(
        "Household is not accessible to the signed-in user.",
        403,
      );
    }

    const state = randomState();
    const stateHash = await sha256Hex(state);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    const serviceClient = createServiceClient();
    const { error: insertError } = await serviceClient.from(
      "gmail_oauth_states",
    ).insert({
      household_id: householdId,
      profile_id: profile.id,
      state_hash: stateHash,
      expires_at: expiresAt,
    });

    if (insertError) {
      throw insertError;
    }

    return jsonResponse({
      authorizationUrl: buildGoogleOAuthUrl(state),
      expiresAt,
      scope: gmailReadonlyScope,
    });
  } catch (error) {
    return errorResponse(
      error instanceof Error ? error.message : "Unable to start Gmail OAuth.",
      400,
    );
  }
});
