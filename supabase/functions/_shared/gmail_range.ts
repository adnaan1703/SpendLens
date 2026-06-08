const isoDatePattern = /^\d{4}-\d{2}-\d{2}$/;

export type DateSlice = {
  startDate: string;
  endDateExclusive: string;
};

export function assertIsoDate(value: unknown, label: string): string {
  if (typeof value !== "string" || !isoDatePattern.test(value)) {
    throw new Error(`${label} must be an ISO date in YYYY-MM-DD format.`);
  }

  const parsed = new Date(`${value}T00:00:00.000Z`);
  if (
    Number.isNaN(parsed.valueOf()) ||
    parsed.toISOString().slice(0, 10) !== value
  ) {
    throw new Error(`${label} must be a valid calendar date.`);
  }

  return value;
}

export function optionalIsoDate(value: unknown, label: string): string | null {
  if (value === undefined || value === null || value === "") {
    return null;
  }

  return assertIsoDate(value, label);
}

export function parseBoundedInteger(
  value: unknown,
  label: string,
  options: { defaultValue: number; min: number; max: number },
): number {
  const candidate = value === undefined || value === null || value === ""
    ? options.defaultValue
    : Number(value);

  if (!Number.isInteger(candidate)) {
    throw new Error(`${label} must be an integer.`);
  }

  if (candidate < options.min || candidate > options.max) {
    throw new Error(
      `${label} must be between ${options.min} and ${options.max}.`,
    );
  }

  return candidate;
}

export function compareIsoDates(left: string, right: string): number {
  return left.localeCompare(right);
}

export function addDays(date: string, days: number): string {
  const parsed = new Date(`${assertIsoDate(date, "date")}T00:00:00.000Z`);
  parsed.setUTCDate(parsed.getUTCDate() + days);
  return parsed.toISOString().slice(0, 10);
}

export function buildDateSlices(
  startDate: string,
  endDateExclusive: string,
  sliceDays: number,
): DateSlice[] {
  const start = assertIsoDate(startDate, "transactionStartDate");
  const end = assertIsoDate(
    endDateExclusive,
    "transactionEndDateExclusive",
  );

  if (compareIsoDates(start, end) >= 0) {
    throw new Error(
      "transactionStartDate must be before transactionEndDateExclusive.",
    );
  }

  const slices: DateSlice[] = [];
  let cursor = start;
  while (compareIsoDates(cursor, end) < 0) {
    const candidateEnd = addDays(cursor, sliceDays);
    const sliceEnd = compareIsoDates(candidateEnd, end) > 0
      ? end
      : candidateEnd;
    slices.push({ startDate: cursor, endDateExclusive: sliceEnd });
    cursor = sliceEnd;
  }

  return slices;
}

export function isDateWithinRange(
  date: unknown,
  startDate: string | null,
  endDateExclusive: string | null,
): boolean {
  const parsedDate = optionalIsoDate(date, "transaction_date");
  if (!parsedDate) {
    return false;
  }

  if (startDate && compareIsoDates(parsedDate, startDate) < 0) {
    return false;
  }

  if (endDateExclusive && compareIsoDates(parsedDate, endDateExclusive) >= 0) {
    return false;
  }

  return true;
}
