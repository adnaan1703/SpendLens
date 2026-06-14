import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/finance_repository.dart';
import '../../shared/widgets/app_primitives.dart';

void refreshCategoryLookups(WidgetRef ref, String householdId) {
  ref.invalidate(transactionCategoriesProvider(householdId));
  ref.invalidate(merchantSubcategoriesProvider(householdId));
  ref.invalidate(categoryManagerSnapshotProvider(householdId));
  ref.invalidate(categoryUsagePreviewProvider);
  ref.invalidate(availableMonthsProvider(householdId));
  ref.invalidate(
    dashboardSnapshotProvider(FinanceMonthRequest(householdId: householdId)),
  );
  ref.invalidate(dashboardSnapshotProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(trendReportProvider);
  ref.invalidate(merchantReviewQueueProvider(householdId));
}

Future<CategoryCreationResult?> showCategoryCreationDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String householdId,
}) {
  final formKey = GlobalKey<FormState>();
  var categoryName = '';
  var subcategoryName = '';

  return showDialog<CategoryCreationResult>(
    context: context,
    builder: (dialogContext) {
      var isSaving = false;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AppModalDialog(
            title: 'Create category',
            maxWidth: 468,
            actions: [
              AppActionPill.secondary(
                label: 'Cancel',
                onPressed: isSaving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
              ),
              AppActionPill.primary(
                label: 'Create',
                icon: Icons.add,
                isLoading: isSaving,
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        await _saveCategory(
                          dialogContext: dialogContext,
                          ref: ref,
                          householdId: householdId,
                          categoryName: categoryName,
                          subcategoryName: subcategoryName,
                          setDialogState: setDialogState,
                          setSaving: (value) {
                            isSaving = value;
                          },
                        );
                      },
              ),
            ],
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Category name',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    onChanged: (value) {
                      categoryName = value;
                    },
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Category name is required';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Subcategory name',
                      prefixIcon: Icon(Icons.sell_outlined),
                    ),
                    onChanged: (value) {
                      subcategoryName = value;
                    },
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Subcategory name is required';
                      }

                      return null;
                    },
                    onFieldSubmitted: (_) async {
                      if (isSaving || !formKey.currentState!.validate()) {
                        return;
                      }

                      await _saveCategory(
                        dialogContext: dialogContext,
                        ref: ref,
                        householdId: householdId,
                        categoryName: categoryName,
                        subcategoryName: subcategoryName,
                        setDialogState: setDialogState,
                        setSaving: (value) {
                          isSaving = value;
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _saveCategory({
  required BuildContext dialogContext,
  required WidgetRef ref,
  required String householdId,
  required String categoryName,
  required String subcategoryName,
  required StateSetter setDialogState,
  required ValueChanged<bool> setSaving,
}) async {
  setDialogState(() {
    setSaving(true);
  });

  try {
    final result = await ref
        .read(financeRepositoryProvider)
        .createCategory(
          CategoryCreationRequest(
            householdId: householdId,
            categoryName: categoryName.trim(),
            subcategoryName: subcategoryName.trim(),
          ),
        );

    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop(result);
    }
  } catch (error) {
    setDialogState(() {
      setSaving(false);
    });

    if (dialogContext.mounted) {
      ScaffoldMessenger.of(
        dialogContext,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}
