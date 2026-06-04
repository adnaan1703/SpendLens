import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/dashboard_screen.dart';
import '../features/merchant_review/merchant_review_screen.dart';
import '../features/piggy_banks/piggy_banks_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/transactions/transactions_screen.dart';
import '../features/trends/trends_screen.dart';
import 'app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: DashboardScreen.routePath,
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, _) => DashboardScreen.routePath,
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(
            location: state.uri.path,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: DashboardScreen.routePath,
            builder: (_, _) => const DashboardScreen(),
          ),
          GoRoute(
            path: TransactionsScreen.routePath,
            builder: (_, _) => const TransactionsScreen(),
          ),
          GoRoute(
            path: TrendsScreen.routePath,
            builder: (_, _) => const TrendsScreen(),
          ),
          GoRoute(
            path: MerchantReviewScreen.routePath,
            builder: (_, _) => const MerchantReviewScreen(),
          ),
          GoRoute(
            path: PiggyBanksScreen.routePath,
            builder: (_, _) => const PiggyBanksScreen(),
          ),
          GoRoute(
            path: SettingsScreen.routePath,
            builder: (_, _) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
