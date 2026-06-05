import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/household_repository.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/merchant_review/merchant_review_screen.dart';
import '../features/piggy_banks/piggy_banks_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/transactions/transactions_screen.dart';
import '../features/trends/trends_screen.dart';

class AppDestination {
  const AppDestination({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

const appDestinations = [
  AppDestination(
    label: 'Dashboard',
    path: DashboardScreen.routePath,
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  AppDestination(
    label: 'Transactions',
    path: TransactionsScreen.routePath,
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
  ),
  AppDestination(
    label: 'Trends',
    path: TrendsScreen.routePath,
    icon: Icons.show_chart_outlined,
    selectedIcon: Icons.show_chart,
  ),
  AppDestination(
    label: 'Review',
    path: MerchantReviewScreen.routePath,
    icon: Icons.rule_folder_outlined,
    selectedIcon: Icons.rule_folder,
  ),
  AppDestination(
    label: 'Piggy Banks',
    path: PiggyBanksScreen.routePath,
    icon: Icons.savings_outlined,
    selectedIcon: Icons.savings,
  ),
  AppDestination(
    label: 'Settings',
    path: SettingsScreen.routePath,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  ),
];

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.location,
    required this.householdContext,
    required this.child,
  });

  final String location;
  final HouseholdContext householdContext;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndexFor(location);
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      body: isWide
          ? Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) {
                      context.go(appDestinations[index].path);
                    },
                    leading: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
                      child: _HouseholdBadge(
                        householdName: householdContext.household.name,
                      ),
                    ),
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final destination in appDestinations)
                        NavigationRailDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.selectedIcon),
                          label: Text(destination.label),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            )
          : child,
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                context.go(appDestinations[index].path);
              },
              destinations: [
                for (final destination in appDestinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            ),
    );
  }

  int _selectedIndexFor(String path) {
    final index = appDestinations.indexWhere((destination) {
      return path == destination.path ||
          path.startsWith('${destination.path}/');
    });

    return index == -1 ? 0 : index;
  }
}

class _HouseholdBadge extends StatelessWidget {
  const _HouseholdBadge({required this.householdName});

  final String householdName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: householdName,
      child: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: const Icon(Icons.home_outlined),
      ),
    );
  }
}
