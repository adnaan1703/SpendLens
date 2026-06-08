import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/household_repository.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/empty_state.dart';

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  static const routePath = '/ask';

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final _questionController = TextEditingController();
  ExpenseQuestionAnswer? _answer;
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
        });
      }
    } catch (error) {
      if (mounted) {
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
          ? const Center(child: CircularProgressIndicator())
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
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => EmptyState(
                    icon: Icons.error_outline,
                    title: 'AI status unavailable',
                    message: error.toString(),
                  ),
                  data: (status) => _AiBudgetPanel(status: status),
                ),
                if (_answer != null) ...[
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Question',
                prefixIcon: Icon(Icons.question_answer_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: isAsking ? null : onAsk,
                icon: isAsking
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(isAsking ? 'Asking...' : 'Ask'),
              ),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            _AiStatusItem(label: 'Provider', value: status.provider),
            _AiStatusItem(label: 'Model', value: status.model),
            _AiStatusItem(label: 'Mode', value: status.modeLabel),
            _AiStatusItem(
              label: 'Usage',
              value:
                  '${status.currentMonthEventCount} calls / \$${status.currentMonthSpendUsd.toStringAsFixed(4)}',
            ),
            _AiStatusItem(
              label: 'Cap',
              value: '\$${status.monthlySpendCapUsd.toStringAsFixed(2)}',
            ),
            _AiStatusItem(
              label: 'Research',
              value: status.merchantResearchSearchLabel,
            ),
            if (!status.expenseQaEnabled)
              Text(
                'Expense Q&A disabled',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
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
      constraints: const BoxConstraints(minWidth: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelSmall),
          const SizedBox(height: 2),
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
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Answer', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(answer.answer),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.input, size: 18),
                  label: Text('${answer.inputTokens} input tokens'),
                ),
                Chip(
                  avatar: const Icon(Icons.output, size: 18),
                  label: Text('${answer.outputTokens} output tokens'),
                ),
                Chip(
                  avatar: const Icon(Icons.payments_outlined, size: 18),
                  label: Text(
                    '\$${answer.estimatedCostUsd.toStringAsFixed(6)}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
