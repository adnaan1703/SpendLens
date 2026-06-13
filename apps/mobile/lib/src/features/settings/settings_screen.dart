import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../core/config/app_config.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/household_repository.dart';
import '../../shared/widgets/app_page.dart';
import '../auth/data/auth_repository.dart';
import '../activity/activity_screen.dart';
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
            _LabelManagerCard(householdId: householdContext.household.id),
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

class _LabelManagerCard extends ConsumerWidget {
  const _LabelManagerCard({required this.householdId});

  final String householdId;

  Future<void> _createLabel(BuildContext context, WidgetRef ref) async {
    final label = await showDialog<LabelOption>(
      context: context,
      builder: (context) {
        return _LabelNameDialog(
          title: 'Create label',
          actionLabel: 'Create',
          onSave: (name) {
            return ref
                .read(financeRepositoryProvider)
                .createHouseholdLabel(
                  LabelCreateRequest(householdId: householdId, name: name),
                );
          },
        );
      },
    );
    if (label == null) return;

    _refreshLabelLookups(ref, householdId);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Created ${label.name}')));
    }
  }

  Future<void> _renameLabel({
    required BuildContext context,
    required WidgetRef ref,
    required LabelOption label,
  }) async {
    final renamed = await showDialog<LabelOption>(
      context: context,
      builder: (context) {
        return _LabelNameDialog(
          title: 'Rename label',
          actionLabel: 'Save',
          initialName: label.name,
          onSave: (name) {
            return ref
                .read(financeRepositoryProvider)
                .renameHouseholdLabel(
                  LabelRenameRequest(
                    householdId: householdId,
                    labelId: label.id,
                    name: name,
                  ),
                );
          },
        );
      },
    );
    if (renamed == null) return;

    _refreshLabelLookups(ref, householdId);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Renamed ${renamed.name}')));
    }
  }

  Future<void> _deleteLabel({
    required BuildContext context,
    required WidgetRef ref,
    required LabelUsageSummary usage,
  }) async {
    final result = await _showLabelDeleteDialog(
      context: context,
      label: usage.label,
      transactionCount: usage.transactionCount,
      onDelete: () {
        return ref
            .read(financeRepositoryProvider)
            .deleteHouseholdLabel(
              LabelDeleteRequest(
                householdId: householdId,
                labelId: usage.label.id,
              ),
            );
      },
    );
    if (result == null) return;

    _refreshLabelLookups(ref, householdId);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted ${usage.label.name}; detached ${_countLabel(result.detachedTransactionCount, 'transaction')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final snapshot = ref.watch(labelManagerSnapshotProvider(householdId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SettingsSectionHeader(
              icon: Icons.label_outline,
              title: 'Labels',
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Refresh labels',
                    onPressed: () => _refreshLabelLookups(ref, householdId),
                    icon: const Icon(Icons.refresh),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: snapshot.isLoading
                        ? null
                        : () => _createLabel(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Create'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            switch (snapshot) {
              AsyncValue(:final value?) => _LabelManager(
                snapshot: value,
                onRename: (label) =>
                    _renameLabel(context: context, ref: ref, label: label),
                onDelete: (usage) =>
                    _deleteLabel(context: context, ref: ref, usage: usage),
              ),
              AsyncValue(hasError: true, :final error) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Labels unavailable', style: textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(error.toString(), style: textTheme.bodySmall),
                ],
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ],
        ),
      ),
    );
  }
}

class _LabelManager extends StatelessWidget {
  const _LabelManager({
    required this.snapshot,
    required this.onRename,
    required this.onDelete,
  });

  final LabelManagerSnapshot snapshot;
  final ValueChanged<LabelOption> onRename;
  final ValueChanged<LabelUsageSummary> onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (snapshot.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.label_outline,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text('No labels yet', style: textTheme.bodyMedium),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final usage in snapshot.labels) ...[
          _LabelUsageRow(
            usage: usage,
            onRename: () => onRename(usage.label),
            onDelete: () => onDelete(usage),
          ),
          if (usage != snapshot.labels.last) const Divider(height: 12),
        ],
      ],
    );
  }
}

class _LabelUsageRow extends StatelessWidget {
  const _LabelUsageRow({
    required this.usage,
    required this.onRename,
    required this.onDelete,
  });

