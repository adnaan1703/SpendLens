import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/household_repository.dart';
import '../../shared/widgets/app_primitives.dart';
import '../transaction_metadata/transaction_metadata_editor.dart';
import '../settings/settings_screen.dart';

class MerchantReviewScreen extends ConsumerStatefulWidget {
  const MerchantReviewScreen({super.key});

  static const routePath = '/merchant-review';

  @override
  ConsumerState<MerchantReviewScreen> createState() =>
      _MerchantReviewScreenState();
}

class _MerchantReviewScreenState extends ConsumerState<MerchantReviewScreen> {
  static const _parseFailurePageLimit =
      GmailParseFailurePageRequest.defaultLimit;

  String? _parseFailureHouseholdId;
  var _parseFailures = <GmailParseFailure>[];
  var _nextParseFailureOffset = 0;
  var _hasMoreParseFailures = false;
  var _isLoadingInitialParseFailures = false;
  var _isLoadingMoreParseFailures = false;
  Object? _parseFailureError;
  Object? _loadMoreParseFailureError;

  @override
  Widget build(BuildContext context) {
    final householdContext = ref.watch(householdContextProvider).value;
    final householdId = householdContext?.household.id;
    final reviewItems = householdId == null
        ? const AsyncValue<List<MerchantReviewItem>>.loading()
        : ref.watch(merchantReviewQueueProvider(householdId));
    _ensureParseFailuresLoadedFor(householdId);
    final categories = householdId == null
        ? const AsyncValue<List<CategoryOption>>.loading()
        : ref.watch(transactionCategoriesProvider(householdId));
    final subcategories = householdId == null
        ? const AsyncValue<List<SubcategoryOption>>.loading()
        : ref.watch(merchantSubcategoriesProvider(householdId));

    return _MerchantReviewPage(
      reviewItems: reviewItems,
      parseFailures: _GmailParseFailuresViewState(
        items: _parseFailures,
        isInitialLoading: _isLoadingInitialParseFailures,
        initialError: _parseFailureError,
        hasMore: _hasMoreParseFailures,
        isLoadingMore: _isLoadingMoreParseFailures,
        loadMoreError: _loadMoreParseFailureError,
      ),
      categories: categories,
      subcategories: subcategories,
      onRefresh: householdId == null
          ? null
          : () {
              ref.invalidate(merchantReviewQueueProvider(householdId));
              _loadFirstParseFailurePage(householdId);
            },
      onRetryParseFailures: householdId == null
          ? null
          : () => _loadFirstParseFailurePage(householdId),
      onLoadMoreParseFailures: householdId == null
          ? null
          : () => _loadMoreParseFailures(householdId),
      onViewParseFailureBody: householdContext == null
          ? null
          : (failure) {
              _showParseFailureBodyDialog(context: context, failure: failure);
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
      onIgnoreParseFailure: householdContext == null
          ? null
          : (failure) {
              _ignoreParseFailure(
                context: context,
                ref: ref,
                householdId: householdContext.household.id,
                failure: failure,
              );
            },
    );
  }

  void _ensureParseFailuresLoadedFor(String? householdId) {
    if (householdId == null) {
      if (_parseFailureHouseholdId != null) {
        _parseFailureHouseholdId = null;
        _parseFailures = [];
        _nextParseFailureOffset = 0;
        _hasMoreParseFailures = false;
        _isLoadingInitialParseFailures = false;
        _isLoadingMoreParseFailures = false;
        _parseFailureError = null;
        _loadMoreParseFailureError = null;
      }
      return;
    }

    if (_parseFailureHouseholdId == householdId) return;

    _parseFailureHouseholdId = householdId;
    _parseFailures = [];
    _nextParseFailureOffset = 0;
    _hasMoreParseFailures = false;
    _isLoadingInitialParseFailures = true;
    _isLoadingMoreParseFailures = false;
    _parseFailureError = null;
    _loadMoreParseFailureError = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _parseFailureHouseholdId != householdId) return;
      _loadFirstParseFailurePage(householdId);
    });
  }

  Future<void> _loadFirstParseFailurePage(String householdId) async {
    setState(() {
      _parseFailureHouseholdId = householdId;
      _isLoadingInitialParseFailures = true;
      _isLoadingMoreParseFailures = false;
      _parseFailureError = null;
      _loadMoreParseFailureError = null;
    });

    try {
      final page = await ref
          .read(financeRepositoryProvider)
          .fetchGmailParseFailurePage(
            GmailParseFailurePageRequest(
              householdId: householdId,
              limit: _parseFailurePageLimit,
            ),
          );
      if (!mounted || _parseFailureHouseholdId != householdId) return;

      setState(() {
        _parseFailures = page.items;
        _nextParseFailureOffset = page.nextOffset;
        _hasMoreParseFailures = page.hasMore;
        _isLoadingInitialParseFailures = false;
      });
    } catch (error) {
      if (!mounted || _parseFailureHouseholdId != householdId) return;

      setState(() {
        _parseFailureError = error;
        _isLoadingInitialParseFailures = false;
      });
    }
  }

  Future<void> _loadMoreParseFailures(String householdId) async {
    if (_isLoadingMoreParseFailures || !_hasMoreParseFailures) return;

    setState(() {
      _isLoadingMoreParseFailures = true;
      _loadMoreParseFailureError = null;
    });

    try {
      final page = await ref
          .read(financeRepositoryProvider)
          .fetchGmailParseFailurePage(
            GmailParseFailurePageRequest(
              householdId: householdId,
              limit: _parseFailurePageLimit,
              offset: _nextParseFailureOffset,
            ),
          );
      if (!mounted || _parseFailureHouseholdId != householdId) return;

      setState(() {
        _parseFailures = [..._parseFailures, ...page.items];
        _nextParseFailureOffset = page.nextOffset;
        _hasMoreParseFailures = page.hasMore;
        _isLoadingMoreParseFailures = false;
      });
    } catch (error) {
      if (!mounted || _parseFailureHouseholdId != householdId) return;

      setState(() {
        _loadMoreParseFailureError = error;
        _isLoadingMoreParseFailures = false;
      });
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

  Future<void> _showParseFailureBodyDialog({
    required BuildContext context,
    required GmailParseFailure failure,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) {
        return _GmailParseFailureBodyDialog(
          failure: failure,
          repository: ref.read(financeRepositoryProvider),
        );
      },
    );
  }

  Future<void> _ignoreParseFailure({
    required BuildContext context,
    required WidgetRef ref,
    required String householdId,
    required GmailParseFailure failure,
  }) async {
    try {
      await ref
          .read(financeRepositoryProvider)
          .ignoreGmailParseFailure(failureId: failure.failureId);
      if (mounted && _parseFailureHouseholdId == householdId) {
        setState(() {
          final beforeCount = _parseFailures.length;
          _parseFailures = _parseFailures
              .where((item) => item.failureId != failure.failureId)
              .toList(growable: false);
          if (_parseFailures.length < beforeCount &&
              _nextParseFailureOffset > 0) {
            _nextParseFailureOffset -= 1;
          }
        });
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ignored Gmail parse failure')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not ignore Gmail parse failure: $error'),
          ),
        );
      }
    }
  }
}

