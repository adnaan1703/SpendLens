import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/household_repository.dart';
import '../../shared/widgets/app_primitives.dart';

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  static const routePath = '/ask';

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final _questionController = TextEditingController();
  ExpenseQuestionAnswer? _answer;
  String? _askError;
  bool _isAsking = false;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _ask(String householdId) async {
    final question = _questionController.text.trim();
    if (question.length < 4) return;

    setState(() {
      _isAsking = true;
      _askError = null;
    });

    try {
      final answer = await ref
          .read(financeRepositoryProvider)
          .askExpenseQuestion(
            ExpenseQuestionRequest(
              householdId: householdId,
              question: question,
            ),
          );
      ref.invalidate(aiBudgetStatusProvider(householdId));
      if (mounted) {
        setState(() {
          _answer = answer;
          _askError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _askError = error.toString();
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAsking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final householdContext = ref.watch(householdContextProvider).value;
    final householdId = householdContext?.household.id;
    final budgetStatus = householdId == null
        ? const AsyncValue<AiBudgetStatus>.loading()
        : ref.watch(aiBudgetStatusProvider(householdId));

    return AppPage(
      title: 'Ask Expenses',
      subtitle: householdContext?.household.name ?? 'Household Q&A',
      maxContentWidth: 920,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: householdId == null
              ? null
              : () => ref.invalidate(aiBudgetStatusProvider(householdId)),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: householdId == null
          ? const AppLoadingState(
              title: 'Loading household context',
              message: 'Preparing the household workspace.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _QuestionComposer(
                  controller: _questionController,
                  isAsking: _isAsking,
                  onAsk: () => _ask(householdId),
                ),
                const SizedBox(height: 16),
                budgetStatus.when(
                  loading: () => const AppLoadingState(
                    title: 'Loading AI budget',
                    message: 'Checking monthly usage and model availability.',
                  ),
                  error: (error, _) => EmptyState(
                    icon: Icons.error_outline,
                    title: 'AI status unavailable',
                    message: error.toString(),
                    action: AppActionPill.secondary(
                      label: 'Retry',
                      icon: Icons.refresh,
                      onPressed: () =>
                          ref.invalidate(aiBudgetStatusProvider(householdId)),
                    ),
                  ),
                  data: (status) => _AiBudgetPanel(status: status),
                ),
                if (_isAsking) ...[
                  const SizedBox(height: 16),
                  const _AnswerLoadingPanel(),
                ] else if (_askError != null) ...[
                  const SizedBox(height: 16),
                  _AskErrorPanel(message: _askError!),
                ] else if (_answer != null) ...[
                  const SizedBox(height: 16),
                  _AnswerPanel(answer: _answer!),
                ],
              ],
            ),
    );
  }
}

class _QuestionComposer extends StatelessWidget {
  const _QuestionComposer({
    required this.controller,
    required this.isAsking,
    required this.onAsk,
  });

  final TextEditingController controller;
  final bool isAsking;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    return AppContentCard(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeading(
              title: 'Question',
              trailing: Icon(Icons.question_answer_outlined),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Ask about your expenses',
                hintText: 'What did I spend on food in March?',
                prefixIcon: Icon(Icons.question_answer_outlined),
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact =
                    constraints.hasBoundedWidth && constraints.maxWidth < 420;
                final action = AppActionPill.primary(
                  label: isAsking ? 'Asking...' : 'Ask',
                  icon: Icons.auto_awesome,
                  tooltip: 'Ask AI',
                  onPressed: isAsking ? null : onAsk,
                );

                return Align(
                  alignment: isCompact
                      ? Alignment.center
                      : Alignment.centerRight,
                  child: isCompact
                      ? SizedBox(width: double.infinity, child: action)
                      : action,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AiBudgetPanel extends StatelessWidget {
  const _AiBudgetPanel({required this.status});

  final AiBudgetStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cap = '\$${status.monthlySpendCapUsd.toStringAsFixed(2)}';
    final usage =
        '${status.currentMonthEventCount} calls / \$${status.currentMonthSpendUsd.toStringAsFixed(4)}';
    final remaining =
        '\$${status.remainingMonthlyBudgetUsd.toStringAsFixed(2)}';

    return SageFeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeading(
            title: 'AI budget',
            showDivider: false,
            trailing: StatusChip(
              label: status.modeLabel,
              tone: status.freeTierOnly
                  ? AppStatusTone.neutral
                  : AppStatusTone.positive,
              icon: Icons.auto_awesome,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 20,
            runSpacing: 16,
            children: [
              _AiStatusItem(label: 'Provider', value: status.provider),
              _AiStatusItem(label: 'Model', value: status.model),
              _AiStatusItem(label: 'Usage', value: usage),
              _AiStatusItem(label: 'Monthly cap', value: cap),
              _AiStatusItem(label: 'Remaining', value: remaining),
              _AiStatusItem(
                label: 'Period',
                value: _formatMonth(status.currentPeriodMonth),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(
                label: status.expenseQaEnabled
                    ? 'Expense Q&A on'
                    : 'Expense Q&A off',
                tone: status.expenseQaEnabled
                    ? AppStatusTone.positive
                    : AppStatusTone.negative,
                icon: status.expenseQaEnabled
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
              ),
              StatusChip(
                label: status.transactionMetadataSuggestionEnabled
                    ? 'Metadata suggest on'
                    : 'Metadata suggest off',
                tone: status.transactionMetadataSuggestionEnabled
                    ? AppStatusTone.positive
                    : AppStatusTone.negative,
                icon: status.transactionMetadataSuggestionEnabled
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
              ),
              StatusChip(
                label: status.transactionMetadataSuggestionSearchLabel,
                tone: status.transactionMetadataSuggestionWebSearchEnabled
                    ? AppStatusTone.positive
                    : AppStatusTone.neutral,
                icon: Icons.search,
              ),
            ],
          ),
          if (!status.expenseQaEnabled ||
              !status.transactionMetadataSuggestionEnabled) ...[
            const SizedBox(height: 14),
            Text(
              [
                if (!status.expenseQaEnabled) 'Expense Q&A disabled',
                if (!status.transactionMetadataSuggestionEnabled)
                  'Metadata suggestions disabled',
              ].join(' · '),
              style: textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatMonth(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[value.month - 1]} ${value.year}';
  }
}

class _AnswerLoadingPanel extends StatelessWidget {
  const _AnswerLoadingPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const foreground = AppThemeTokens.primary;

    return DarkFeatureCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacks =
              constraints.hasBoundedWidth && constraints.maxWidth < 420;
          final indicator = const SizedBox.square(
            dimension: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          );
          final text = Column(
            crossAxisAlignment: stacks
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                'Preparing answer',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: foreground,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Checking expense history and budget usage.',
                style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              ),
            ],
          );

          if (stacks) {
            return Column(
              children: [indicator, const SizedBox(height: 14), text],
            );
          }

          return Row(
            children: [
              indicator,
              const SizedBox(width: 16),
              Expanded(child: text),
            ],
          );
        },
      ),
    );
  }
}

class _AskErrorPanel extends StatelessWidget {
  const _AskErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppErrorState(title: 'Ask failed', message: message);
  }
}

class _AiStatusItem extends StatelessWidget {
  const _AiStatusItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 128, maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelSmall?.copyWith(letterSpacing: 0)),
          const SizedBox(height: 4),
          Text(value, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _AnswerPanel extends StatelessWidget {
  const _AnswerPanel({required this.answer});

  final ExpenseQuestionAnswer answer;

  @override
  Widget build(BuildContext context) {
    return AppContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeading(
            title: 'Answer',
            trailing: Icon(Icons.auto_awesome),
          ),
          const SizedBox(height: 16),
          Text(answer.answer),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              IconChip(
                icon: Icons.input,
                label: '${answer.inputTokens} input tokens',
              ),
              IconChip(
                icon: Icons.output,
                label: '${answer.outputTokens} output tokens',
              ),
              IconChip(
                icon: Icons.payments_outlined,
                label: '\$${answer.estimatedCostUsd.toStringAsFixed(6)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