  final LabelUsageSummary usage;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.label_outline),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usage.label.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  _labelUsageText(usage),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Rename label',
            onPressed: onRename,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete label',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
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
              AsyncValue(hasError: true, :final error) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Categories unavailable', style: textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(error.toString(), style: textTheme.bodySmall),
                ],
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text('No categories yet', style: textTheme.bodyMedium),
          ],
        ),
      );
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
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            onPressed: categories.length < 2
                ? null
                : () => _mergeCategories(context: context, ref: ref),
            icon: const Icon(Icons.merge_type_outlined),
            label: const Text('Merge'),
          ),
        ),
        const SizedBox(height: 8),
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
            onDelete: () => _deleteCategory(
              context: context,
              ref: ref,
              category: category,
              usage: snapshot.categoryUsage(category.id),
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
              onDelete: () => _deleteSubcategory(
                context: context,
                ref: ref,
                category: category,
                subcategory: subcategory,
                usage: snapshot.subcategoryUsage(subcategory.id),
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
              onViewTransactions: () =>
                  _openTransactions(context, selectedCategory.id),
            ),
          ],
          if (category != categories.last) const Divider(height: 12),
        ],
      ],
    );
  }

  Future<void> _mergeCategories({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final result = await showDialog<CategoryMergeResult>(
      context: context,
      builder: (context) {
        return _CategoryMergeDialog(
          householdId: householdId,
          snapshot: snapshot,
        );
      },
    );
    if (result == null) return;

    refreshCategoryLookups(ref, householdId);
    onCategorySelected(result.destinationCategory.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Merged into ${result.destinationCategory.name}; moved ${result.changedTransactionCount} transactions',
          ),
        ),
      );
    }
  }

  void _openTransactions(BuildContext context, String categoryId) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;

    router.go(
      Uri(
        path: ActivityScreen.routePath,
        queryParameters: {'categoryId': categoryId},
      ).toString(),
    );
  }

  Future<void> _deleteCategory({
    required BuildContext context,
    required WidgetRef ref,
    required CategoryOption category,
    required CategoryUsageSummary usage,
  }) async {
    onCategorySelected(category.id);
    final preview = await _loadDeletePreview(
      context: context,
      ref: ref,
      request: CategoryUsagePreviewRequest(
        householdId: householdId,
        categoryId: category.id,
      ),
    );
    if (preview == null || !context.mounted) return;

    final result = await _showTaxonomyDeleteDialog(
      context: context,
      title: 'Delete category',
      targetName: category.name,
      body:
          'Transactions keep their merchant and statement details, but category fields return to Review.',
      usage: usage,
      preview: preview,
      onDelete: () {
        return ref
            .read(financeRepositoryProvider)
            .deleteCategory(
              TaxonomyCategoryDeleteRequest(
                householdId: householdId,
                categoryId: category.id,
              ),
            );
      },
    );
    if (result == null) return;

    refreshCategoryLookups(ref, householdId);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted ${category.name}; requeued ${result.openedReviewItemCount} transactions',
          ),
        ),
      );
    }
  }

  Future<void> _deleteSubcategory({
    required BuildContext context,
    required WidgetRef ref,
    required CategoryOption category,
    required SubcategoryOption subcategory,
    required CategoryUsageSummary usage,
  }) async {
    onSubcategorySelected(category.id, subcategory.id);
    final preview = await _loadDeletePreview(
      context: context,
      ref: ref,
      request: CategoryUsagePreviewRequest(
        householdId: householdId,
        categoryId: category.id,
        subcategoryId: subcategory.id,
      ),
    );
    if (preview == null || !context.mounted) return;

    final result = await _showTaxonomyDeleteDialog(
      context: context,
      title: 'Delete subcategory',
      targetName: subcategory.name,
      body:
          'Transactions keep ${category.name} as their category, but subcategory fields return to Review.',
      usage: usage,
      preview: preview,
      onDelete: () {
        return ref
            .read(financeRepositoryProvider)
            .deleteSubcategory(
              TaxonomySubcategoryDeleteRequest(
                householdId: householdId,
                categoryId: category.id,
                subcategoryId: subcategory.id,
              ),
            );
      },
    );
    if (result == null) return;

    refreshCategoryLookups(ref, householdId);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted ${subcategory.name}; requeued ${result.openedReviewItemCount} transactions',
          ),
        ),
      );
    }
  }

  Future<CategoryUsagePreview?> _loadDeletePreview({
    required BuildContext context,
    required WidgetRef ref,
    required CategoryUsagePreviewRequest request,
  }) async {
    try {
      return await ref
          .read(financeRepositoryProvider)
          .fetchCategoryUsagePreview(request);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return null;
    }
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.usage,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final CategoryOption category;
  final CategoryUsageSummary usage;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      selected: isSelected,
      leading: const Icon(Icons.category_outlined),
      title: Text(category.name),
      subtitle: Text(_usageLabel(usage), style: textTheme.bodySmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Edit category',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete category',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
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
    required this.onDelete,
  });

  final SubcategoryOption subcategory;
  final CategoryUsageSummary usage;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit subcategory',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete subcategory',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
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
    required this.onViewTransactions,
  });

  final CategoryOption category;
  final SubcategoryOption? subcategory;
  final CategoryUsageSummary usage;
  final AsyncValue<CategoryUsagePreview> preview;
  final VoidCallback onViewTransactions;

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
            LayoutBuilder(
              builder: (context, constraints) {
                final summary = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(_usageLabel(usage), style: theme.textTheme.labelLarge),
                  ],
                );
                final button = FilledButton.tonalIcon(
                  onPressed: onViewTransactions,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('View transactions'),
                );

                if (constraints.maxWidth < 360) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      summary,
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerLeft, child: button),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: summary),
                    const SizedBox(width: 12),
                    button,
                  ],
                );
              },
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

