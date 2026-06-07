import {
  errorResponse,
  handleOptions,
  jsonResponse,
  readJsonBody,
} from "../_shared/http.ts";
import { errorMessage, logOperationalEvent } from "../_shared/observability.ts";
import { requireUser } from "../_shared/supabase.ts";

Deno.serve(async (req: Request) => {
  const options = handleOptions(req);
  if (options) return options;

  try {
    const { userClient } = await requireUser(req);
    const body = await readJsonBody(req);
    const url = new URL(req.url);
    const householdId = String(
      body.household_id ?? body.householdId ??
        url.searchParams.get("household_id") ?? "",
    ).trim();

    let query = userClient
      .from("v_linked_mailbox_status")
      .select("*")
      .order("created_at", { ascending: false });

    if (householdId) {
      query = query.eq("household_id", householdId);
    }

    const { data, error } = await query;
    if (error) {
      throw error;
    }

    return jsonResponse({ mailboxes: data ?? [] });
  } catch (error) {
    logOperationalEvent(
      "gmail_connector_status_failed",
      { error: errorMessage(error, "Unable to load connector status.") },
      "error",
    );
    return errorResponse(
      errorMessage(error, "Unable to load connector status."),
      400,
    );
  }
});
