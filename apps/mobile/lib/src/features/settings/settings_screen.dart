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

class _CategoryManagerCard extends ConsumerStatefulWidget {
  const _CategoryManagerCard({required this.householdId});

  final String householdId;

  @override
  ConsumerState<_CategoryManagerCard> createState() =>
      _CategoryManagerCardState();
}

class _CategoryManagerCardState extends ConsumerState<_CategoryManagerCard> {
  String? _selectedCategoryId;
  String? _selectedSubcategoryId;

  Future<void> _createCategory() async {
    final result = await showCategoryCreationDialog(
      context: context,
      ref: ref,
      householdId: widget.householdId,
    );
    if (result == null) return;

    refreshCategoryLookups(ref, widget.householdId);

    setState(() {
      _selectedCategoryId = result.category.id;
      _selectedSubcategoryId = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created ${result.category.name}')),
      );
    }
  }

  Future<void> _editCategory({
    required CategoryOption category,
    required List<SubcategoryOption> subcategories,
  }) async {
    final result = await showDialog<CategoryTaxonomyUpdateResult>(
      context: context,
      builder: (context) {
        return _CategoryTaxonomyDialog(
          householdId: widget.householdId,
          category: category,
          subcategories: subcategories,
        );
      },
    );
    if (result == null) return;

    refreshCategoryLookups(ref, widget.householdId);

    setState(() {
      _selectedCategoryId = result.category.id;
      _selectedSubcategoryId = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated ${result.category.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final snapshot = ref.watch(
      categoryManagerSnapshotProvider(widget.householdId),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SettingsSectionHeader(
              icon: Icons.category_outlined,
              title: 'Categories',
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () =>
                        refreshCategoryLookups(ref, widget.householdId),
                    icon: const Icon(Icons.refresh),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: snapshot.isLoading ? null : _createCategory,
                    icon: const Icon(Icons.add),
                    label: const Text('Create'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            switch (snapshot) {
              AsyncValue(:final value?) => _CategoryManager(
                snapshot: value,
                selectedCategoryId: _selectedCategoryId,
                selectedSubcategoryId: _selectedSubcategoryId,
                householdId: widget.householdId,
                onCategorySelected: (categoryId) {
                  setState(() {
                    _selectedCategoryId = categoryId;
                    _selectedSubcategoryId = null;
                  });
                },
                onSubcategorySelected: (categoryId, subcategoryId) {
                  setState(() {
                    _selectedCategoryId = categoryId;
                    _selectedSubcategoryId = subcategoryId;
                  });
                },
                onEditCategory: (category, subcategories) {
                  _editCategory(
                    category: category,
                    subcategories: subcategories,
                  );
                },
              ),
              AsyncValue(hasError: true, :final error) => Text(
                error.toString(),
                style: textTheme.bodySmall,
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ],
        ),
      ),
    );
  }
}

class _CategoryManager extends ConsumerWidget {
  const _CategoryManager({
    required this.snapshot,
    required this.selectedCategoryId,
    required this.selectedSubcategoryId,
    required this.householdId,
    required this.onCategorySelected,
    required this.onSubcategorySelected,
    required this.onEditCategory,
  });

  final CategoryManagerSnapshot snapshot;
  final String? selectedCategoryId;
  final String? selectedSubcategoryId;
  final String householdId;
  final ValueChanged<String> onCategorySelected;
  final void Function(String categoryId, String subcategoryId)
  onSubcategorySelected;
  final void Function(
    CategoryOption category,
    List<SubcategoryOption> subcategories,
  )
  onEditCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final categories = snapshot.categories;
    final subcategories = snapshot.subcategories;

    if (categories.isEmpty) {
      return Text('No categories', style: textTheme.bodyMedium);
    }

    final selectedCategory =
        categories
            .where((category) => category.id == selectedCategoryId)
            .firstOrNull ??
        categories.first;
    final selectedSubcategory = subcategories
        .where(
          (subcategory) =>
              subcategory.id == selectedSubcategoryId &&
              subcategory.categoryId == selectedCategory.id,
        )
        .firstOrNull;
    final previewRequest = CategoryUsagePreviewRequest(
      householdId: householdId,
      categoryId: selectedCategory.id,
      subcategoryId: selectedSubcategory?.id,
    );
    final preview = ref.watch(categoryUsagePreviewProvider(previewRequest));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final category in categories) ...[
          _CategoryRow(
            category: category,
            usage: snapshot.categoryUsage(category.id),
            isSelected:
                selectedCategory.id == category.id &&
                selectedSubcategory == null,
            onTap: () => onCategorySelected(category.id),
            onEdit: () => onEditCategory(
              category,
              subcategories
                  .where((subcategory) => subcategory.categoryId == category.id)
                  .toList(growable: false),
            ),
          ),
          for (final subcategory in subcategories.where(
            (subcategory) => subcategory.categoryId == category.id,
          ))
            _SubcategoryRow(
              subcategory: subcategory,
              usage: snapshot.subcategoryUsage(subcategory.id),
              isSelected: selectedSubcategory?.id == subcategory.id,
              onTap: () => onSubcategorySelected(category.id, subcategory.id),
              onEdit: () => onEditCategory(
                category,
                subcategories
                    .where((candidate) => candidate.categoryId == category.id)
                    .toList(growable: false),
              ),
            ),
          if (selectedCategory.id == category.id) ...[
            const SizedBox(height: 8),
            _CategoryUsagePanel(
              category: selectedCategory,
              subcategory: selectedSubcategory,
              usage: selectedSubcategory == null
                  ? snapshot.categoryUsage(selectedCategory.id)
                  : snapshot.subcategoryUsage(selectedSubcategory.id),
              preview: preview,
            ),
          ],
          if (category != categories.last) const Divider(height: 12),
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.usage,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
  });

  final CategoryOption category;
  final CategoryUsageSummary usage;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      selected: isSelected,
      leading: const Icon(Icons.category_outlined),
      title: Text(category.name),
      subtitle: Text(_usageLabel(usage), style: textTheme.bodySmall),
      trailing: IconButton(
        tooltip: 'Edit category',
        onPressed: onEdit,
        icon: const Icon(Icons.edit_outlined),
      ),
      onTap: onTap,
    );
  }
}

