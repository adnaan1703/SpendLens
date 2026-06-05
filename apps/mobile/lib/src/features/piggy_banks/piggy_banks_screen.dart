import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/household_repository.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/metric_card.dart';

class PiggyBanksScreen extends ConsumerStatefulWidget {
  const PiggyBanksScreen({super.key});

  static const routePath = '/piggy-banks';

  @override
  ConsumerState<PiggyBanksScreen> createState() => _PiggyBanksScreenState();
}

class _PiggyBanksScreenState extends ConsumerState<PiggyBanksScreen> {
  String? _selectedPiggyBankId;

  @override
  Widget build(BuildContext context) {
    final householdContext = ref.watch(householdContextProvider).value;
    final householdId = householdContext?.household.id;
    final piggyBanks = householdId == null
        ? const AsyncValue<List<PiggyBankSummary>>.loading()
        : ref.watch(piggyBanksProvider(householdId));

    return AppPage(
      title: 'Piggy Banks',
      subtitle: householdContext?.household.name ?? 'Manual ledgers',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: householdId == null
              ? null
              : () => ref.invalidate(piggyBanksProvider(householdId)),
          icon: const Icon(Icons.refresh),
        ),
        FilledButton.icon(
          onPressed: householdContext == null
              ? null
              : () {
                  _showPiggyBankDialog(
                    context: context,
                    householdContext: householdContext,
                  );
                },
          icon: const Icon(Icons.add),
          label: const Text('New'),
        ),
      ],
      child: switch (piggyBanks) {
        AsyncValue(:final value?) => _PiggyBanksContent(
          piggyBanks: value,
          selectedPiggyBankId: _selectedPiggyBankId,
          onSelect: (piggyBank) {
            setState(() {
              _selectedPiggyBankId = piggyBank.id;
            });
          },
          onEdit: householdContext == null
              ? null
              : (piggyBank) {
                  _showPiggyBankDialog(
                    context: context,
                    householdContext: householdContext,
                    piggyBank: piggyBank,
                  );
                },
          onAddFirst: householdContext == null
              ? null
              : () {
                  _showPiggyBankDialog(
                    context: context,
                    householdContext: householdContext,
                  );
                },
        ),
        AsyncValue(hasError: true, :final error) => EmptyState(
          icon: Icons.error_outline,
          title: 'Piggy banks unavailable',
          message: error.toString(),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _showPiggyBankDialog({
    required BuildContext context,
    required HouseholdContext householdContext,
    PiggyBankSummary? piggyBank,
  }) async {
    final result = await showDialog<PiggyBankSummary>(
      context: context,
      builder: (dialogContext) {
        return _PiggyBankDialog(
          householdContext: householdContext,
          piggyBank: piggyBank,
        );
      },
    );

    if (result == null) return;

    ref.invalidate(piggyBanksProvider(householdContext.household.id));
    setState(() {
      _selectedPiggyBankId = result.id;
    });

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${result.name} saved')));
    }
  }
}

class _PiggyBanksContent extends StatelessWidget {
  const _PiggyBanksContent({
    required this.piggyBanks,
    required this.selectedPiggyBankId,
    required this.onSelect,
    required this.onEdit,
    required this.onAddFirst,
  });

  final List<PiggyBankSummary> piggyBanks;
  final String? selectedPiggyBankId;
  final ValueChanged<PiggyBankSummary> onSelect;
  final ValueChanged<PiggyBankSummary>? onEdit;
  final VoidCallback? onAddFirst;

  @override
  Widget build(BuildContext context) {
    if (piggyBanks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EmptyState(
            icon: Icons.savings_outlined,
            title: 'No piggy banks',
            message: 'Create a manual ledger for a future expense.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAddFirst,
            icon: const Icon(Icons.add),
            label: const Text('Create piggy bank'),
          ),
        ],
      );
    }

    final selected = piggyBanks.firstWhere(
      (piggyBank) => piggyBank.id == selectedPiggyBankId,
      orElse: () => piggyBanks.first,
    );

