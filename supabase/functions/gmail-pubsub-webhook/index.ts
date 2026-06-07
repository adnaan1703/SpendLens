import { base64UrlDecode } from "../_shared/crypto.ts";
import { errorResponse, handleOptions, jsonResponse } from "../_shared/http.ts";
import { createServiceClient } from "../_shared/supabase.ts";

function verifyPubSubSecret(req: Request): void {
  const expected = Deno.env.get("PUBSUB_VERIFICATION_SECRET");
  if (!expected) {
    return;
  }

  const url = new URL(req.url);
  const provided = req.headers.get("x-spendlens-pubsub-secret") ??
    url.searchParams.get("token") ??
    "";

  if (provided !== expected) {
    throw new Error("Invalid Pub/Sub verification secret.");
  }
}

Deno.serve(async (req: Request) => {
  const options = handleOptions(req);
  if (options) return options;

  try {
    verifyPubSubSecret(req);

    const body = await req.json();
    const message = body?.message;
    const data = message?.data;
    if (!message || typeof data !== "string") {
      return errorResponse("Invalid Pub/Sub message shape.", 400);
    }

    const decoded = JSON.parse(base64UrlDecode(data));
    const emailAddress = decoded.emailAddress;
    const historyId = decoded.historyId;

    if (!emailAddress || !historyId) {
      return errorResponse(
        "Gmail Pub/Sub payload is missing emailAddress or historyId.",
        400,
      );
    }

    const serviceClient = createServiceClient();
    const { data: result, error } = await serviceClient.rpc(
      "enqueue_gmail_sync_from_notification",
      {
        p_email: emailAddress,
        p_history_id: String(historyId),
        p_pubsub_message_id: String(
          message.messageId ?? message.message_id ?? "",
        ),
        p_subscription: String(body.subscription ?? ""),
      },
    );

    if (error) {
      throw error;
    }

    return jsonResponse({ ok: true, result });
  } catch (error) {
    return errorResponse(
      error instanceof Error
        ? error.message
        : "Unable to handle Pub/Sub notification.",
      400,
    );
  }
});
