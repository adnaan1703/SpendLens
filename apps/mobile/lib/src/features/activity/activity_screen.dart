import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/household_repository.dart';
import '../../shared/widgets/app_page.dart';
import '../transactions/transactions_screen.dart';
import '../trends/trends_screen.dart';
import 'activity_route.dart';

enum _ActivityMode { list, charts }

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({
    super.key,
    this.initialFilters = const TransactionInitialFilters(),
  });

  static const routePath = activityRoutePath;
  static TransactionInitialFilters initialFiltersFromUri(Uri uri) {
    return TransactionInitialFilters.fromUri(uri);
  }

  final TransactionInitialFilters initialFilters;

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  _ActivityMode _mode = _ActivityMode.list;

  @override
  Widget build(BuildContext context) {
    final householdName = ref
        .watch(householdContextProvider)
        .value
        ?.household
        .name;

    return AppPage(
      title: 'Activity',
      subtitle: householdName ?? 'List and charts',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ActivityModeSelector(
            mode: _mode,
            onChanged: (mode) {
              setState(() {
                _mode = mode;
              });
            },
          ),
          const SizedBox(height: 20),
          switch (_mode) {
            _ActivityMode.list => TransactionListPane(
              initialFilters: widget.initialFilters,
              clearFiltersPath: ActivityScreen.routePath,
            ),
            _ActivityMode.charts => const ActivityChartsPane(),
          },
        ],
      ),
    );
  }
}

class _ActivityModeSelector extends StatelessWidget {
  const _ActivityModeSelector({required this.mode, required this.onChanged});

  final _ActivityMode mode;
  final ValueChanged<_ActivityMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            Expanded(
              child: _ActivityModeButton(
                label: 'List',
                selected: mode == _ActivityMode.list,
                onTap: () => onChanged(_ActivityMode.list),
              ),
            ),
            Expanded(
              child: _ActivityModeButton(
                label: 'Charts',
                selected: mode == _ActivityMode.charts,
                onTap: () => onChanged(_ActivityMode.charts),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityModeButton extends StatelessWidget {
  const _ActivityModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? theme.colorScheme.surface : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Center(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
