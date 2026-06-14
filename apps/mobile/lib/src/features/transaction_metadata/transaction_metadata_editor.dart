import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/finance_repository.dart';
import '../../shared/widgets/app_primitives.dart';
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
      var isSuggesting = false;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          final isBusy = isSaving || isSuggesting;
          final theme = Theme.of(context);
          final availableSubcategories = dialogSubcategories
              .where(
                (subcategory) => subcategory.categoryId == selectedCategoryId,
              )
              .toList(growable: false);
          final dropdownRadius = BorderRadius.circular(12.0);
          final dropdownTextStyle = theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          );
          const dropdownMenuHeight = 320.0;

          return _MetadataEditorModal(
            form: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSuggesting) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    key: ValueKey('merchant-group-$merchantGroup'),
                    initialValue: merchantGroup,
                    enabled: !isBusy,
                    textInputAction: TextInputAction.next,
                    decoration: _metadataFieldDecoration(
                      context,
                      label: 'Merchant group',
                      icon: Icons.storefront_outlined,
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Merchant group is required';
                      }

                      return null;
                    },
                    onChanged: (value) {
                      merchantGroup = value;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey('category-$selectedCategoryId'),
                    isExpanded: true,
                    initialValue: selectedCategoryId,
                    dropdownColor: theme.colorScheme.surface,
                    borderRadius: dropdownRadius,
                    menuMaxHeight: dropdownMenuHeight,
                    style: dropdownTextStyle,
                    icon: const Icon(Icons.expand_more_rounded),
                    iconEnabledColor: theme.colorScheme.onSurfaceVariant,
                    decoration: _metadataFieldDecoration(
                      context,
                      label: 'Category',
                      icon: Icons.category_outlined,
                    ),
                    items: [
                      for (final category in dialogCategories)
                        DropdownMenuItem(
                          value: category.id,
                          child: Text(
                            category.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    validator: (value) {
                      if (value == null) return 'Category is required';

                      return null;
                    },
                    onChanged: isBusy
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TextButton.icon(
                      key: const ValueKey('metadata-create-category-button'),
                      onPressed: isBusy
                          ? null
                          : () async {
                              final created = await showCategoryCreationDialog(
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
                                  dialogCategories = [
                                    ...dialogCategories,
                                    created.category,
                                  ]..sort((a, b) => a.name.compareTo(b.name));
                                }
                                if (!dialogSubcategories.any(
                                  (subcategory) =>
                                      subcategory.id == created.subcategory.id,
                                )) {
                                  dialogSubcategories = [
                                    ...dialogSubcategories,
                                    created.subcategory,
                                  ]..sort((a, b) => a.name.compareTo(b.name));
                                }
                                selectedCategoryId = created.category.id;
                                selectedSubcategoryId = created.subcategory.id;
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
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Create category'),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'subcategory-$selectedCategoryId-$selectedSubcategoryId',
                    ),
                    isExpanded: true,
                    initialValue: selectedSubcategoryId,
                    dropdownColor: theme.colorScheme.surface,
                    borderRadius: dropdownRadius,
                    menuMaxHeight: dropdownMenuHeight,
                    style: dropdownTextStyle,
                    icon: const Icon(Icons.expand_more_rounded),
                    iconEnabledColor: theme.colorScheme.onSurfaceVariant,
                    decoration: _metadataFieldDecoration(
                      context,
                      label: 'Subcategory',
                      icon: Icons.sell_outlined,
                    ),
                    items: [
                      for (final subcategory in availableSubcategories)
                        DropdownMenuItem(
                          value: subcategory.id,
                          child: Text(
                            subcategory.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    validator: (value) {
                      if (value == null) {
                        return 'Subcategory is required';
                      }

                      return null;
                    },
                    onChanged: isBusy
                        ? null
                        : (value) {
                            setDialogState(() {
                              selectedSubcategoryId = value;
                            });
                          },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey('confidence-$confidence'),
                    initialValue: confidence,
                    dropdownColor: theme.colorScheme.surface,
                    borderRadius: dropdownRadius,
                    menuMaxHeight: dropdownMenuHeight,
                    style: dropdownTextStyle,
                    icon: const Icon(Icons.expand_more_rounded),
                    iconEnabledColor: theme.colorScheme.onSurfaceVariant,
                    decoration: _metadataFieldDecoration(
                      context,
                      label: 'Confidence',
                      icon: Icons.verified_outlined,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'manual', child: Text('Manual')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                    ],
                    onChanged: isBusy
                        ? null
                        : (value) {
                            confidence = value ?? 'manual';
                          },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: ValueKey('notes-$notes'),
                    initialValue: notes,
                    enabled: !isBusy,
                    minLines: 2,
                    maxLines: 4,
                    decoration: _metadataFieldDecoration(
                      context,
                      label: 'Notes',
                      icon: Icons.notes_outlined,
                      hint: 'Add notes...',
                    ),
                    onChanged: (value) {
                      notes = value;
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Applies to matching statement merchant and future imports.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            isSaving: isSaving,
            isSuggesting: isSuggesting,
            onCancel: isBusy ? null : () => Navigator.of(dialogContext).pop(),
            onSuggest: isBusy
                ? null
                : () async {
                    setDialogState(() {
                      isSuggesting = true;
                    });

                    try {
                      final suggestion = await ref
                          .read(financeRepositoryProvider)
                          .suggestTransactionMetadata(
                            TransactionMetadataSuggestionRequest(
                              householdId: initialValue.householdId,
                              transactionId: initialValue.transactionId,
                              reviewItemId: initialValue.reviewItemId,
                            ),
                          );
                      final hasCategory = dialogCategories.any(
                        (category) => category.id == suggestion.categoryId,
                      );
                      final hasSubcategory = dialogSubcategories.any(
                        (subcategory) =>
                            subcategory.id == suggestion.subcategoryId &&
                            subcategory.categoryId == suggestion.categoryId,
                      );
                      if (!hasCategory || !hasSubcategory) {
                        throw StateError(
                          'Suggestion returned a category that is not available in the editor.',
                        );
                      }

                      if (!dialogContext.mounted) return;
                      setDialogState(() {
                        merchantGroup = suggestion.merchantGroup;
                        notes = suggestion.notes;
                        selectedCategoryId = suggestion.categoryId;
                        selectedSubcategoryId = suggestion.subcategoryId;
                        confidence = _supportedConfidence(
                          suggestion.confidence,
                        );
                        isSuggesting = false;
                      });
                      ref.invalidate(
                        aiBudgetStatusProvider(initialValue.householdId),
                      );
                    } catch (error) {
                      if (!dialogContext.mounted) return;
                      setDialogState(() {
                        isSuggesting = false;
                      });
                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(SnackBar(content: Text(error.toString())));
                    }
                  },
            onSave: isBusy
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
                              notes: notes.trim().isEmpty ? null : notes.trim(),
                            ),
                          );

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(correction);
                      }
                    } catch (error) {
                      if (!dialogContext.mounted) return;
                      setDialogState(() {
                        isSaving = false;
                      });

                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(SnackBar(content: Text(error.toString())));
                    }
                  },
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

InputDecoration _metadataFieldDecoration(
  BuildContext context, {
  required String label,
  required IconData icon,
  String? hint,
}) {
  final theme = Theme.of(context);
  final radius = BorderRadius.circular(AppThemeTokens.inputRadius);
  final border = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: theme.colorScheme.onSurface, width: 1.4),
  );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: theme.cardColor,
    border: border,
    enabledBorder: border,
    disabledBorder: border.copyWith(
      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
    ),
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: AppThemeTokens.primary, width: 2),
    ),
    errorBorder: border.copyWith(
      borderSide: BorderSide(color: theme.colorScheme.error),
    ),
    focusedErrorBorder: border.copyWith(
      borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
    ),
  );
}