Future<TaxonomyDeleteResult?> _showTaxonomyDeleteDialog({
  required BuildContext context,
  required String title,
  required String targetName,
  required String body,
  required CategoryUsageSummary usage,
  required CategoryUsagePreview preview,
  required Future<TaxonomyDeleteResult> Function() onDelete,
}) {
  return showDialog<TaxonomyDeleteResult>(
    context: context,
    builder: (dialogContext) {
      var isDeleting = false;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      targetName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(body),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ImpactChip(
                          icon: Icons.receipt_long_outlined,
                          label: _countLabel(
                            usage.transactionCount,
                            'transaction',
                          ),
                        ),
                        _ImpactChip(
                          icon: Icons.rule_folder_outlined,
                          label: _countLabel(
                            usage.activeMappingRuleCount,
                            'active rule',
                          ),
                        ),
                        _ImpactChip(
                          icon: Icons.savings_outlined,
                          label: _countLabel(usage.capCount, 'cap'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Recent transactions',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _RecentCategoryTransactions(
                      transactions: preview.recentTransactions,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isDeleting
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: isDeleting
                    ? null
                    : () async {
                        setDialogState(() {
                          isDeleting = true;
                        });

                        try {
                          final result = await onDelete();
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(result);
                          }
                        } catch (error) {
                          if (!dialogContext.mounted) return;

                          setDialogState(() {
                            isDeleting = false;
                          });
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      },
                icon: isDeleting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _LabelNameDialog extends StatefulWidget {
  const _LabelNameDialog({
    required this.title,
    required this.actionLabel,
    required this.onSave,
    this.initialName = '',
  });

  final String title;
  final String actionLabel;
  final String initialName;
  final Future<LabelOption> Function(String name) onSave;

  @override
  State<_LabelNameDialog> createState() => _LabelNameDialogState();
}

class _LabelNameDialogState extends State<_LabelNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.onSave(_controller.text.trim());
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const ValueKey('label-name-field'),
                controller: _controller,
                autofocus: true,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'Label name',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Label name is required';
                  }

                  return null;
                },
                onFieldSubmitted: (_) => _isSaving ? null : _save(),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
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
          label: Text(widget.actionLabel),
        ),
      ],
    );
  }
}

