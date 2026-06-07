import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.107.0";

// deno-lint-ignore no-explicit-any -- replace with generated Supabase DB types.
type LooseDatabase = any;

export type SupabaseClientLike = SupabaseClient<LooseDatabase>;

function parseKeyMap(value: string | undefined): Record<string, string> | null {
  if (!value) {
    return null;
  }

  try {
    const parsed = JSON.parse(value);
    if (parsed && typeof parsed === "object") {
      return parsed as Record<string, string>;
    }
  } catch {
    return null;
  }

  return null;
}

export function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export function getPublishableKey(): string {
  const mapped = parseKeyMap(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS"));
  return mapped?.default ??
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
    Deno.env.get("SUPABASE_ANON_KEY") ??
    requiredEnv("SUPABASE_PUBLISHABLE_KEY");
}

export function getSecretKey(): string {
  const mapped = parseKeyMap(Deno.env.get("SUPABASE_SECRET_KEYS"));
  return mapped?.default ??
    Deno.env.get("SUPABASE_SECRET_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    requiredEnv("SUPABASE_SECRET_KEY");
}

export function createUserClient(req: Request): SupabaseClientLike {
  return createClient<LooseDatabase>(
    requiredEnv("SUPABASE_URL"),
    getPublishableKey(),
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
      global: {
        headers: {
          Authorization: req.headers.get("Authorization") ?? "",
        },
      },
    },
  );
}

export function createServiceClient(): SupabaseClientLike {
  return createClient<LooseDatabase>(
    requiredEnv("SUPABASE_URL"),
    getSecretKey(),
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );
}

export async function requireUser(req: Request): Promise<{
  userClient: SupabaseClientLike;
  user: { id: string; email?: string };
}> {
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    throw new Error("A signed-in user is required.");
  }

  const userClient = createUserClient(req);
  const { data, error } = await userClient.auth.getUser(token);
  if (error || !data.user) {
    throw new Error("Invalid or expired user session.");
  }

  return {
    userClient,
    user: { id: data.user.id, email: data.user.email ?? undefined },
  };
}

export function requireServiceRequest(req: Request): void {
  const expected = getSecretKey();
  const authorization = req.headers.get("Authorization") ?? "";
  const bearer = authorization.replace(/^Bearer\s+/i, "").trim();
  const apiKey = req.headers.get("apikey") ?? "";

  if (bearer !== expected && apiKey !== expected) {
    throw new Error("A Supabase secret key is required for this function.");
  }
}
