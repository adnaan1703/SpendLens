import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/household_repository.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/metric_card.dart';
import '../transaction_metadata/transaction_metadata_editor.dart';

class MerchantReviewScreen extends ConsumerWidget {
  const MerchantReviewScreen({super.key});

  static const routePath = '/merchant-review';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdContext = ref.watch(householdContextProvider).value;
    final householdId = householdContext?.household.id;
    final reviewItems = householdId == null
        ? const AsyncValue<List<MerchantReviewItem>>.loading()
        : ref.watch(merchantReviewQueueProvider(householdId));
    final categories = householdId == null
        ? const AsyncValue<List<CategoryOption>>.loading()
        : ref.watch(transactionCategoriesProvider(householdId));
    final subcategories = householdId == null
        ? const AsyncValue<List<SubcategoryOption>>.loading()
        : ref.watch(merchantSubcategoriesProvider(householdId));
    final researchSuggestions = householdId == null
        ? const AsyncValue<List<MerchantResearchSuggestion>>.loading()
        : ref.watch(merchantResearchSuggestionsProvider(householdId));

    return AppPage(
      title: 'Merchant Review',
      subtitle: householdContext?.household.name ?? 'Open mappings',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: householdId == null
              ? null
              : () {
                  ref.invalidate(merchantReviewQueueProvider(householdId));
                  ref.invalidate(
                    merchantResearchSuggestionsProvider(householdId),
                  );
                },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: switch (reviewItems) {
        AsyncValue(:final value?) => _MerchantReviewContent(
          items: value,
          suggestions: researchSuggestions.value ?? const [],
          categories: categories.value ?? const [],
          optionsReady: categories.hasValue && subcategories.hasValue,
          onResearch: householdContext == null
              ? null
              : (item) {
                  _researchMerchant(
                    context: context,
                    ref: ref,
                    householdContext: householdContext,
                    item: item,
                  );
                },
          onCorrect: householdContext == null
              ? null
              : (item) {
                  _showCorrectionDialog(
                    context: context,
                    ref: ref,
                    householdContext: householdContext,
                    item: item,
                    categories: categories.value ?? const [],
                    subcategories: subcategories.value ?? const [],
                  );
                },
        ),
        AsyncValue(hasError: true, :final error) => EmptyState(
          icon: Icons.error_outline,
          title: 'Review queue unavailable',
          message: error.toString(),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _researchMerchant({
    required BuildContext context,
    required WidgetRef ref,
    required HouseholdContext householdContext,
    required MerchantReviewItem item,
  }) async {
    try {
      final suggestion = await ref
          .read(financeRepositoryProvider)
          .researchMerchant(
            MerchantResearchRequest(
              householdId: householdContext.household.id,
              reviewItemId: item.id,
              statementMerchant: item.statementMerchant,
            ),
          );
      ref.invalidate(
        merchantResearchSuggestionsProvider(householdContext.household.id),
      );
      ref.invalidate(aiBudgetStatusProvider(householdContext.household.id));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Suggested ${suggestion.title}')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _showCorrectionDialog({
    required BuildContext context,
    required WidgetRef ref,
    required HouseholdContext householdContext,
    required MerchantReviewItem item,
    required List<CategoryOption> categories,
    required List<SubcategoryOption> subcategories,
  }) async {
    final result = await showTransactionMetadataEditor(
      context: context,
      ref: ref,
      initialValue: TransactionMetadataEditorInitialValue(
        householdId: householdContext.household.id,
        transactionId: item.transactionId,
        reviewItemId: item.id,
        statementMerchant: item.statementMerchant,
        merchantGroup: item.correctionMerchantName,
        categoryId: item.correctionCategoryId,
        subcategoryId: item.correctionSubcategoryId,
        confidence: item.confidence,
      ),
      categories: categories,
      subcategories: subcategories,
    );

    if (result == null) return;

    ref.invalidate(merchantReviewQueueProvider(householdContext.household.id));
    ref.invalidate(transactionsProvider);
    ref.invalidate(trendReportProvider);
    ref.invalidate(
      merchantResearchSuggestionsProvider(householdContext.household.id),
    );
    ref.invalidate(
      dashboardSnapshotProvider(
        FinanceMonthRequest(householdId: householdContext.household.id),
      ),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Resolved ${result.resolvedReviewItemCount} review items',
          ),
        ),
      );
    }
  }
}

class _MerchantReviewContent extends StatelessWidget {
  const _MerchantReviewContent({
    required this.items,
    required this.suggestions,
    required this.categories,
    required this.optionsReady,
    required this.onResearch,
    required this.onCorrect,
  });

  final List<MerchantReviewItem> items;
  final List<MerchantResearchSuggestion> suggestions;
  final List<CategoryOption> categories;
  final bool optionsReady;
  final ValueChanged<MerchantReviewItem>? onResearch;
  final ValueChanged<MerchantReviewItem>? onCorrect;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.rule_folder_outlined,
        title: 'No review items',
        message: 'Low-confidence merchant mappings will appear here.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            MetricCard(
              label: 'Open reviews',
              value: items.length.toString(),
              icon: Icons.rule_folder_outlined,
              supportingText: items.length == 1 ? 'Item' : 'Items',
            ),
            MetricCard(
              label: 'Correction data',
              value: optionsReady ? 'Ready' : 'Loading',
              icon: Icons.tune_outlined,
              supportingText: '${categories.length} categories',
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (suggestions.isNotEmpty) ...[
          _ResearchSuggestionList(suggestions: suggestions),
          const SizedBox(height: 20),
        ],
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ReviewItemCard(
              item: item,
              canCorrect: optionsReady && onCorrect != null,
              canResearch: onResearch != null,
              onResearch: onResearch == null ? null : () => onResearch!(item),
              onCorrect: onCorrect == null ? null : () => onCorrect!(item),
            ),
          ),
      ],
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({
    required this.item,
    required this.canCorrect,
    required this.canResearch,
    required this.onResearch,
    required this.onCorrect,
  });

  final MerchantReviewItem item;
  final bool canCorrect;
  final bool canResearch;
  final VoidCallback? onResearch;
  final VoidCallback? onCorrect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountColor = item.netExpense < 0
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.statementMerchant,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dateString(item.transactionDate)} - ${item.reason}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatMoney(item.netExpense),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: amountColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.storefront_outlined,
                  label: item.currentMerchantName ?? 'Unknown merchant',
                ),
                _InfoChip(
                  icon: Icons.category_outlined,
                  label: item.currentCategoryName ?? 'Uncategorized',
                ),
                _InfoChip(
                  icon: Icons.sell_outlined,
                  label: item.currentSubcategoryName ?? 'No subcategory',
                ),
                _InfoChip(
                  icon: Icons.auto_awesome_motion_outlined,
                  label: item.confidence,
                ),
                _InfoChip(
                  icon: Icons.payments_outlined,
                  label: 'Source ${formatMoney(item.amount)}',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: canResearch ? onResearch : null,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Research'),
                  ),
                  FilledButton.icon(
                    onPressed: canCorrect ? onCorrect : null,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Resolve'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResearchSuggestionList extends StatelessWidget {
  const _ResearchSuggestionList({required this.suggestions});

  final List<MerchantResearchSuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined),
                const SizedBox(width: 10),
                Text('AI suggestions', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            for (final suggestion in suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(suggestion.title),
                  subtitle: Text(suggestion.subtitle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
    );
  }
}