    final totalBalance = piggyBanks.fold<double>(
      0,
      (total, piggyBank) => total + piggyBank.balanceAmount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            MetricCard(
              label: 'Active ledgers',
              value: piggyBanks.length.toString(),
              icon: Icons.savings_outlined,
              supportingText: piggyBanks.length == 1
                  ? 'Piggy bank'
                  : 'Piggy banks',
            ),
            MetricCard(
              label: 'Total balance',
              value: formatMoney(totalBalance),
              icon: Icons.account_balance_wallet_outlined,
              supportingText: 'Ledger-derived',
            ),
          ],
        ),
        const SizedBox(height: 24),
        _PiggyBankList(
          piggyBanks: piggyBanks,
          selectedPiggyBank: selected,
          onSelect: onSelect,
          onEdit: onEdit,
        ),
        const SizedBox(height: 28),
        _PiggyBankDetail(piggyBank: selected),
      ],
    );
  }
}

class _PiggyBankList extends StatelessWidget {
  const _PiggyBankList({
    required this.piggyBanks,
    required this.selectedPiggyBank,
    required this.onSelect,
    required this.onEdit,
  });

  final List<PiggyBankSummary> piggyBanks;
  final PiggyBankSummary selectedPiggyBank;
  final ValueChanged<PiggyBankSummary> onSelect;
  final ValueChanged<PiggyBankSummary>? onEdit;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 860;

    if (!isWide) {
      return Column(
        children: [
          for (final piggyBank in piggyBanks)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PiggyBankCard(
                piggyBank: piggyBank,
                isSelected: piggyBank.id == selectedPiggyBank.id,
                onSelect: () => onSelect(piggyBank),
                onEdit: onEdit == null ? null : () => onEdit!(piggyBank),
              ),
            ),
        ],
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        mainAxisExtent: 210,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: piggyBanks.length,
      itemBuilder: (context, index) {
        final piggyBank = piggyBanks[index];

        return _PiggyBankCard(
          piggyBank: piggyBank,
          isSelected: piggyBank.id == selectedPiggyBank.id,
          onSelect: () => onSelect(piggyBank),
          onEdit: onEdit == null ? null : () => onEdit!(piggyBank),
        );
      },
    );
  }
}

class _PiggyBankCard extends StatelessWidget {
  const _PiggyBankCard({
    required this.piggyBank,
    required this.isSelected,
    required this.onSelect,
    required this.onEdit,
  });

  final PiggyBankSummary piggyBank;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (piggyBank.targetProgress ?? 0).clamp(0, 1).toDouble();
    final borderColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.savings_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          piggyBank.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (piggyBank.description != null &&
                            piggyBank.description!.trim().isNotEmpty)
                          Text(
                            piggyBank.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit piggy bank',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                formatMoney(
                  piggyBank.balanceAmount,
                  currencyCode: piggyBank.currencyCode,
                ),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  Text(_targetLabel(piggyBank)),
                  if (piggyBank.targetDate != null)
                    Text('By ${dateString(piggyBank.targetDate!)}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _targetLabel(PiggyBankSummary piggyBank) {
    final target = piggyBank.targetAmount;
    if (target == null) return 'No target';

    return 'Target ${formatMoney(target, currencyCode: piggyBank.currencyCode)}';
  }
}

class _PiggyBankDetail extends ConsumerWidget {
  const _PiggyBankDetail({required this.piggyBank});