class _GmailParseFailuresViewState {
  const _GmailParseFailuresViewState({
    required this.items,
    required this.isInitialLoading,
    required this.initialError,
    required this.hasMore,
    required this.isLoadingMore,
    required this.loadMoreError,
  });

  final List<GmailParseFailure> items;
  final bool isInitialLoading;
  final Object? initialError;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? loadMoreError;

  bool get hasInitialError => initialError != null && items.isEmpty;
  bool get isWaitingForInitialPage =>
      isInitialLoading && items.isEmpty && initialError == null;
}

class _MerchantReviewPage extends StatelessWidget {
  const _MerchantReviewPage({
    required this.reviewItems,
    required this.parseFailures,
    required this.categories,
    required this.subcategories,
    required this.onRefresh,
    required this.onRetryParseFailures,
    required this.onLoadMoreParseFailures,
    required this.onViewParseFailureBody,
    required this.onCorrect,
    required this.onIgnoreParseFailure,
  });

  final AsyncValue<List<MerchantReviewItem>> reviewItems;
  final _GmailParseFailuresViewState parseFailures;
  final AsyncValue<List<CategoryOption>> categories;
  final AsyncValue<List<SubcategoryOption>> subcategories;
  final VoidCallback? onRefresh;
  final VoidCallback? onRetryParseFailures;
  final VoidCallback? onLoadMoreParseFailures;
  final ValueChanged<GmailParseFailure>? onViewParseFailureBody;
  final ValueChanged<MerchantReviewItem>? onCorrect;
  final ValueChanged<GmailParseFailure>? onIgnoreParseFailure;

