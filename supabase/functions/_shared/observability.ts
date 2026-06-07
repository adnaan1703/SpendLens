type LogLevel = "info" | "warn" | "error";

type LogDetails = Record<string, unknown>;

export function errorMessage(error: unknown, fallback: string): string {
  return error instanceof Error ? error.message : fallback;
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