  final PiggyBankSummary piggyBank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesRequest = PiggyBankEntriesRequest(
      householdId: piggyBank.householdId,
      piggyBankId: piggyBank.id,
    );
    final entries = ref.watch(piggyBankEntriesProvider(entriesRequest));
    final transactions = ref.watch(
      transactionsProvider(
        TransactionQuery(householdId: piggyBank.householdId, pageSize: 50),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PiggyBankDetailHeader(
          piggyBank: piggyBank,
          onAddEntry: (entryType) {
            _showEntryDialog(
              context: context,
              ref: ref,
              piggyBank: piggyBank,
              entryType: entryType,
              linkableTransactions: transactions.value?.items ?? const [],
            );
          },
        ),
        const SizedBox(height: 20),
        switch (entries) {
          AsyncValue(:final value?) => _EntryTimeline(entries: value),
          AsyncValue(hasError: true, :final error) => EmptyState(
            icon: Icons.error_outline,
            title: 'Entries unavailable',
            message: error.toString(),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ],
    );
  }

  Future<void> _showEntryDialog({
    required BuildContext context,
    required WidgetRef ref,
    required PiggyBankSummary piggyBank,
    required String entryType,
    required List<FinanceTransaction> linkableTransactions,
  }) async {
    final result = await showDialog<PiggyBankEntry>(
      context: context,
      builder: (dialogContext) {
        return _PiggyBankEntryDialog(
          piggyBank: piggyBank,
          initialEntryType: entryType,
          linkableTransactions: linkableTransactions,
        );
      },
    );

    if (result == null) return;

    ref.invalidate(piggyBanksProvider(piggyBank.householdId));
    ref.invalidate(
      piggyBankEntriesProvider(
        PiggyBankEntriesRequest(
          householdId: piggyBank.householdId,
          piggyBankId: piggyBank.id,
        ),
      ),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_entryLabel(result.entryType)} saved')),
      );
    }
  }
}

class _PiggyBankDetailHeader extends StatelessWidget {
  const _PiggyBankDetailHeader({
    required this.piggyBank,
    required this.onAddEntry,
  });

  final PiggyBankSummary piggyBank;
  final ValueChanged<String> onAddEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = piggyBank.targetProgress;
    final remaining = piggyBank.remainingToTarget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(piggyBank.name, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            MetricCard(
              label: 'Current balance',
              value: formatMoney(
                piggyBank.balanceAmount,
                currencyCode: piggyBank.currencyCode,
              ),
              icon: Icons.account_balance_wallet_outlined,
              supportingText: 'From entries',
            ),
            MetricCard(
              label: 'Target progress',
              value: progress == null ? 'No target' : formatPercent(progress),
              icon: Icons.track_changes_outlined,
              supportingText: piggyBank.targetAmount == null
                  ? 'Set a target to track'
                  : 'Target ${formatMoney(piggyBank.targetAmount!, currencyCode: piggyBank.currencyCode)}',
            ),
            MetricCard(
              label: 'Remaining',
              value: remaining == null
                  ? 'No target'
                  : formatMoney(
                      remaining < 0 ? 0 : remaining,
                      currencyCode: piggyBank.currencyCode,
                    ),
              icon: Icons.flag_outlined,
              supportingText: piggyBank.targetDate == null
                  ? 'No target date'
                  : 'By ${dateString(piggyBank.targetDate!)}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => onAddEntry('deposit'),
              icon: const Icon(Icons.add),
              label: const Text('Deposit'),
            ),
            OutlinedButton.icon(
              onPressed: piggyBank.balanceAmount <= 0
                  ? null
                  : () => onAddEntry('withdrawal'),
              icon: const Icon(Icons.remove),
              label: const Text('Withdraw'),
            ),
            OutlinedButton.icon(
              onPressed: () => onAddEntry('adjustment'),
              icon: const Icon(Icons.tune_outlined),
              label: const Text('Adjust'),
            ),
          ],
        ),
      ],
    );
  }
}

class _EntryTimeline extends StatelessWidget {
  const _EntryTimeline({required this.entries});

