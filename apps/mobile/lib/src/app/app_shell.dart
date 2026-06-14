import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/household_repository.dart';
import '../features/activity/activity_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/merchant_review/merchant_review_screen.dart';
import '../features/piggy_banks/piggy_banks_screen.dart';
import '../features/settings/settings_screen.dart';
import '../shared/string_extensions.dart';
import '../shared/widgets/responsive.dart';

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
    label: 'Activity',
    path: ActivityScreen.routePath,
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
  ),
  AppDestination(
    label: 'Review',
    path: MerchantReviewScreen.routePath,
    icon: Icons.rule_folder_outlined,
    selectedIcon: Icons.rule_folder,
  ),
  AppDestination(
    label: 'Vaults',
    path: PiggyBanksScreen.routePath,
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
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
    final isSettingsRoute =
        location == SettingsScreen.routePath ||
        location.startsWith('${SettingsScreen.routePath}/');

    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final isWide =
            AppResponsiveBreakpoints.classForWidth(layoutWidth) !=
            AppWindowSizeClass.mobile;
        final showPrimaryNavigation = !isSettingsRoute;

        return Scaffold(
          body: isWide && showPrimaryNavigation
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
                            householdName: householdContext
                                .household
                                .name
                                .toTitleCaseWords(),
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
          bottomNavigationBar: isWide || !showPrimaryNavigation
              ? null
              : NavigationBar(
                  selectedIndex: selectedIndex ?? 0,
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
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
      },
    );
  }

  int? _selectedIndexFor(String path) {
    final index = appDestinations.indexWhere((destination) {
      return path == destination.path ||
          path.startsWith('${destination.path}/');
    });

    return index == -1 ? null : index;
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
