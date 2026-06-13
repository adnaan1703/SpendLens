import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/household_repository.dart';
import '../../shared/widgets/app_primitives.dart';

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

    return _VaultsPage(
      onRefresh: householdId == null
          ? null
          : () => ref.invalidate(piggyBanksProvider(householdId)),
      onNewVault: householdContext == null
          ? null
          : () {
              _showPiggyBankDialog(
                context: context,
                householdContext: householdContext,
              );
            },
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
          title: 'Vaults unavailable',
          message: error.toString(),
        ),
        _ => const AppLoadingState(
          title: 'Loading vaults',
          message: 'Checking manual ledgers and balances.',
        ),
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

class _VaultsPage extends StatelessWidget {
  const _VaultsPage({
    required this.onRefresh,
    required this.onNewVault,
    required this.child,
  });

  final VoidCallback? onRefresh;
  final VoidCallback? onNewVault;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppResponsiveBuilder(
      reserveBottomNavigationSpace: true,
      builder: (context, metrics) {
        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: metrics.pagePadding,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: metrics.contentConstraints,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _VaultsHeader(onRefresh: onRefresh, onNewVault: onNewVault),
                    SizedBox(height: metrics.sectionGap),
                    child,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VaultsHeader extends StatelessWidget {
  const _VaultsHeader({required this.onRefresh, required this.onNewVault});

  final VoidCallback? onRefresh;
  final VoidCallback? onNewVault;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Text(
      'Vaults',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        height: 0.98,
      ),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Refresh vaults',
          child: IconButton.filledTonal(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ),
        const SizedBox(width: 8),
        AppActionPill.secondary(
          label: 'New Vault',
          icon: Icons.add,
          onPressed: onNewVault,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacks =
            constraints.hasBoundedWidth && constraints.maxWidth < 330;
        if (stacks) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 16), actions],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
    );
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _VaultSummaryCards(activeLedgerCount: 0, totalBalance: 0),
          const SizedBox(height: 24),
          _NoVaultsCard(onCreate: onAddFirst),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VaultSummaryCards(
          activeLedgerCount: piggyBanks.length,
          totalBalance: totalBalance,
        ),
        if (piggyBanks.length > 1) ...[
          const SizedBox(height: 28),
          _PiggyBankList(
            piggyBanks: piggyBanks,
            selectedPiggyBank: selected,
            onSelect: onSelect,
            onEdit: onEdit,
          ),
        ],
        const SizedBox(height: 36),
        _PiggyBankDetail(
          piggyBank: selected,
          onEdit: onEdit == null ? null : () => onEdit!(selected),
        ),
      ],
    );
  }
}

class _VaultSummaryCards extends StatelessWidget {
  const _VaultSummaryCards({
    required this.activeLedgerCount,
    required this.totalBalance,
  });

  final int activeLedgerCount;
  final double totalBalance;

  @override
  Widget build(BuildContext context) {
    final ledgerLabel = activeLedgerCount == 1 ? 'Vault' : 'Vaults';

    return MetricCardGrid(
      minTileWidth: 240,
      spacing: 16,
      runSpacing: 16,
      children: [
        MetricCard(
          label: 'Active ledgers',
          value: activeLedgerCount.toString(),
          icon: Icons.savings_outlined,
          supportingText: ledgerLabel,
          width: null,
        ),
        MetricCard(
          label: 'Total balance',
          value: formatMoney(totalBalance),
          icon: Icons.account_balance_wallet_outlined,
          supportingText: 'Ledger-derived',
          width: null,
        ),
      ],
    );
  }
}

