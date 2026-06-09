import { buildGeminiGenerateRequest } from "../_shared/gemini.ts";
import {
  buildTransactionMetadataSuggestionPrompt,
  parseTransactionMetadataSuggestion,
  transactionMetadataSuggestionSchema,
  transactionMetadataSuggestionSystemInstruction,
  type TransactionMetadataTaxonomyCategory,
} from "../_shared/transaction_metadata_suggestion.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

function assertThrows(fn: () => unknown, expectedMessage: string): void {
  try {
    fn();
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    assert(
      message.includes(expectedMessage),
      `Expected "${message}" to include "${expectedMessage}".`,
    );
    return;
  }

  throw new Error("Expected function to throw.");
}

const taxonomy: TransactionMetadataTaxonomyCategory[] = [
  {
    id: "cat-shopping",
    name: "Shopping",
    subcategories: [{ id: "sub-marketplace", name: "Marketplace" }],
  },
  {
    id: "cat-food",
    name: "Food",
    subcategories: [{ id: "sub-delivery", name: "Delivery" }],
  },
];

Deno.test("transaction metadata suggestion request includes structured schema fields", () => {
  const request = buildGeminiGenerateRequest({
    systemInstruction: transactionMetadataSuggestionSystemInstruction,
    prompt: "prompt",
    responseMimeType: "application/json",
    responseJsonSchema: transactionMetadataSuggestionSchema,
  });
  const generationConfig = request.generationConfig as Record<
    string,
    unknown
  >;
  const schema = generationConfig.responseJsonSchema as Record<
    string,
    unknown
  >;
  const required = schema.required as string[];

  assert(
    generationConfig.responseMimeType === "application/json",
    "Suggestion request must ask Gemini for JSON.",
  );
  for (
    const field of [
      "merchant_group",
      "category_id",
      "subcategory_id",
      "confidence",
      "notes",
    ]
  ) {
    assert(required.includes(field), `${field} must be required.`);
  }
});

Deno.test("transaction metadata suggestion prompt includes editor and taxonomy context", () => {
  const prompt = buildTransactionMetadataSuggestionPrompt({
    transactionFacts: {
      transaction_id: "txn-1",
      statement_merchant: "AMZN MKTP IN",
      net_expense: 2499,
    },
    currentEditorValues: {
      merchant_group: "Unknown Amazon",
      category_id: "cat-shopping",
    },
    reviewItem: { id: "review-1", reason: "Unknown merchant" },
    taxonomy,
    nearbyMerchantContext: {
      same_statement_merchant_transactions: [],
      related_merchant_summaries: [],
    },
  });
  const parsed = JSON.parse(prompt) as Record<string, unknown>;

  assert(
    Array.isArray(parsed.allowed_categories),
    "Allowed categories must be included.",
  );
  assert(
    parsed.current_editor_values !== null,
    "Current editor values must be included.",
  );
  assert(
    parsed.nearby_same_household_merchant_context !== null,
    "Nearby merchant context must be included.",
  );
});

Deno.test("transaction metadata suggestion validates existing taxonomy ids", () => {
  const suggestion = parseTransactionMetadataSuggestion(
    JSON.stringify({
      merchant_group: "Amazon Shopping",
      category_id: "cat-shopping",
      subcategory_id: "sub-marketplace",
      confidence: "medium",
      notes: "Marketplace spend pattern.",
    }),
    taxonomy,
  );

  assert(
    suggestion.merchantGroup === "Amazon Shopping",
    "Merchant group was not parsed.",
  );
  assert(
    suggestion.categoryId === "cat-shopping",
    "Category id was not parsed.",
  );
  assert(
    suggestion.subcategoryId === "sub-marketplace",
    "Subcategory id was not parsed.",
  );
});

Deno.test("transaction metadata suggestion rejects invalid taxonomy ids", () => {
  assertThrows(
    () =>
      parseTransactionMetadataSuggestion(
        JSON.stringify({
          merchant_group: "Amazon Shopping",
          category_id: "cat-missing",
          subcategory_id: "sub-marketplace",
          confidence: "medium",
          notes: "Marketplace spend pattern.",
        }),
        taxonomy,
      ),
    "unknown category",
  );

  assertThrows(
    () =>
      parseTransactionMetadataSuggestion(
        JSON.stringify({
          merchant_group: "Amazon Shopping",
          category_id: "cat-food",
          subcategory_id: "sub-marketplace",
          confidence: "medium",
          notes: "Marketplace spend pattern.",
        }),
        taxonomy,
      ),
    "outside the selected category",
  );
});

Deno.test("transaction metadata suggestion rejects invalid confidence", () => {
  assertThrows(
    () =>
      parseTransactionMetadataSuggestion(
        JSON.stringify({
          merchant_group: "Amazon Shopping",
          category_id: "cat-shopping",
          subcategory_id: "sub-marketplace",
          confidence: "certain",
          notes: "Marketplace spend pattern.",
        }),
        taxonomy,
      ),
    "invalid confidence",
  );
});