  @override
  Widget build(BuildContext context) {
    return AppResponsiveBuilder(
      reserveBottomNavigationSpace: true,
      builder: (context, metrics) {
        return SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              _sliverBox(
                metrics: metrics,
                top: metrics.topPagePadding,
                bottom: metrics.sectionGap,
                child: _ReviewHeader(onRefresh: onRefresh),
              ),
              ..._contentSlivers(metrics),
              SliverToBoxAdapter(
                child: SizedBox(height: metrics.bottomPagePadding),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _contentSlivers(AppResponsiveMetrics metrics) {
    if (reviewItems.hasError) {
      return [
        _sliverBox(
          metrics: metrics,
          child: AppErrorState(
            title: 'Review queue unavailable',
            message: reviewItems.error.toString(),
          ),
        ),
      ];
    }

    if (parseFailures.hasInitialError) {
      return [
        _sliverBox(
          metrics: metrics,
          child: AppErrorState(
            title: 'Gmail parse failures unavailable',
            message: parseFailures.initialError.toString(),
            action: AppActionPill.secondary(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: onRetryParseFailures,
            ),
          ),
        ),
      ];
    }

    final items = reviewItems.value;
    if (items == null || parseFailures.isWaitingForInitialPage) {
      return [
        _sliverBox(
          metrics: metrics,
          child: const AppLoadingState(
            title: 'Loading review queue',
            message: 'Checking review items and Gmail parser diagnostics.',
          ),
        ),
      ];
    }

    final optionsReady = categories.hasValue && subcategories.hasValue;
    final loadedCategories = categories.value ?? const <CategoryOption>[];
    final failures = parseFailures.items;
    final slivers = <Widget>[
      _sliverBox(
        metrics: metrics,
        bottom: metrics.sectionGap,
        child: _ReviewMetrics(
          openReviewCount: items.length,
          categoryCount: loadedCategories.length,
          optionsReady: optionsReady,
        ),
      ),
    ];

    if (failures.isNotEmpty) {
      slivers.add(
        _sliverBox(
          metrics: metrics,
          bottom: metrics.sectionGap,
          child: _GmailParseFailuresCard(
            failures: failures,
            hasMore: parseFailures.hasMore,
            isLoadingMore: parseFailures.isLoadingMore,
            loadMoreError: parseFailures.loadMoreError,
            onLoadMore: onLoadMoreParseFailures,
            onRetryLoadMore: onLoadMoreParseFailures,
            onViewBody: onViewParseFailureBody,
            onIgnore: onIgnoreParseFailure,
          ),
        ),
      );
    }

    if (items.isEmpty) {
      if (failures.isEmpty) {
        slivers.add(
          _sliverBox(metrics: metrics, child: const _CaughtUpState()),
        );
      }

      return slivers;
    }

    slivers.add(
      SliverPadding(
        padding: EdgeInsets.symmetric(
          horizontal: metrics.horizontalPagePadding,
        ),
        sliver: SliverList.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];

            return _ConstrainedReviewChild(
              metrics: metrics,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: index == items.length - 1 ? 0 : 12,
                ),
                child: _ReviewItemCard(
                  key: ValueKey('review-queue-card-${item.id}'),
                  item: item,
                  canCorrect: optionsReady && onCorrect != null,
                  onCorrect: onCorrect == null ? null : () => onCorrect!(item),
                ),
              ),
            );
          },
        ),
      ),
    );

    return slivers;
  }
}

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({required this.onRefresh});

  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final heading = const AppDisplayHeading(
      title: 'Review',
      subtitle:
          'Help SpendLens classify recent transactions for cleaner insights.',
    );
    final settingsAction = IconButton(
      tooltip: 'Open settings',
      onPressed: () => context.go(SettingsScreen.routePath),
      icon: const Icon(Icons.settings_outlined),
    );
    final actions = [
      IconButton.filledTonal(
        tooltip: 'Refresh',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 24),
            Align(alignment: Alignment.topRight, child: settingsAction),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.end,
            children: actions,
          ),
        ),
      ],
    );
  }
}

class _ReviewMetrics extends StatelessWidget {
  const _ReviewMetrics({
    required this.openReviewCount,
    required this.categoryCount,
    required this.optionsReady,
  });

  final int openReviewCount;
  final int categoryCount;
  final bool optionsReady;

