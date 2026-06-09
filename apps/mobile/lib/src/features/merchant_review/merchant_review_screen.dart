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
    final parseFailures = householdId == null
        ? const AsyncValue<List<GmailParseFailure>>.loading()
        : ref.watch(gmailParseFailuresProvider(householdId));
    final categories = householdId == null
        ? const AsyncValue<List<CategoryOption>>.loading()
        : ref.watch(transactionCategoriesProvider(householdId));
    final subcategories = householdId == null
        ? const AsyncValue<List<SubcategoryOption>>.loading()
        : ref.watch(merchantSubcategoriesProvider(householdId));

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
                  ref.invalidate(gmailParseFailuresProvider(householdId));
                },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: _reviewBody(
        reviewItems: reviewItems,
        parseFailures: parseFailures,
        categories: categories,
        subcategories: subcategories,
        householdContext: householdContext,
        context: context,
        ref: ref,
      ),
    );
  }

  Widget _reviewBody({
    required AsyncValue<List<MerchantReviewItem>> reviewItems,
    required AsyncValue<List<GmailParseFailure>> parseFailures,
    required AsyncValue<List<CategoryOption>> categories,
    required AsyncValue<List<SubcategoryOption>> subcategories,
    required HouseholdContext? householdContext,
    required BuildContext context,
    required WidgetRef ref,
  }) {
    if (reviewItems.hasError) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Review queue unavailable',
        message: reviewItems.error.toString(),
      );
    }

    if (parseFailures.hasError) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Gmail parse failures unavailable',
        message: parseFailures.error.toString(),
      );
    }

    final items = reviewItems.value;
    final failures = parseFailures.value;
    if (items == null || failures == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return _MerchantReviewContent(
      items: items,
      parseFailures: failures,
      categories: categories.value ?? const [],
      optionsReady: categories.hasValue && subcategories.hasValue,
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
    );
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
    required this.parseFailures,
    required this.categories,
    required this.optionsReady,
    required this.onCorrect,
  });

  final List<MerchantReviewItem> items;
  final List<GmailParseFailure> parseFailures;
  final List<CategoryOption> categories;
  final bool optionsReady;
  final ValueChanged<MerchantReviewItem>? onCorrect;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && parseFailures.isEmpty) {
      return const EmptyState(
        icon: Icons.rule_folder_outlined,
        title: 'No review items',
        message: 'Low-confidence merchant mappings will appear here.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parseFailures.isNotEmpty) ...[
          _GmailParseFailuresCard(failures: parseFailures),
          if (items.isNotEmpty) const SizedBox(height: 20),
        ],
        if (items.isNotEmpty) ...[
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
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ReviewItemCard(
                item: item,
                canCorrect: optionsReady && onCorrect != null,
                onCorrect: onCorrect == null ? null : () => onCorrect!(item),
              ),
            ),
        ],
      ],
    );
  }
}

class _GmailParseFailuresCard extends StatelessWidget {
  const _GmailParseFailuresCard({required this.failures});

  final List<GmailParseFailure> failures;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gmail parse failures',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${failures.length} recent '
                        '${failures.length == 1 ? 'failure' : 'failures'}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final failure in failures) ...[
              _GmailParseFailureRow(failure: failure),
              if (failure != failures.last) const Divider(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _GmailParseFailureRow extends StatelessWidget {
  const _GmailParseFailureRow({required this.failure});

  final GmailParseFailure failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(failure.subject, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(
              icon: Icons.account_balance_wallet_outlined,
              label: failure.candidateTypeLabel,
            ),
            _InfoChip(
              icon: Icons.report_problem_outlined,
              label: failure.reasonLabel,
            ),
            _InfoChip(
              icon: Icons.integration_instructions_outlined,
              label: failure.parserLabel,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _FailureDetailLine(
          icon: Icons.schedule_outlined,
          label: 'Received ${_formatReceivedAt(failure.sourceReceivedAt)}',
        ),
        _FailureDetailLine(
          icon: Icons.alternate_email_outlined,
          label: failure.senderEmail,
        ),
        _FailureDetailLine(
          icon: Icons.email_outlined,
          label: 'Message ${failure.sourceMessageId}',
        ),
        if (failure.sourceThreadId != null)
          _FailureDetailLine(
            icon: Icons.forum_outlined,
            label: 'Thread ${failure.sourceThreadId}',
          ),
      ],
    );
  }
}

class _FailureDetailLine extends StatelessWidget {
  const _FailureDetailLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({
    required this.item,
    required this.canCorrect,
    required this.onCorrect,
  });

  final MerchantReviewItem item;
  final bool canCorrect;
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

String _formatReceivedAt(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '${local.year}-$month-$day $hour:$minute';
}