Future<LabelDeleteResult?> _showLabelDeleteDialog({
  required BuildContext context,
  required LabelOption label,
  required int transactionCount,
  required Future<LabelDeleteResult> Function() onDelete,
}) {
  return showDialog<LabelDeleteResult>(
    context: context,
    builder: (dialogContext) {
      var isDeleting = false;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Delete label'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    label.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ImpactChip(
                        icon: Icons.receipt_long_outlined,
                        label: _countLabel(transactionCount, 'transaction'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Deleting detaches this label from those transactions. Transactions stay intact.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isDeleting
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: isDeleting
                    ? null
                    : () async {
                        setDialogState(() {
                          isDeleting = true;
                        });

                        try {
                          final result = await onDelete();
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(result);
                          }
                        } catch (error) {
                          setDialogState(() {
                            isDeleting = false;
                          });
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        }
                      },
                icon: isDeleting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          );
        },
      );
    },
  );
}

const _newDestinationSubcategoryValue = '__new_destination_subcategory__';

class _CategoryMergeDialog extends ConsumerStatefulWidget {
  const _CategoryMergeDialog({
    required this.householdId,
    required this.snapshot,
  });

  final String householdId;
  final CategoryManagerSnapshot snapshot;

  @override
  ConsumerState<_CategoryMergeDialog> createState() =>
      _CategoryMergeDialogState();
}