  @override
  Widget build(BuildContext context) {
    return MetricCardGrid(
      minTileWidth: 150,
      children: [
        MetricCard(
          label: 'Open Reviews',
          value: openReviewCount.toString(),
          icon: Icons.rule_folder_outlined,
          supportingText: openReviewCount == 1
              ? 'Item waiting'
              : 'Items waiting',
          tone: openReviewCount == 0
              ? MetricCardTone.positive
              : MetricCardTone.warning,
          width: null,
        ),
        MetricCard(
          label: 'Correction Data',
          value: optionsReady ? 'Ready' : 'Loading',
          icon: Icons.tune_outlined,
          supportingText: optionsReady
              ? _categorySummary(categoryCount)
              : 'Fetching categories',
          width: null,
        ),
      ],
    );
  }
}

class _GmailParseFailuresCard extends StatelessWidget {
  const _GmailParseFailuresCard({
    required this.failures,
    required this.hasMore,
    required this.isLoadingMore,
    required this.loadMoreError,
    required this.onLoadMore,
    required this.onRetryLoadMore,
    required this.onViewBody,
    required this.onIgnore,
  });

  final List<GmailParseFailure> failures;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? loadMoreError;
  final VoidCallback? onLoadMore;
  final VoidCallback? onRetryLoadMore;
  final ValueChanged<GmailParseFailure>? onViewBody;
  final ValueChanged<GmailParseFailure>? onIgnore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semanticColors = theme.extension<AppSemanticColors>();

    return AppContentCard(
      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 8,
            child: ColoredBox(
              color: semanticColors?.negative ?? theme.colorScheme.error,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.mark_email_unread_outlined,
                      color:
                          semanticColors?.negative ?? theme.colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gmail parse failures',
                            style: theme.textTheme.titleMedium?.copyWith(
                              letterSpacing: 0,
                            ),
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
                const SizedBox(height: 18),
                for (final failure in failures) ...[
                  _GmailParseFailureRow(
                    failure: failure,
                    onViewBody: onViewBody,
                    onIgnore: onIgnore,
                  ),
                  if (failure != failures.last) const Divider(height: 28),
                ],
                if (loadMoreError != null) ...[
                  const SizedBox(height: 18),
                  _ParseFailureLoadMoreError(
                    error: loadMoreError!,
                    onRetry: onRetryLoadMore,
                  ),
                ],
                if (loadMoreError == null && (hasMore || isLoadingMore)) ...[
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppActionPill.secondary(
                      label: isLoadingMore ? 'Loading more' : 'Load more',
                      icon: Icons.expand_more,
                      tooltip: isLoadingMore
                          ? 'Loading more Gmail parse failures'
                          : 'Load more Gmail parse failures',
                      isLoading: isLoadingMore,
                      onPressed: isLoadingMore ? null : onLoadMore,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GmailParseFailureRow extends StatelessWidget {
  const _GmailParseFailureRow({
    required this.failure,
    required this.onViewBody,
    required this.onIgnore,
  });

  final GmailParseFailure failure;
  final ValueChanged<GmailParseFailure>? onViewBody;
  final ValueChanged<GmailParseFailure>? onIgnore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(failure.subject, style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusChip(
              icon: Icons.account_balance_wallet_outlined,
              label: failure.candidateTypeLabel,
            ),
            StatusChip(
              icon: Icons.report_problem_outlined,
              label: failure.reasonLabel,
              tone: AppStatusTone.negative,
            ),
            StatusChip(
              icon: Icons.integration_instructions_outlined,
              label: failure.parserLabel,
            ),
          ],
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.end,
            children: [
              AppActionPill.primary(
                label: 'View email',
                icon: Icons.article_outlined,
                tooltip: 'View plain-text email body',
                onPressed: onViewBody == null
                    ? null
                    : () => onViewBody!(failure),
              ),
              AppActionPill.secondary(
                label: 'Ignore for now',
                icon: Icons.visibility_off_outlined,
                tooltip: 'Hide this parse failure',
                onPressed: onIgnore == null ? null : () => onIgnore!(failure),
              ),
            ],
          ),
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
      padding: const EdgeInsets.only(top: 5),
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

class _ParseFailureLoadMoreError extends StatelessWidget {
  const _ParseFailureLoadMoreError({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final retry = AppActionPill.secondary(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: onRetry,
            );
            final text = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not load more Gmail parse failures.',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(error.toString(), style: theme.textTheme.bodySmall),
              ],
            );

            if (constraints.hasBoundedWidth && constraints.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [text, const SizedBox(height: 12), retry],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: text),
                const SizedBox(width: 16),
                retry,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GmailParseFailureBodyDialog extends StatefulWidget {
  const _GmailParseFailureBodyDialog({
    required this.failure,
    required this.repository,
  });

  final GmailParseFailure failure;
  final FinanceRepository repository;

  @override
  State<_GmailParseFailureBodyDialog> createState() =>
      _GmailParseFailureBodyDialogState();
}

class _GmailParseFailureBodyDialogState
    extends State<_GmailParseFailureBodyDialog> {
  GmailParseFailureBody? _body;
  Object? _error;
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBody();
  }

  Future<void> _fetchBody() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final body = await widget.repository.fetchGmailParseFailureBody(
        failureId: widget.failure.failureId,
      );
      if (!mounted) return;

      setState(() {
        _body = body;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _body;
    final error = _error;

    return AppModalDialog(
      title: 'Email body',
      subtitle: widget.failure.subject,
      maxWidth: 720,
      expandToAvailableHeight: true,
      actions: [
        if (error != null)
          AppActionPill.primary(
            label: 'Retry',
            icon: Icons.refresh,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _fetchBody,
          ),
        AppActionPill.secondary(
          label: 'Close',
          icon: Icons.close,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: _GmailParseFailureBodyContent(
        failure: widget.failure,
        body: body,
        error: error,
        isLoading: _isLoading,
      ),
    );
  }
}

class _GmailParseFailureBodyContent extends StatelessWidget {
  const _GmailParseFailureBodyContent({
    required this.failure,
    required this.body,
    required this.error,
    required this.isLoading,
  });

  final GmailParseFailure failure;
  final GmailParseFailureBody? body;
  final Object? error;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading && body == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: 16),
              Text('Fetching email body'),
            ],
          ),
        ),
      );
    }

    if (error != null && body == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Email body unavailable', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(error.toString(), style: theme.textTheme.bodyMedium),
        ],
      );
    }

