import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../core/config/app_config.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/household_repository.dart';
import '../../shared/widgets/app_page.dart';
import '../auth/data/auth_repository.dart';
import '../categories/category_creation_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const routePath = '/settings';

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    try {
      await ref.read(authRepositoryProvider).signOut();
      ref.invalidate(householdContextProvider);
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final bootstrap = ref.watch(appBootstrapProvider);
    final householdContext = ref.watch(householdContextProvider).value;
    final session = ref.watch(authSessionProvider).value;

    return AppPage(
      title: 'Settings',
      subtitle: 'Account and runtime',
      actions: [
        FilledButton.tonalIcon(
          onPressed: _isSigningOut ? null : _signOut,
          icon: _isSigningOut
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout),
          label: Text(_isSigningOut ? 'Signing out...' : 'Sign out'),
        ),
      ],
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _SettingsRow(
                    label: 'Signed in as',
                    value:
                        householdContext?.profile.email ??
                        session?.user.email ??
                        'Unknown user',
                  ),
                  const Divider(height: 28),
                  _SettingsRow(
                    label: 'Household',
                    value: householdContext?.household.name ?? 'Loading',
                  ),
                  const Divider(height: 28),
                  _SettingsRow(
                    label: 'Role',
                    value: householdContext?.memberRole ?? 'Loading',
                  ),
                ],
              ),
            ),
          ),
          if (householdContext != null) ...[
            const SizedBox(height: 16),
            _CategoryManagerCard(householdId: householdContext.household.id),
            const SizedBox(height: 16),
            _GmailConnectorCard(householdId: householdContext.household.id),
            const SizedBox(height: 16),
            _AiSettingsCard(householdId: householdContext.household.id),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _SettingsRow(
                    label: 'Environment',
                    value: config.environment.label,
                  ),
                  const Divider(height: 28),
                  const _SettingsRow(
                    label: 'Android package',
                    value: AppConfig.androidPackageName,
                  ),
                  const Divider(height: 28),
                  _SettingsRow(
                    label: 'Auth redirect',
                    value: config.authRedirectUrl,
                  ),
                  const Divider(height: 28),
                  _SettingsRow(
                    label: 'Supabase',
                    value: switch (bootstrap.supabaseStatus) {
                      SupabaseStatus.ready => 'Ready',
                      SupabaseStatus.failed => 'Error',
                      SupabaseStatus.notConfigured => 'Not configured',
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiSettingsCard extends ConsumerWidget {
  const _AiSettingsCard({required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final status = ref.watch(aiBudgetStatusProvider(householdId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: status.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsSectionHeader(
                icon: Icons.auto_awesome_outlined,
                title: 'AI',
                action: IconButton(
                  tooltip: 'Refresh',
                  onPressed: () =>
                      ref.invalidate(aiBudgetStatusProvider(householdId)),
                  icon: const Icon(Icons.refresh),
                ),
              ),
              const SizedBox(height: 12),
              Text('AI status unavailable', style: textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(error.toString(), style: textTheme.bodySmall),
            ],
          ),
          data: (ai) => Column(
            children: [
              _SettingsSectionHeader(
                icon: Icons.auto_awesome,
                title: 'AI',
                action: IconButton(
                  tooltip: 'Refresh',
                  onPressed: () =>
                      ref.invalidate(aiBudgetStatusProvider(householdId)),
                  icon: const Icon(Icons.refresh),
                ),
              ),
              const SizedBox(height: 16),
              _SettingsRow(label: 'Provider', value: ai.provider),
              const Divider(height: 28),
              _SettingsRow(label: 'Model', value: ai.model),
              const Divider(height: 28),
              _SettingsRow(label: 'Mode', value: ai.modeLabel),
              const Divider(height: 28),
              _SettingsRow(
                label: 'Monthly cap',
                value: '\$${ai.monthlySpendCapUsd.toStringAsFixed(2)}',
              ),
              const Divider(height: 28),
              _SettingsRow(
                label: 'Current usage',
                value:
                    '${ai.currentMonthEventCount} calls / \$${ai.currentMonthSpendUsd.toStringAsFixed(4)}',
              ),
              const Divider(height: 28),
              _SettingsRow(
                label: 'Metadata Suggest search',
                value: ai.transactionMetadataSuggestionSearchLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryManagerCard extends ConsumerWidget {
  const _CategoryManagerCard({required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final categories = ref.watch(transactionCategoriesProvider(householdId));
    final subcategories = ref.watch(merchantSubcategoriesProvider(householdId));

    Future<void> createCategory() async {
      final result = await showCategoryCreationDialog(
        context: context,
        ref: ref,
        householdId: householdId,
      );
      if (result == null) return;

      refreshCategoryLookups(ref, householdId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created ${result.category.name}')),
        );
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SettingsSectionHeader(
              icon: Icons.category_outlined,
              title: 'Categories',
              action: FilledButton.tonalIcon(
                onPressed: categories.isLoading || subcategories.isLoading
                    ? null
                    : createCategory,
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
            ),
            const SizedBox(height: 16),
            if (categories.isLoading || subcategories.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (categories.hasError)
              Text(categories.error.toString(), style: textTheme.bodySmall)
            else if (subcategories.hasError)
              Text(subcategories.error.toString(), style: textTheme.bodySmall)
            else
              _CategoryList(
                categories: categories.value ?? const [],
                subcategories: subcategories.value ?? const [],
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories, required this.subcategories});

  final List<CategoryOption> categories;
  final List<SubcategoryOption> subcategories;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (categories.isEmpty) {
      return Text('No categories', style: textTheme.bodyMedium);
    }

    return Column(
      children: [
        for (final category in categories) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.category_outlined),
            title: Text(category.name),
            subtitle: _SubcategoryWrap(
              subcategories: subcategories
                  .where((subcategory) => subcategory.categoryId == category.id)
                  .toList(growable: false),
            ),
          ),
          if (category != categories.last) const Divider(height: 12),
        ],
      ],
    );
  }
}

class _SubcategoryWrap extends StatelessWidget {
  const _SubcategoryWrap({required this.subcategories});

  final List<SubcategoryOption> subcategories;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (subcategories.isEmpty) {
      return Text('No subcategories', style: textTheme.bodySmall);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final subcategory in subcategories)
            Chip(
              avatar: const Icon(Icons.sell_outlined, size: 18),
              label: Text(subcategory.name),
            ),
        ],
      ),
    );
  }
}

class _GmailConnectorCard extends ConsumerStatefulWidget {
  const _GmailConnectorCard({required this.householdId});

  final String householdId;

  @override
  ConsumerState<_GmailConnectorCard> createState() =>
      _GmailConnectorCardState();
}

class _GmailConnectorCardState extends ConsumerState<_GmailConnectorCard> {
  bool _isConnecting = false;
  String? _disconnectingMailboxId;

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
    });

    try {
      final authorizationUrl = await ref
          .read(financeRepositoryProvider)
          .startGmailConnector(householdId: widget.householdId);
      final launched = await launchUrl(
        Uri.parse(authorizationUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('Could not open Google authorization.');
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
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _disconnect(String mailboxId) async {
    setState(() {
      _disconnectingMailboxId = mailboxId;
    });

    try {
      await ref
          .read(financeRepositoryProvider)
          .disconnectGmailMailbox(mailboxId: mailboxId);
      ref.invalidate(gmailConnectorStatusProvider(widget.householdId));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _disconnectingMailboxId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = ref.watch(gmailConnectorStatusProvider(widget.householdId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: status.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsSectionHeader(
                icon: Icons.mark_email_unread_outlined,
                title: 'Gmail connector',
                action: IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => ref.invalidate(
                    gmailConnectorStatusProvider(widget.householdId),
                  ),
                  icon: const Icon(Icons.refresh),
                ),
              ),
              const SizedBox(height: 12),
              Text('Connector status unavailable', style: textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(error.toString(), style: textTheme.bodySmall),
            ],
          ),
          data: (mailboxes) {
            final activeMailboxes = mailboxes
                .where((mailbox) => mailbox.isActive)
                .toList();
            final mailbox = activeMailboxes.firstOrNull;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SettingsSectionHeader(
                  icon: Icons.mark_email_read_outlined,
                  title: 'Gmail connector',
                  action: IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => ref.invalidate(
                      gmailConnectorStatusProvider(widget.householdId),
                    ),
                    icon: const Icon(Icons.refresh),
                  ),
                ),
                const SizedBox(height: 16),
                if (mailbox == null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _isConnecting ? null : _connect,
                      icon: _isConnecting
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_link),
                      label: Text(
                        _isConnecting ? 'Opening...' : 'Connect Gmail',
                      ),
                    ),
                  )
                else ...[
                  _SettingsRow(label: 'Mailbox', value: mailbox.email),
                  const Divider(height: 28),
                  _SettingsRow(label: 'Status', value: mailbox.displayStatus),
                  const Divider(height: 28),
                  _SettingsRow(
                    label: 'Watch expires',
                    value: _formatDateTime(mailbox.watchExpiresAt),
                  ),
                  const Divider(height: 28),
                  _SettingsRow(
                    label: 'Last sync',
                    value: _formatDateTime(mailbox.lastSyncAt),
                  ),
                  if (mailbox.queuedJobCount > 0) ...[
                    const Divider(height: 28),
                    _SettingsRow(
                      label: 'Queued jobs',
                      value: mailbox.queuedJobCount.toString(),
                    ),
                  ],
                  if ((mailbox.lastError ?? mailbox.latestJobError) !=
                      null) ...[
                    const Divider(height: 28),
                    _SettingsRow(
                      label: 'Last error',
                      value: mailbox.lastError ?? mailbox.latestJobError!,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _disconnectingMailboxId == mailbox.id
                          ? null
                          : () => _disconnect(mailbox.id),
                      icon: _disconnectingMailboxId == mailbox.id
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.link_off),
                      label: Text(
                        _disconnectingMailboxId == mailbox.id
                            ? 'Disconnecting...'
                            : 'Disconnect',
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({
    required this.icon,
    required this.title,
    this.action,
  });

  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: textTheme.titleMedium)),
        ?action,
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(child: Text(label, style: textTheme.labelLarge)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

String _formatDateTime(DateTime? value) {
  if (value == null) return 'None';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