class _NoVaultsCard extends StatelessWidget {
  const _NoVaultsCard({required this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmptyState(
          icon: Icons.savings_outlined,
          title: 'No vaults yet',
          message: 'Create a manual ledger for a future expense.',
          action: AppActionPill.primary(
            label: 'Create vault',
            icon: Icons.add,
            onPressed: onCreate,
          ),
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeading(
          title: 'Vault ledgers',
          subtitle: 'Choose the ledger to review or update.',
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final columns = (availableWidth / 320).floor().clamp(1, 3);
            final cardWidth = (availableWidth - (16 * (columns - 1))) / columns;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final piggyBank in piggyBanks)
                  SizedBox(
                    width: cardWidth,
                    child: _PiggyBankCard(
                      piggyBank: piggyBank,
                      isSelected: piggyBank.id == selectedPiggyBank.id,
                      onSelect: () => onSelect(piggyBank),
                      onEdit: onEdit == null ? null : () => onEdit!(piggyBank),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
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
        ? AppThemeTokens.primary
        : theme.colorScheme.outlineVariant;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${piggyBank.name} vault',
      child: AppContentCard(
        onTap: onSelect,
        borderSide: BorderSide(color: borderColor, width: isSelected ? 2 : 1),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: ShapeDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    shape: const OvalBorder(),
                  ),
                  child: Icon(
                    Icons.savings_outlined,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
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
                  tooltip: 'Edit vault',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LargeAmountText(
              formatMoney(
                piggyBank.balanceAmount,
                currencyCode: piggyBank.currencyCode,
              ),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                height: 1,
              ),
            ),
            const SizedBox(height: 12),
            _VaultProgressBar(value: progress),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                Text(_targetLabel(piggyBank), style: theme.textTheme.bodySmall),
                if (piggyBank.targetDate != null)
                  Text(
                    'By ${dateString(piggyBank.targetDate!)}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ],
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
  const _PiggyBankDetail({required this.piggyBank, required this.onEdit});

  final PiggyBankSummary piggyBank;
  final VoidCallback? onEdit;

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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VaultHeroCard(
          piggyBank: piggyBank,
          onEdit: onEdit,
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
        _VaultDetailMetrics(piggyBank: piggyBank),
        const SizedBox(height: 24),
        switch (entries) {
          AsyncValue(:final value?) => _EntryTimeline(entries: value),
          AsyncValue(hasError: true, :final error) => EmptyState(
            icon: Icons.error_outline,
            title: 'Entries unavailable',
            message: error.toString(),
          ),
          _ => const AppLoadingState(
            title: 'Loading entries',
            message: 'Reading deposits, withdrawals, and adjustments.',
          ),
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

class _VaultHeroCard extends StatelessWidget {
  const _VaultHeroCard({
    required this.piggyBank,
    required this.onEdit,
    required this.onAddEntry,
  });

  final PiggyBankSummary piggyBank;
  final VoidCallback? onEdit;
  final ValueChanged<String> onAddEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (piggyBank.targetProgress ?? 0).clamp(0, 1).toDouble();
    final targetText = piggyBank.targetAmount == null
        ? 'No target'
        : formatMoney(
            piggyBank.targetAmount!,
            currencyCode: piggyBank.currencyCode,
          );
    final targetDetails = piggyBank.targetDate == null
        ? 'No target date'
        : 'By ${dateString(piggyBank.targetDate!)}';

    return AppContentCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      piggyBank.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    if (piggyBank.description != null &&
                        piggyBank.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        piggyBank.description!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Target date: ${piggyBank.targetDate == null ? 'Not set' : dateString(piggyBank.targetDate!)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit vault',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 28),
          LargeAmountText(
            formatMoney(
              piggyBank.balanceAmount,
              currencyCode: piggyBank.currencyCode,
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 28),
          _VaultProgressBar(value: progress),
          const SizedBox(height: 16),
          _VaultDetailRow(label: 'Target', value: targetText),
          const SizedBox(height: 10),
          _VaultDetailRow(label: 'Target details', value: targetDetails),
          const SizedBox(height: 24),
          _VaultActionGrid(
            actions: [
              _VaultEntryActionButton(
                label: 'Deposit',
                icon: Icons.add,
                onPressed: () => onAddEntry('deposit'),
              ),
              _VaultEntryActionButton(
                label: 'Withdraw',
                icon: Icons.remove,
                onPressed: piggyBank.balanceAmount <= 0
                    ? null
                    : () => onAddEntry('withdrawal'),
              ),
              _VaultEntryActionButton(
                label: 'Adjust',
                icon: Icons.tune_outlined,
                onPressed: () => onAddEntry('adjustment'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VaultActionGrid extends StatelessWidget {
  const _VaultActionGrid({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final columns = availableWidth >= 560 ? actions.length : 2;
        final width = (availableWidth - (12 * (columns - 1))) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final action in actions) SizedBox(width: width, child: action),
          ],
        );
      },
    );
  }
}

class _VaultEntryActionButton extends StatelessWidget {
  const _VaultEntryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        foregroundColor: theme.colorScheme.onSurface,
        disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
        disabledForegroundColor: theme.colorScheme.outline,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemeTokens.buttonRadius),
        ),
        textStyle: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _VaultDetailMetrics extends StatelessWidget {
  const _VaultDetailMetrics({required this.piggyBank});

  final PiggyBankSummary piggyBank;

  @override
  Widget build(BuildContext context) {
    final progress = piggyBank.targetProgress;
    final remaining = piggyBank.remainingToTarget;

    return MetricCardGrid(
      minTileWidth: 220,
      spacing: 16,
      runSpacing: 16,
      children: [
        MetricCard(
          label: 'Current balance',
          value: formatMoney(
            piggyBank.balanceAmount,
            currencyCode: piggyBank.currencyCode,
          ),
          icon: Icons.account_balance_outlined,
          supportingText: 'From entries',
          width: null,
        ),
        MetricCard(
          label: 'Target progress',
          value: progress == null ? 'No target' : formatPercent(progress),
          icon: Icons.track_changes_outlined,
          supportingText: piggyBank.targetAmount == null
              ? 'Set a target to track'
              : 'Target ${formatMoney(piggyBank.targetAmount!, currencyCode: piggyBank.currencyCode)}',
          width: null,
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
          width: null,
        ),
      ],
    );
  }
}

class _VaultProgressBar extends StatelessWidget {
  const _VaultProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 12,
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
      ),
    );
  }
}

class _VaultDetailRow extends StatelessWidget {
  const _VaultDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyEntriesCard extends StatelessWidget {
  const _EmptyEntriesCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppContentCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: ShapeDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  shape: const OvalBorder(),
                ),
                child: Icon(
                  Icons.timeline_outlined,
                  color: theme.colorScheme.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No entries yet',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Deposits, withdrawals, and adjustments will appear here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryTimeline extends StatelessWidget {
  const _EntryTimeline({required this.entries});

  final List<PiggyBankEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const _EmptyEntriesCard();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeading(title: 'Entry timeline'),
        const SizedBox(height: 16),
        for (final entry in entries) ...[
          _EntryCard(entry: entry),
          const SizedBox(height: 12),
        ],
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
    final semanticColors = theme.extension<AppSemanticColors>();
    final signedAmount = entry.signedAmount;
    final amountColor = signedAmount < 0
        ? semanticColors?.negative ?? theme.colorScheme.error
        : semanticColors?.positive ?? theme.colorScheme.primary;
    final label = _entryLabel(entry.entryType);
    final amount = Text(
      formatSignedMoney(signedAmount),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(
        color: amountColor,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
    final leading = IconChip(
      icon: _entryIcon(entry.entryType),
      label: label,
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      foregroundColor: theme.colorScheme.onSurface,
      maxWidth: 180,
    );
    final details = Text(
      _entrySubtitle(entry),
      style: theme.textTheme.bodySmall,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    return AppContentCard(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacks =
              constraints.hasBoundedWidth && constraints.maxWidth < 420;
          if (stacks) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                const SizedBox(height: 12),
                details,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: amount),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leading,
              const SizedBox(width: 16),
              Expanded(child: details),
              const SizedBox(width: 16),
              amount,
            ],
          );
        },
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
      title: Text(widget.piggyBank == null ? 'Create vault' : 'Edit vault'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
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
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
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