    final loadedBody = body;
    if (loadedBody == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusChip(
              icon: Icons.account_balance_wallet_outlined,
              label: failure.candidateTypeLabel,
            ),
            StatusChip(
              icon: Icons.report_problem_outlined,
              label: failure.reasonLabel,
              tone: AppStatusTone.negative,
            ),
            StatusChip(
              icon: Icons.integration_instructions_outlined,
              label: failure.parserLabel,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FailureDetailLine(
          icon: Icons.mail_outline,
          label: 'Mailbox ${loadedBody.mailboxEmail}',
        ),
        _FailureDetailLine(
          icon: Icons.alternate_email_outlined,
          label: loadedBody.messageFrom ?? loadedBody.senderEmail,
        ),
        _FailureDetailLine(
          icon: Icons.schedule_outlined,
          label: 'Received ${_formatReceivedAt(loadedBody.sourceReceivedAt)}',
        ),
        _FailureDetailLine(
          icon: Icons.email_outlined,
          label:
              'Message ${loadedBody.messageId ?? loadedBody.sourceMessageId}',
        ),
        const SizedBox(height: 18),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                loadedBody.plainTextBody.isEmpty
                    ? 'No plain-text body was returned.'
                    : loadedBody.plainTextBody,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({
    super.key,
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

    return AppContentCard(
      padding: EdgeInsets.zero,
      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
      semanticLabel: 'Review item ${item.statementMerchant}',
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 8,
            child: ColoredBox(color: _warningColor(context)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 24, 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide =
                    constraints.hasBoundedWidth && constraints.maxWidth >= 680;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _ReviewItemDetails(item: item)),
                      const SizedBox(width: 24),
                      SizedBox(
                        width: 224,
                        child: _ReviewItemActionPanel(
                          item: item,
                          canCorrect: canCorrect,
                          onCorrect: onCorrect,
                          alignEnd: true,
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ReviewItemDetails(item: item),
                    const SizedBox(height: 18),
                    _ReviewItemActionPanel(
                      item: item,
                      canCorrect: canCorrect,
                      onCorrect: onCorrect,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewItemDetails extends StatelessWidget {
  const _ReviewItemDetails({required this.item});

  final MerchantReviewItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final amount = LargeAmountText(
              formatMoney(item.netExpense),
              textAlign: TextAlign.right,
              semanticLabel: 'Net amount ${formatMoney(item.netExpense)}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                height: 1,
                color: theme.colorScheme.onSurface,
              ),
            );

            if (constraints.hasBoundedWidth && constraints.maxWidth < 420) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReviewMerchantText(item.statementMerchant),
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerRight, child: amount),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _ReviewMerchantText(item.statementMerchant)),
                const SizedBox(width: 16),
                SizedBox(width: 160, child: amount),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Source ${formatMoney(item.amount)} - ${dateString(item.transactionDate)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Needs Attention',
          style: theme.textTheme.labelLarge?.copyWith(
            color: _warningDeepColor(context),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(item.reason, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            IconChip(
              icon: Icons.storefront_outlined,
              label: item.currentMerchantName ?? 'Unknown merchant',
              backgroundColor: _classificationHighlight(context),
              foregroundColor: _classificationForeground(context),
              maxWidth: 260,
            ),
            IconChip(
              icon: Icons.category_outlined,
              label: item.currentCategoryName ?? 'Uncategorized',
              maxWidth: 260,
            ),
            IconChip(
              icon: Icons.sell_outlined,
              label: item.currentSubcategoryName ?? 'No subcategory',
              maxWidth: 260,
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewMerchantText extends StatelessWidget {
  const _ReviewMerchantText(this.merchant);

  final String merchant;

  @override
  Widget build(BuildContext context) {
    return Text(
      merchant.toUpperCase(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _ReviewItemActionPanel extends StatelessWidget {
  const _ReviewItemActionPanel({
    required this.item,
    required this.canCorrect,
    required this.onCorrect,
    this.alignEnd = false,
  });

  final MerchantReviewItem item;
  final bool canCorrect;
  final VoidCallback? onCorrect;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final panel = Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: StatusChip(
            icon: Icons.help_outline,
            label: '${_confidenceLabel(item.confidence)} Confidence',
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: AppActionPill.primary(
            label: 'Resolve',
            tooltip: canCorrect
                ? 'Resolve review item'
                : 'Category data is still loading',
            onPressed: canCorrect ? onCorrect : null,
          ),
        ),
      ],
    );

    if (!alignEnd) return panel;

    return Align(alignment: Alignment.topRight, child: panel);
  }
}

class _CaughtUpState extends StatelessWidget {
  const _CaughtUpState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppContentCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: ShapeDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: const OvalBorder(),
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "You're all caught up for now.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConstrainedReviewChild extends StatelessWidget {
  const _ConstrainedReviewChild({required this.metrics, required this.child});

  final AppResponsiveMetrics metrics;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: metrics.contentConstraints,
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

Widget _sliverBox({
  required AppResponsiveMetrics metrics,
  required Widget child,
  double top = 0,
  double bottom = 0,
}) {
  return SliverPadding(
    padding: EdgeInsets.fromLTRB(
      metrics.horizontalPagePadding,
      top,
      metrics.horizontalPagePadding,
      bottom,
    ),
    sliver: SliverToBoxAdapter(
      child: _ConstrainedReviewChild(metrics: metrics, child: child),
    ),
  );
}

String _categorySummary(int count) {
  if (count == 1) return '1 category ready';

  return '$count categories ready';
}

String _confidenceLabel(String value) {
  return switch (value.toLowerCase()) {
    'manual' => 'Manual',
    'high' => 'High',
    'medium' => 'Medium',
    'low' => 'Low',
    _ =>
      value.isEmpty ? 'Unknown' : value[0].toUpperCase() + value.substring(1),
  };
}

Color _warningColor(BuildContext context) {
  final semanticColors = Theme.of(context).extension<AppSemanticColors>();

  return semanticColors?.warning ?? AppThemeTokens.warning;
}

Color _warningDeepColor(BuildContext context) {
  final theme = Theme.of(context);

  return theme.brightness == Brightness.dark
      ? AppThemeTokens.warning
      : AppThemeTokens.warningDeep;
}

Color _classificationHighlight(BuildContext context) {
  final theme = Theme.of(context);

  return theme.brightness == Brightness.dark
      ? theme.colorScheme.primaryContainer
      : AppThemeTokens.primaryPale;
}

Color _classificationForeground(BuildContext context) {
  final theme = Theme.of(context);

  return theme.brightness == Brightness.dark
      ? theme.colorScheme.onPrimaryContainer
      : AppThemeTokens.positiveDeep;
}

String _formatReceivedAt(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '${local.year}-$month-$day $hour:$minute';
}
