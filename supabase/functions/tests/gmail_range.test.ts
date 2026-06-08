import {
  addDays,
  buildDateSlices,
  isDateWithinRange,
} from "../_shared/gmail_range.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

Deno.test("buildDateSlices creates deterministic exclusive date slices", () => {
  const slices = buildDateSlices("2026-05-01", "2026-05-06", 2);

  assert(slices.length === 3, `Unexpected slice count: ${slices.length}`);
  assert(
    JSON.stringify(slices) ===
      JSON.stringify([
        { startDate: "2026-05-01", endDateExclusive: "2026-05-03" },
        { startDate: "2026-05-03", endDateExclusive: "2026-05-05" },
        { startDate: "2026-05-05", endDateExclusive: "2026-05-06" },
      ]),
    "Unexpected slice boundaries.",
  );
});

Deno.test("addDays handles month boundaries in UTC", () => {
  assert(addDays("2026-05-01", -1) === "2026-04-30", "Previous day failed.");
  assert(addDays("2026-05-31", 1) === "2026-06-01", "Next day failed.");
});

Deno.test("isDateWithinRange uses inclusive start and exclusive end", () => {
  assert(
    isDateWithinRange("2026-05-01", "2026-05-01", "2026-06-01"),
    "Start date should be included.",
  );
  assert(
    isDateWithinRange("2026-05-31", "2026-05-01", "2026-06-01"),
    "Date before the exclusive end should be included.",
  );
  assert(
    !isDateWithinRange("2026-06-01", "2026-05-01", "2026-06-01"),
    "Exclusive end date should not be included.",
  );
});