  final List<PiggyBankEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.timeline_outlined,
        title: 'No entries yet',
        message: 'Deposits, withdrawals, and adjustments will appear here.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Entry timeline', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _EntryCard(entry: entry),
          ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final PiggyBankEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signedAmount = entry.signedAmount;
    final amountColor = signedAmount < 0
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Card(
      child: ListTile(
        leading: Icon(_entryIcon(entry.entryType), color: amountColor),
        title: Text(_entryLabel(entry.entryType)),
        subtitle: Text(_entrySubtitle(entry)),
        trailing: Text(
          formatSignedMoney(signedAmount),
          style: theme.textTheme.titleMedium?.copyWith(color: amountColor),
        ),
      ),
    );
  }

  String _entrySubtitle(PiggyBankEntry entry) {
    final pieces = [
      dateString(entry.entryDate),
      if (entry.note != null && entry.note!.trim().isNotEmpty) entry.note!,
      if (entry.linkedTransactionId != null) 'Linked transaction',
    ];

    return pieces.join(' - ');
  }
}

class _PiggyBankDialog extends ConsumerStatefulWidget {
  const _PiggyBankDialog({required this.householdContext, this.piggyBank});

  final HouseholdContext householdContext;
  final PiggyBankSummary? piggyBank;

  @override
  ConsumerState<_PiggyBankDialog> createState() => _PiggyBankDialogState();
}