class _MetadataEditorModal extends StatelessWidget {
  const _MetadataEditorModal({
    required this.form,
    required this.isSaving,
    required this.isSuggesting,
    required this.onCancel,
    required this.onSuggest,
    required this.onSave,
  });

  final Widget form;
  final bool isSaving;
  final bool isSuggesting;
  final VoidCallback? onCancel;
  final VoidCallback? onSuggest;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = MediaQuery.sizeOf(context);
          final layoutWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : size.width;
          final layoutHeight = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : size.height;
          final horizontalInset = layoutWidth < 600 ? 16.0 : 48.0;
          final verticalInset = layoutHeight < 700 ? 12.0 : 48.0;
          final availableHeight =
              layoutHeight - mediaQuery.viewInsets.bottom - (verticalInset * 2);
          final maxHeight = availableHeight.clamp(0.0, layoutHeight);

          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalInset,
              verticalInset,
              horizontalInset,
              verticalInset + mediaQuery.viewInsets.bottom,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: maxHeight.toDouble(),
                ),
                child: AppContentCard(
                  key: const ValueKey('metadata-editor-card'),
                  padding: EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _MetadataEditorHeader(),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                          child: form,
                        ),
                      ),
                      _MetadataEditorActions(
                        isSaving: isSaving,
                        isSuggesting: isSuggesting,
                        onCancel: onCancel,
                        onSuggest: onSuggest,
                        onSave: onSave,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MetadataEditorHeader extends StatelessWidget {
  const _MetadataEditorHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Text(
          'Edit metadata',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _MetadataEditorActions extends StatelessWidget {
  const _MetadataEditorActions({
    required this.isSaving,
    required this.isSuggesting,
    required this.onCancel,
    required this.onSuggest,
    required this.onSave,
  });

  final bool isSaving;
  final bool isSuggesting;
  final VoidCallback? onCancel;
  final VoidCallback? onSuggest;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestButton = _MetadataPillButton.outlined(
      key: const ValueKey('metadata-suggest-button'),
      label: 'Suggest',
      icon: isSuggesting
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_awesome, color: AppThemeTokens.primary),
      onPressed: onSuggest,
    );
    final cancelButton = _MetadataPillButton.secondary(
      key: const ValueKey('metadata-cancel-button'),
      label: 'Cancel',
      onPressed: onCancel,
    );
    final saveButton = _MetadataPillButton.primary(
      key: const ValueKey('metadata-save-button'),
      label: 'Save',
      icon: isSaving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.check),
      onPressed: onSave,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 380) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  suggestButton,
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: cancelButton),
                      const SizedBox(width: 12),
                      Expanded(child: saveButton),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                suggestButton,
                const Spacer(),
                cancelButton,
                const SizedBox(width: 12),
                saveButton,
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _MetadataPillVariant { outlined, secondary, primary }

class _MetadataPillButton extends StatelessWidget {
  const _MetadataPillButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  }) : variant = _MetadataPillVariant.outlined;

  const _MetadataPillButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
  }) : icon = null,
       variant = _MetadataPillVariant.secondary;

  const _MetadataPillButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  }) : variant = _MetadataPillVariant.primary;

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final _MetadataPillVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = switch (variant) {
      _MetadataPillVariant.outlined => OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        side: BorderSide(color: theme.colorScheme.onSurface, width: 1.4),
        shape: const StadiumBorder(),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0),
      ),
      _MetadataPillVariant.secondary => FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        foregroundColor: theme.colorScheme.onSurface,
        disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
        disabledForegroundColor: theme.colorScheme.outline,
        shape: const StadiumBorder(),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0),
      ),
      _MetadataPillVariant.primary => FilledButton.styleFrom(
        backgroundColor: AppThemeTokens.primary,
        foregroundColor: AppThemeTokens.onPrimary,
        disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
        disabledForegroundColor: theme.colorScheme.outline,
        shape: const StadiumBorder(),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0),
      ),
    };
    final child = icon == null
        ? Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon!,
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    return switch (variant) {
      _MetadataPillVariant.outlined => OutlinedButton(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
      _MetadataPillVariant.secondary || _MetadataPillVariant.primary =>
        FilledButton(onPressed: onPressed, style: style, child: child),
    };
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;

    return null;
  }
}
