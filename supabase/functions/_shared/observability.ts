type LogLevel = "info" | "warn" | "error";

type LogDetails = Record<string, unknown>;

function fieldValue(error: Record<string, unknown>, key: string): string | null {
  const value = error[key];
  if (
    typeof value === "string" || typeof value === "number" ||
    typeof value === "boolean"
  ) {
    const formatted = String(value).trim();
    return formatted ? `${key}: ${formatted}` : null;
  }

  return null;
}

export function errorMessage(error: unknown, fallback: string): string {
  if (error instanceof Error) {
    return error.message;
  }

  if (typeof error === "string") {
    return error.trim() || fallback;
  }

  if (error && typeof error === "object") {
    const fields = [
      "message",
      "code",
      "details",
      "hint",
      "status",
      "statusCode",
      "error",
      "error_description",
    ];
    const parts = fields
      .map((field) => fieldValue(error as Record<string, unknown>, field))
      .filter((part): part is string => part !== null);

    if (parts.length > 0) {
      return parts.join(" | ");
    }
  }

  return fallback;
}

export function logOperationalEvent(
  event: string,
  details: LogDetails = {},
  level: LogLevel = "info",
): void {
  const payload = {
    event,
    level,
    at: new Date().toISOString(),
    ...details,
  };

  const line = JSON.stringify(payload);
  if (level === "error") {
    console.error(line);
  } else if (level === "warn") {
    console.warn(line);
  } else {
    console.log(line);
  }
}