class _PiggyBankDialogState extends ConsumerState<_PiggyBankDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _description;
  late String _targetAmount;
  DateTime? _targetDate;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    final piggyBank = widget.piggyBank;
    _name = piggyBank?.name ?? '';
    _description = piggyBank?.description ?? '';
    _targetAmount = piggyBank?.targetAmount == null
        ? ''
        : _amountText(piggyBank!.targetAmount!);
    _targetDate = piggyBank?.targetDate;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.piggyBank == null ? 'Create piggy bank' : 'Edit piggy bank',
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: _name,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.savings_outlined),
                  ),
                  onChanged: (value) {
                    _name = value;
                  },
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Name is required';

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  onChanged: (value) {
                    _description = value;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _targetAmount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Target amount',
                    prefixIcon: Icon(Icons.flag_outlined),
                    prefixText: 'INR ',
                  ),
                  onChanged: (value) {
                    _targetAmount = value;
                  },
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;

                    final parsed = double.tryParse(text);
                    if (parsed == null) return 'Enter a valid amount';
                    if (parsed < 0) return 'Target amount cannot be negative';

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTargetDate,
                        icon: const Icon(Icons.event_outlined),
                        label: Text(
                          _targetDate == null
                              ? 'Target date'
                              : dateString(_targetDate!),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Clear target date',
                      onPressed: _targetDate == null
                          ? null
                          : () {
                              setState(() {
                                _targetDate = null;
                              });
                            },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10, 12, 31),
    );

    if (picked == null) return;

    setState(() {
      _targetDate = picked;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final targetAmountText = _targetAmount.trim();
      final saved = await ref
          .read(financeRepositoryProvider)
          .savePiggyBank(
            PiggyBankSaveRequest(
              id: widget.piggyBank?.id,
              householdId: widget.householdContext.household.id,
              profileId: widget.householdContext.profile.id,
              name: _name.trim(),
              description: _description.trim().isEmpty
                  ? null
                  : _description.trim(),
              targetAmount: targetAmountText.isEmpty
                  ? null
                  : double.parse(targetAmountText),
              targetDate: _targetDate,
            ),
          );

      if (mounted) Navigator.of(context).pop(saved);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _PiggyBankEntryDialog extends ConsumerStatefulWidget {
  const _PiggyBankEntryDialog({
    required this.piggyBank,
    required this.initialEntryType,
    required this.linkableTransactions,
  });

  final PiggyBankSummary piggyBank;
  final String initialEntryType;
  final List<FinanceTransaction> linkableTransactions;

  @override
  ConsumerState<_PiggyBankEntryDialog> createState() =>
      _PiggyBankEntryDialogState();
}

class _PiggyBankEntryDialogState extends ConsumerState<_PiggyBankEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _entryType;
  var _amount = '';
  var _note = '';
  DateTime _entryDate = DateTime.now();
  String? _linkedTransactionId;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _entryType = widget.initialEntryType;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${_entryLabel(_entryType)} entry'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'deposit',
                      icon: Icon(Icons.add),
                      label: Text('Deposit'),
                    ),
                    ButtonSegment(
                      value: 'withdrawal',
                      icon: Icon(Icons.remove),
                      label: Text('Withdraw'),
                    ),
                    ButtonSegment(
                      value: 'adjustment',
                      icon: Icon(Icons.tune_outlined),
                      label: Text('Adjust'),
                    ),
                  ],
                  selected: {_entryType},
                  onSelectionChanged: _isSaving
                      ? null
                      : (values) {
                          setState(() {
                            _entryType = values.single;
                            _amount = '';
                          });
                        },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: ValueKey(_entryType),
                  initialValue: _amount,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      _entryType == 'adjustment'
                          ? RegExp(r'[-0-9.]')
                          : RegExp(r'[0-9.]'),
                    ),
                  ],
                  decoration: InputDecoration(
                    labelText: _entryType == 'adjustment'
                        ? 'Adjustment amount'
                        : 'Amount',
                    prefixIcon: Icon(_entryIcon(_entryType)),
                    prefixText: 'INR ',
                  ),
                  onChanged: (value) {
                    _amount = value;
                  },
                  validator: _validateAmount,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickEntryDate,
                        icon: const Icon(Icons.event_outlined),
                        label: Text(dateString(_entryDate)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _linkedTransactionId,
                  decoration: const InputDecoration(
                    labelText: 'Linked transaction',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No linked transaction'),
                    ),
                    for (final transaction in widget.linkableTransactions)
                      DropdownMenuItem(
                        value: transaction.id,
                        child: Text(
                          _transactionLabel(transaction),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          _linkedTransactionId = value;
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  onChanged: (value) {
                    _note = value;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Save'),
        ),
      ],
    );
  }

  String? _validateAmount(String? value) {
    final text = value?.trim() ?? '';
    final parsed = double.tryParse(text);
    if (parsed == null) return 'Enter a valid amount';

    if (_entryType == 'adjustment') {
      if (parsed == 0) return 'Adjustment amount cannot be zero';

      return null;
    }

    if (parsed <= 0) return 'Amount must be positive';
    if (_entryType == 'withdrawal' && parsed > widget.piggyBank.balanceAmount) {
      return 'Cannot exceed current balance';
    }

    return null;
  }

  Future<void> _pickEntryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );

    if (picked == null) return;

    setState(() {
      _entryDate = picked;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final entry = await ref
          .read(financeRepositoryProvider)
          .createPiggyBankEntry(
            PiggyBankEntryRequest(
              householdId: widget.piggyBank.householdId,
              piggyBankId: widget.piggyBank.id,
              entryType: _entryType,
              amount: double.parse(_amount.trim()),
              entryDate: _entryDate,
              note: _note.trim().isEmpty ? null : _note.trim(),
              linkedTransactionId: _linkedTransactionId,
            ),
          );

      if (mounted) Navigator.of(context).pop(entry);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

IconData _entryIcon(String entryType) {
  return switch (entryType) {
    'deposit' => Icons.add_circle_outline,
    'withdrawal' => Icons.remove_circle_outline,
    'adjustment' => Icons.tune_outlined,
    _ => Icons.savings_outlined,
  };
}

String _entryLabel(String entryType) {
  return switch (entryType) {
    'deposit' => 'Deposit',
    'withdrawal' => 'Withdrawal',
    'adjustment' => 'Adjustment',
    _ => entryType,
  };
}

String _transactionLabel(FinanceTransaction transaction) {
  return '${dateString(transaction.transactionDate)} - '
      '${transaction.statementMerchant} - '
      '${formatMoney(transaction.netExpense)}';
}

String _amountText(double amount) {
  if (amount == amount.roundToDouble()) return amount.round().toString();

  return amount.toStringAsFixed(2);
}