class _CategoryMergeDialogState extends ConsumerState<_CategoryMergeDialog> {
  late String _destinationCategoryId;
  late final TextEditingController _destinationNameController;
  final _sourceCategoryIds = <String>{};
  final _mappings = <String, _MergeSubcategorySelection>{};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _destinationCategoryId = widget.snapshot.categories.first.id;
    _destinationNameController = TextEditingController(
      text: widget.snapshot.categories.first.name,
    );
  }

  @override
  void dispose() {
    _destinationNameController.dispose();
    super.dispose();
  }

  List<CategoryOption> get _sourceCategories {
    return widget.snapshot.categories
        .where((category) => _sourceCategoryIds.contains(category.id))
        .toList(growable: false);
  }

  List<SubcategoryOption> get _destinationSubcategories {
    return widget.snapshot.subcategories
        .where(
          (subcategory) => subcategory.categoryId == _destinationCategoryId,
        )
        .toList(growable: false);
  }

  List<SubcategoryOption> get _sourceSubcategories {
    return widget.snapshot.subcategories
        .where(
          (subcategory) => _sourceCategoryIds.contains(subcategory.categoryId),
        )
        .toList(growable: false);
  }

  String? get _validationMessage {
    if (_destinationNameController.text.trim().isEmpty) {
      return 'Destination category name is required.';
    }

    if (_sourceCategoryIds.isEmpty) {
      return 'Choose at least one source category.';
    }

    final destinationNames = {
      for (final subcategory in _destinationSubcategories)
        subcategory.name.trim().toLowerCase(),
    };

    for (final subcategory in _sourceSubcategories) {
      final mapping = _mappings[subcategory.id];
      if (mapping == null || !mapping.isMapped) {
        return 'Map every source subcategory.';
      }

      final newName = mapping.destinationSubcategoryName?.trim();
      if (newName == null) continue;

      final normalized = newName.toLowerCase();
      if (destinationNames.contains(normalized)) {
        return 'Duplicate destination subcategory names are not allowed.';
      }
      destinationNames.add(normalized);
    }

    return null;
  }

  void _selectDestination(String categoryId) {
    final category = widget.snapshot.categories
        .where((candidate) => candidate.id == categoryId)
        .first;
    setState(() {
      _destinationCategoryId = category.id;
      _destinationNameController.text = category.name;
      _sourceCategoryIds.remove(category.id);
      _mappings.clear();
    });
  }

  void _toggleSource(CategoryOption category, bool selected) {
    setState(() {
      if (selected) {
        _sourceCategoryIds.add(category.id);
        return;
      }

      _sourceCategoryIds.remove(category.id);
      for (final subcategory in widget.snapshot.subcategories.where(
        (subcategory) => subcategory.categoryId == category.id,
      )) {
        _mappings.remove(subcategory.id);
      }
    });
  }

  void _mapToExisting(SubcategoryOption source, String destinationId) {
    setState(() {
      _mappings[source.id] = _MergeSubcategorySelection(
        destinationSubcategoryId: destinationId,
      );
    });
  }

  void _mapToNew(SubcategoryOption source, String name) {
    setState(() {
      _mappings[source.id] = _MergeSubcategorySelection(
        destinationSubcategoryName: name,
      );
    });
  }

  Future<void> _save() async {
    if (_validationMessage != null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await ref
          .read(financeRepositoryProvider)
          .mergeCategories(
            CategoryMergeRequest(
              householdId: widget.householdId,
              destinationCategoryId: _destinationCategoryId,
              destinationCategoryName: _destinationNameController.text.trim(),
              sourceCategoryIds: [
                for (final category in widget.snapshot.categories)
                  if (_sourceCategoryIds.contains(category.id)) category.id,
              ],
              subcategoryMappings: [
                for (final subcategory in _sourceSubcategories)
                  CategoryMergeSubcategoryMapping(
                    sourceSubcategoryId: subcategory.id,
                    destinationSubcategoryId:
                        _mappings[subcategory.id]!.destinationSubcategoryId,
                    destinationSubcategoryName: _mappings[subcategory.id]!
                        .destinationSubcategoryName
                        ?.trim(),
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
    final theme = Theme.of(context);
    final sourceUsage = _sourceCategories.fold<CategoryUsageSummary>(
      CategoryUsageSummary.empty('merge'),
      (total, category) {
        final usage = widget.snapshot.categoryUsage(category.id);
        return CategoryUsageSummary(
          id: 'merge',
          transactionCount: total.transactionCount + usage.transactionCount,
          netSpend: total.netSpend + usage.netSpend,
          activeMappingRuleCount:
              total.activeMappingRuleCount + usage.activeMappingRuleCount,
          capCount: total.capCount + usage.capCount,
        );
      },
    );
    final validationMessage = _validationMessage;

    return AlertDialog(
      title: const Text('Merge categories'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: const ValueKey('category-merge-destination'),
                initialValue: _destinationCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Destination category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  for (final category in widget.snapshot.categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: _isSaving || widget.snapshot.categories.length < 2
                    ? null
                    : (value) {
                        if (value == null) return;
                        _selectDestination(value);
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('category-merge-name'),
                controller: _destinationNameController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'Surviving category name',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Text('Source categories', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final category in widget.snapshot.categories.where(
                (category) => category.id != _destinationCategoryId,
              ))
                CheckboxListTile(
                  key: ValueKey('category-merge-source-${category.id}'),
                  contentPadding: EdgeInsets.zero,
                  value: _sourceCategoryIds.contains(category.id),
                  onChanged: _isSaving
                      ? null
                      : (value) => _toggleSource(category, value ?? false),
                  title: Text(category.name),
                  subtitle: Text(
                    _usageLabel(widget.snapshot.categoryUsage(category.id)),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ImpactChip(
                    icon: Icons.receipt_long_outlined,
                    label: _countLabel(
                      sourceUsage.transactionCount,
                      'transaction',
                    ),
                  ),
                  _ImpactChip(
                    icon: Icons.currency_rupee,
                    label: formatMoney(sourceUsage.netSpend),
                  ),
                  _ImpactChip(
                    icon: Icons.rule_folder_outlined,
                    label: _countLabel(
                      sourceUsage.activeMappingRuleCount,
                      'active rule',
                    ),
                  ),
                  _ImpactChip(
                    icon: Icons.savings_outlined,
                    label: _countLabel(sourceUsage.capCount, 'cap'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Subcategory mapping', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (_sourceSubcategories.isEmpty)
                Text(
                  'Selected source categories have no subcategories to map.',
                  style: theme.textTheme.bodySmall,
                )
              else
                for (final subcategory in _sourceSubcategories) ...[
                  _SubcategoryMappingRow(
                    destinationCategoryId: _destinationCategoryId,
                    sourceCategory: widget.snapshot.categories
                        .where(
                          (category) => category.id == subcategory.categoryId,
                        )
                        .first,
                    sourceSubcategory: subcategory,
                    destinationSubcategories: _destinationSubcategories,
                    selection: _mappings[subcategory.id],
                    isSaving: _isSaving,
                    onExistingSelected: (destinationId) =>
                        _mapToExisting(subcategory, destinationId),
                    onNewNameChanged: (name) => _mapToNew(subcategory, name),
                    onNewSelected: () => _mapToNew(
                      subcategory,
                      _mappings[subcategory.id]?.destinationSubcategoryName ??
                          '',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              if (_sourceCategories.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Recent transaction examples',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                for (final category in _sourceCategories) ...[
                  Text(category.name, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  _MergeSourceRecentTransactions(
                    request: CategoryUsagePreviewRequest(
                      householdId: widget.householdId,
                      categoryId: category.id,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              if (validationMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  validationMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving || validationMessage != null ? null : _save,
          icon: _isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.merge_type_outlined),
          label: const Text('Save'),
        ),
      ],
    );
  }
}

class _SubcategoryMappingRow extends StatelessWidget {
  const _SubcategoryMappingRow({
    required this.destinationCategoryId,
    required this.sourceCategory,
    required this.sourceSubcategory,
    required this.destinationSubcategories,
    required this.selection,
    required this.isSaving,
    required this.onExistingSelected,
    required this.onNewNameChanged,
    required this.onNewSelected,
  });

  final String destinationCategoryId;
  final CategoryOption sourceCategory;
  final SubcategoryOption sourceSubcategory;
  final List<SubcategoryOption> destinationSubcategories;
  final _MergeSubcategorySelection? selection;
  final bool isSaving;
  final ValueChanged<String> onExistingSelected;
  final ValueChanged<String> onNewNameChanged;
  final VoidCallback onNewSelected;

  @override
  Widget build(BuildContext context) {
    final selectedValue = selection?.dropdownValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(
            'category-merge-map-$destinationCategoryId-${sourceSubcategory.id}',
          ),
          initialValue: selectedValue,
          decoration: InputDecoration(
            labelText: '${sourceCategory.name} / ${sourceSubcategory.name}',
            prefixIcon: const Icon(Icons.sell_outlined),
          ),
          items: [
            for (final subcategory in destinationSubcategories)
              DropdownMenuItem(
                value: subcategory.id,
                child: Text(subcategory.name),
              ),
            const DropdownMenuItem(
              value: _newDestinationSubcategoryValue,
              child: Text('New subcategory'),
            ),
          ],
          onChanged: isSaving
              ? null
              : (value) {
                  if (value == null) return;
                  if (value == _newDestinationSubcategoryValue) {
                    onNewSelected();
                    return;
                  }

                  onExistingSelected(value);
                },
        ),
        if (selection?.isNew ?? false) ...[
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('category-merge-new-${sourceSubcategory.id}'),
            initialValue: selection?.destinationSubcategoryName ?? '',
            enabled: !isSaving,
            decoration: const InputDecoration(
              labelText: 'New destination subcategory',
              prefixIcon: Icon(Icons.add),
            ),
            onChanged: onNewNameChanged,
          ),
        ],
      ],
    );
  }
}

class _MergeSourceRecentTransactions extends ConsumerWidget {
  const _MergeSourceRecentTransactions({required this.request});

  final CategoryUsagePreviewRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(categoryUsagePreviewProvider(request));

    return switch (preview) {
      AsyncValue(:final value?) => _RecentCategoryTransactions(
        transactions: value.recentTransactions.take(3).toList(growable: false),
      ),
      AsyncValue(hasError: true, :final error) => Text(
        error.toString(),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

final class _MergeSubcategorySelection {
  const _MergeSubcategorySelection({
    this.destinationSubcategoryId,
    this.destinationSubcategoryName,
  });

  final String? destinationSubcategoryId;
  final String? destinationSubcategoryName;

  bool get isNew => destinationSubcategoryName != null;

  bool get isMapped {
    if (destinationSubcategoryId != null) return true;

    return (destinationSubcategoryName ?? '').trim().isNotEmpty;
  }

  String? get dropdownValue {
    if (destinationSubcategoryId != null) return destinationSubcategoryId;
    if (isNew) return _newDestinationSubcategoryValue;

    return null;
  }
}

class _ImpactChip extends StatelessWidget {
  const _ImpactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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

String _countLabel(int count, String singular) {
  return count == 1 ? '1 $singular' : '$count ${singular}s';
}

String _labelUsageText(LabelUsageSummary usage) {
  final countLabel = _countLabel(usage.transactionCount, 'transaction');
  final recent = usage.recentUsedAt;
  if (recent == null) return countLabel;

  return '$countLabel - last used ${dateString(recent)}';
}

void _refreshLabelLookups(WidgetRef ref, String householdId) {
  ref.invalidate(labelManagerSnapshotProvider(householdId));
  ref.invalidate(transactionLabelsProvider(householdId));
  ref.invalidate(transactionsProvider);
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
