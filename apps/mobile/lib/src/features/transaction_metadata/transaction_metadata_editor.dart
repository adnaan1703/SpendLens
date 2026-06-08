import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/finance_repository.dart';
import '../categories/category_creation_dialog.dart';

final class TransactionMetadataEditorInitialValue {
  const TransactionMetadataEditorInitialValue({
    required this.householdId,
    required this.transactionId,
    required this.statementMerchant,
    required this.merchantGroup,
    required this.categoryId,
    required this.subcategoryId,
    required this.confidence,
    this.reviewItemId,
    this.notes,
  });

  final String householdId;
  final String transactionId;
  final String statementMerchant;
  final String merchantGroup;
  final String? categoryId;
  final String? subcategoryId;
  final String confidence;
  final String? reviewItemId;
  final String? notes;
}

Future<TransactionMetadataCorrectionResult?> showTransactionMetadataEditor({
  required BuildContext context,
  required WidgetRef ref,
  required TransactionMetadataEditorInitialValue initialValue,
  required List<CategoryOption> categories,
  required List<SubcategoryOption> subcategories,
}) {
  final formKey = GlobalKey<FormState>();
  var merchantGroup = initialValue.merchantGroup;
  var notes = initialValue.notes ?? '';
  var confidence = _supportedConfidence(initialValue.confidence);
  var dialogCategories = [...categories];
  var dialogSubcategories = [...subcategories];
  var selectedCategoryId = initialValue.categoryId;
  if (selectedCategoryId != null &&
      !dialogCategories.any((category) => category.id == selectedCategoryId)) {
    selectedCategoryId = null;
  }
  selectedCategoryId ??= dialogCategories.firstOrNull?.id;

  var selectedSubcategoryId = initialValue.subcategoryId;
  if (selectedSubcategoryId != null &&
      !dialogSubcategories.any(
        (subcategory) =>
            subcategory.id == selectedSubcategoryId &&
            subcategory.categoryId == selectedCategoryId,
      )) {
    selectedSubcategoryId = null;
  }
  selectedSubcategoryId ??= dialogSubcategories
      .where((subcategory) => subcategory.categoryId == selectedCategoryId)
      .firstOrNull
      ?.id;

  return showDialog<TransactionMetadataCorrectionResult>(
    context: context,
    builder: (dialogContext) {
      var isSaving = false;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          final availableSubcategories = dialogSubcategories
              .where(
                (subcategory) => subcategory.categoryId == selectedCategoryId,
              )
              .toList(growable: false);

          return AlertDialog(
            title: const Text('Edit metadata'),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        initialValue: merchantGroup,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Merchant group',
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                        onChanged: (value) {
                          merchantGroup = value;
                        },
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Merchant group is required';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: [
                          for (final category in dialogCategories)
                            DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            ),
                        ],
                        validator: (value) {
                          if (value == null) return 'Category is required';

                          return null;
                        },
                        onChanged: isSaving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  selectedCategoryId = value;
                                  selectedSubcategoryId = dialogSubcategories
                                      .where(
                                        (subcategory) =>
                                            subcategory.categoryId == value,
                                      )
                                      .firstOrNull
                                      ?.id;
                                });
                              },
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final created =
                                      await showCategoryCreationDialog(
                                        context: dialogContext,
                                        ref: ref,
                                        householdId: initialValue.householdId,
                                      );
                                  if (created == null) return;

                                  refreshCategoryLookups(
                                    ref,
                                    initialValue.householdId,
                                  );

                                  setDialogState(() {
                                    if (!dialogCategories.any(
                                      (category) =>
                                          category.id == created.category.id,
                                    )) {
                                      dialogCategories =
                                          [
                                            ...dialogCategories,
                                            created.category,
                                          ]..sort(
                                            (a, b) => a.name.compareTo(b.name),
                                          );
                                    }
                                    if (!dialogSubcategories.any(
                                      (subcategory) =>
                                          subcategory.id ==
                                          created.subcategory.id,
                                    )) {
                                      dialogSubcategories =
                                          [
                                            ...dialogSubcategories,
                                            created.subcategory,
                                          ]..sort(
                                            (a, b) => a.name.compareTo(b.name),
                                          );
                                    }
                                    selectedCategoryId = created.category.id;
                                    selectedSubcategoryId =
                                        created.subcategory.id;
                                  });

                                  if (dialogContext.mounted) {
                                    ScaffoldMessenger.of(
                                      dialogContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Created ${created.category.name}',
                                        ),
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.add),
                          label: const Text('Create category'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(selectedCategoryId),
                        isExpanded: true,
                        initialValue: selectedSubcategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Subcategory',
                          prefixIcon: Icon(Icons.sell_outlined),
                        ),
                        items: [
                          for (final subcategory in availableSubcategories)
                            DropdownMenuItem(
                              value: subcategory.id,
                              child: Text(subcategory.name),
                            ),
                        ],
                        validator: (value) {
                          if (value == null) {
                            return 'Subcategory is required';
                          }

                          return null;
                        },
                        onChanged: isSaving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  selectedSubcategoryId = value;
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: confidence,
                        decoration: const InputDecoration(
                          labelText: 'Confidence',
                          prefixIcon: Icon(Icons.fact_check_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'manual',
                            child: Text('Manual'),
                          ),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                          DropdownMenuItem(
                            value: 'medium',
                            child: Text('Medium'),
                          ),
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                        ],
                        onChanged: isSaving
                            ? null
                            : (value) {
                                confidence = value ?? 'manual';
                              },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: notes,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                        onChanged: (value) {
                          notes = value;
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Applies to matching statement merchant and future imports.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        setDialogState(() {
                          isSaving = true;
                        });

                        try {
                          final correction = await ref
                              .read(financeRepositoryProvider)
                              .applyTransactionMetadataCorrection(
                                TransactionMetadataCorrectionRequest(
                                  householdId: initialValue.householdId,
                                  transactionId: initialValue.transactionId,
                                  reviewItemId: initialValue.reviewItemId,
                                  merchantGroup: merchantGroup.trim(),
                                  categoryId: selectedCategoryId!,
                                  subcategoryId: selectedSubcategoryId!,
                                  confidence: confidence,
                                  notes: notes.trim().isEmpty
                                      ? null
                                      : notes.trim(),
                                ),
                              );

                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(correction);
                          }
                        } catch (error) {
                          setDialogState(() {
                            isSaving = false;
                          });

                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        }
                      },
                icon: isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

String _supportedConfidence(String value) {
  const supported = {'manual', 'high', 'medium', 'low'};
  return supported.contains(value) ? value : 'manual';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;

    return null;
  }
}
