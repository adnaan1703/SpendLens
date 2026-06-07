export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-spendlens-pubsub-secret",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

export function handleOptions(req: Request): Response | null {
  if (req.method !== "OPTIONS") {
    return null;
  }

  return new Response("ok", { headers: corsHeaders });
}

export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

export function errorResponse(message: string, status = 400): Response {
  return jsonResponse({ error: message }, status);
}

export async function readJsonBody(
  req: Request,
): Promise<Record<string, unknown>> {
  if (req.method === "GET") {
    return {};
  }

  const text = await req.text();
  if (text.trim() === "") {
    return {};
  }

  const parsed = JSON.parse(text);
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Request body must be a JSON object.");
  }

  return parsed as Record<string, unknown>;
}

export function htmlResponse(body: string, status = 200): Response {
  return new Response(body, {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "text/html; charset=utf-8",
    },
  });
}