class _SubcategoryRow extends StatelessWidget {
  const _SubcategoryRow({
    required this.subcategory,
    required this.usage,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
  });

  final SubcategoryOption subcategory;
  final CategoryUsageSummary usage;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        selected: isSelected,
        leading: const Icon(Icons.sell_outlined, size: 20),
        title: Text(subcategory.name),
        subtitle: Text(_usageLabel(usage), style: textTheme.bodySmall),
        trailing: IconButton(
          tooltip: 'Edit subcategory',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _CategoryUsagePanel extends StatelessWidget {
  const _CategoryUsagePanel({
    required this.category,
    required this.subcategory,
    required this.usage,
    required this.preview,
  });

  final CategoryOption category;
  final SubcategoryOption? subcategory;
  final CategoryUsageSummary usage;
  final AsyncValue<CategoryUsagePreview> preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = subcategory?.name ?? category.name;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
                Text(_usageLabel(usage), style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 12),
            switch (preview) {
              AsyncValue(:final value?) => _RecentCategoryTransactions(
                transactions: value.recentTransactions,
              ),
              AsyncValue(hasError: true, :final error) => Text(
                error.toString(),
                style: theme.textTheme.bodySmall,
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ],
        ),
      ),
    );
  }
}

class _RecentCategoryTransactions extends StatelessWidget {
  const _RecentCategoryTransactions({required this.transactions});

  final List<FinanceTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (transactions.isEmpty) {
      return Text('No recent transactions', style: textTheme.bodySmall);
    }

    return Column(
      children: [
        for (final transaction in transactions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.merchantName ??
                            transaction.statementMerchant,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [
                          dateString(transaction.transactionDate),
                          transaction.categoryName ?? 'Uncategorized',
                          transaction.subcategoryName ?? 'Uncategorized',
                        ].join(' - '),
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(formatMoney(transaction.netExpense)),
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryTaxonomyDialog extends ConsumerStatefulWidget {
  const _CategoryTaxonomyDialog({
    required this.householdId,
    required this.category,
    required this.subcategories,
  });

  final String householdId;
  final CategoryOption category;
  final List<SubcategoryOption> subcategories;

  @override
  ConsumerState<_CategoryTaxonomyDialog> createState() =>
      _CategoryTaxonomyDialogState();
}

class _CategoryTaxonomyDialogState
    extends ConsumerState<_CategoryTaxonomyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _categoryController;
  late final List<_SubcategoryField> _subcategoryFields;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _categoryController = TextEditingController(text: widget.category.name);
    _subcategoryFields = [
      for (final subcategory in widget.subcategories)
        _SubcategoryField(
          id: subcategory.id,
          controller: TextEditingController(text: subcategory.name),
        ),
    ];
  }

  @override
  void dispose() {
    _categoryController.dispose();
    for (final field in _subcategoryFields) {
      field.controller.dispose();
    }
    super.dispose();
  }

  void _addSubcategory() {
    setState(() {
      _subcategoryFields.add(
        _SubcategoryField(controller: TextEditingController()),
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await ref
          .read(financeRepositoryProvider)
          .updateCategoryTaxonomy(
            CategoryTaxonomyUpdateRequest(
              householdId: widget.householdId,
              categoryId: widget.category.id,
              categoryName: _categoryController.text.trim(),
              subcategories: [
                for (final field in _subcategoryFields)
                  if (field.id != null ||
                      field.controller.text.trim().isNotEmpty)
                    CategoryTaxonomySubcategoryDraft(
                      id: field.id,
                      name: field.controller.text.trim(),
                    ),
              ],
            ),
          );

      if (mounted) {
        Navigator.of(context).pop(result);
      }
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit category'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('category-taxonomy-name'),
                  controller: _categoryController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Category name',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Category name is required';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                for (var index = 0; index < _subcategoryFields.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      key: ValueKey(
                        'subcategory-taxonomy-${_subcategoryFields[index].id ?? 'new-$index'}',
                      ),
                      controller: _subcategoryFields[index].controller,
                      decoration: InputDecoration(
                        labelText: 'Subcategory ${index + 1}',
                        prefixIcon: const Icon(Icons.sell_outlined),
                      ),
                      validator: (value) {
                        if (_subcategoryFields[index].id != null &&
                            (value ?? '').trim().isEmpty) {
                          return 'Subcategory name is required';
                        }

                        return null;
                      },
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _isSaving ? null : _addSubcategory,
                    icon: const Icon(Icons.add),
                    label: const Text('Add subcategory'),
                  ),
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
              : const Icon(Icons.save_outlined),
          label: const Text('Save'),
        ),
      ],
    );
  }
}

final class _SubcategoryField {
  const _SubcategoryField({this.id, required this.controller});

  final String? id;
  final TextEditingController controller;
}

String _usageLabel(CategoryUsageSummary usage) {
  final countLabel = usage.transactionCount == 1
      ? '1 transaction'
      : '${usage.transactionCount} transactions';
  return '$countLabel - ${formatMoney(usage.netSpend)}';
}

extension _SettingsFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;

    return null;
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
