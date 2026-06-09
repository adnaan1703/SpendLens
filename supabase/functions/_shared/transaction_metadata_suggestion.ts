export type TransactionMetadataSuggestionConfidence = "high" | "medium" | "low";

export type TransactionMetadataSuggestion = {
  merchantGroup: string;
  categoryId: string;
  subcategoryId: string;
  confidence: TransactionMetadataSuggestionConfidence;
  notes: string;
};

export type TransactionMetadataTaxonomyCategory = {
  id: string;
  name: string;
  subcategories: Array<{
    id: string;
    name: string;
  }>;
};

export type TransactionMetadataSuggestionPromptContext = {
  transactionFacts: Record<string, unknown>;
  currentEditorValues: Record<string, unknown>;
  reviewItem: Record<string, unknown> | null;
  taxonomy: TransactionMetadataTaxonomyCategory[];
  nearbyMerchantContext: Record<string, unknown>;
};

export const transactionMetadataSuggestionFeature =
  "transaction_metadata_suggestion";

export const transactionMetadataSuggestionSystemInstruction = [
  "Classify one SpendLens transaction using only the supplied household context.",
  "Return JSON only.",
  "Do not invent categories or subcategories.",
  "Use only category_id and subcategory_id values from the allowed taxonomy.",
  "Every output field must have a value.",
  "Use low confidence when unsure.",
  "Do not apply changes.",
].join(" ");

export const transactionMetadataSuggestionSchema: Record<string, unknown> = {
  type: "object",
  properties: {
    merchant_group: {
      type: "string",
      description: "Non-empty merchant group label for the editor.",
    },
    category_id: {
      type: "string",
      description: "ID of one allowed household category.",
    },
    subcategory_id: {
      type: "string",
      description:
        "ID of one allowed household subcategory that belongs to category_id.",
    },
    confidence: {
      type: "string",
      enum: ["high", "medium", "low"],
      description: "Confidence in the suggested classification.",
    },
    notes: {
      type: "string",
      description: "Short note explaining why this suggestion fits.",
    },
  },
  required: [
    "merchant_group",
    "category_id",
    "subcategory_id",
    "confidence",
    "notes",
  ],
};

export function buildTransactionMetadataSuggestionPrompt(
  context: TransactionMetadataSuggestionPromptContext,
): string {
  return JSON.stringify({
    transaction_facts: context.transactionFacts,
    current_editor_values: context.currentEditorValues,
    review_item: context.reviewItem,
    allowed_confidence_values: ["high", "medium", "low"],
    allowed_categories: context.taxonomy,
    nearby_same_household_merchant_context: context.nearbyMerchantContext,
    required_json_shape: {
      merchant_group: "non-empty string",
      category_id: "one allowed category id",
      subcategory_id: "one allowed subcategory id under category_id",
      confidence: "high | medium | low",
      notes: "string",
    },
  });
}

export function parseTransactionMetadataSuggestion(
  text: string,
  taxonomy: TransactionMetadataTaxonomyCategory[],
): TransactionMetadataSuggestion {
  const parsed = JSON.parse(text) as Record<string, unknown>;
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Gemini suggestion must be a JSON object.");
  }

  const merchantGroup = requiredTrimmedString(
    parsed.merchant_group,
    "Merchant group",
  );
  const categoryId = requiredTrimmedString(parsed.category_id, "Category");
  const subcategoryId = requiredTrimmedString(
    parsed.subcategory_id,
    "Subcategory",
  );
  const confidence = confidenceValue(parsed.confidence);
  const notes = stringValue(parsed.notes, "Notes").trim();

  const category = taxonomy.find((item) => item.id === categoryId);
  if (!category) {
    throw new Error("Gemini suggested an unknown category.");
  }

  const subcategory = category.subcategories.find((item) =>
    item.id === subcategoryId
  );
  if (!subcategory) {
    throw new Error(
      "Gemini suggested a subcategory outside the selected category.",
    );
  }

  return {
    merchantGroup,
    categoryId,
    subcategoryId,
    confidence,
    notes,
  };
}

function confidenceValue(
  value: unknown,
): TransactionMetadataSuggestionConfidence {
  if (value === "high" || value === "medium" || value === "low") {
    return value;
  }

  throw new Error("Gemini suggested an invalid confidence value.");
}

function requiredTrimmedString(value: unknown, label: string): string {
  const trimmed = stringValue(value, label).trim();
  if (!trimmed) {
    throw new Error(`${label} is required in the Gemini suggestion.`);
  }

  return trimmed;
}

function stringValue(value: unknown, label: string): string {
  if (typeof value !== "string") {
    throw new Error(`${label} must be a string in the Gemini suggestion.`);
  }

  return value;
}
