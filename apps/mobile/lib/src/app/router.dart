import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/bootstrap/app_bootstrap.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/household_repository.dart';
import '../features/ai/ai_screen.dart';
import '../features/activity/activity_screen.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/merchant_review/merchant_review_screen.dart';
import '../features/piggy_banks/piggy_banks_screen.dart';
import '../features/settings/settings_screen.dart';
import '../shared/widgets/app_primitives.dart';
import 'app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final bootstrap = ref.watch(appBootstrapProvider);
  final sessionState = ref.watch(authSessionProvider);

  return GoRouter(
    initialLocation: SignInScreen.routePath,
    redirect: (_, state) {
      final path = state.uri.path;
      final isSigningIn = path == SignInScreen.routePath;
      final hasSession = sessionState.value != null;

      if (!bootstrap.isSupabaseReady) {
        return isSigningIn ? null : SignInScreen.routePath;
      }

      if (sessionState.isLoading && !hasSession) {
        return isSigningIn ? null : SignInScreen.routePath;
      }

      if (sessionState.hasError) {
        return isSigningIn ? null : SignInScreen.routePath;
      }

      if (!hasSession) {
        return isSigningIn ? null : SignInScreen.routePath;
      }

      if (isSigningIn || path == '/') {
        return DashboardScreen.routePath;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: SignInScreen.routePath,
        pageBuilder: (context, state) =>
            _scaffoldBackgroundPage(context, state, const SignInScreen()),
      ),
      GoRoute(path: '/', redirect: (_, _) => DashboardScreen.routePath),
      ShellRoute(
        builder: (context, state, child) {
          return HouseholdGate(
            child: (context, householdContext) {
              return AppShell(
                location: state.uri.path,
                householdContext: householdContext,
                child: child,
              );
            },
          );
        },
        routes: [
          GoRoute(
            path: DashboardScreen.routePath,
            pageBuilder: (context, state) =>
                _scaffoldBackgroundPage(context, state, const DashboardScreen()),
          ),
          GoRoute(
            path: ActivityScreen.routePath,
            pageBuilder: (context, state) => _scaffoldBackgroundPage(
              context,
              state,
              ActivityScreen(
              initialFilters: ActivityScreen.initialFiltersFromUri(state.uri),
              ),
            ),
          ),
          GoRoute(
            path: MerchantReviewScreen.routePath,
            pageBuilder: (context, state) => _scaffoldBackgroundPage(
              context,
              state,
              const MerchantReviewScreen(),
            ),
          ),
          GoRoute(
            path: AiScreen.routePath,
            pageBuilder: (context, state) =>
                _scaffoldBackgroundPage(context, state, const AiScreen()),
          ),
          GoRoute(
            path: PiggyBanksScreen.routePath,
            pageBuilder: (context, state) => _scaffoldBackgroundPage(
              context,
              state,
              const PiggyBanksScreen(),
            ),
          ),
          GoRoute(
            path: SettingsScreen.routePath,
            pageBuilder: (context, state) =>
                _scaffoldBackgroundPage(context, state, const SettingsScreen()),
          ),
        ],
      ),
    ],
  );
});

Page<void> _scaffoldBackgroundPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  final theme = Theme.of(context);

  return MaterialPage(
    key: state.pageKey,
    child: ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: child,
    ),
  );
}

class HouseholdGate extends ConsumerWidget {
  const HouseholdGate({super.key, required this.child});

  final Widget Function(BuildContext context, HouseholdContext householdContext)
  child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextState = ref.watch(householdContextProvider);

    return switch (contextState) {
      AsyncValue(:final value?) => child(context, value),
      AsyncValue(hasError: true, :final error) => HouseholdErrorScreen(
        message: error.toString(),
      ),
      _ => const HouseholdLoadingScreen(),
    };
  }
}

class HouseholdLoadingScreen extends StatelessWidget {
  const HouseholdLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppGateScaffold(
      maxContentWidth: 520,
      child: AppLoadingState(
        title: 'Loading household context',
        message: 'Preparing your profile, household, and workspace.',
      ),
    );
  }
}

class HouseholdErrorScreen extends ConsumerWidget {
  const HouseholdErrorScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semanticColors = theme.extension<AppSemanticColors>();
    final negative = semanticColors?.negative ?? theme.colorScheme.error;
    final negativeContainer =
        semanticColors?.negativeContainer ?? theme.colorScheme.errorContainer;
    final onNegativeContainer = theme.colorScheme.onErrorContainer;

    return AppGateScaffold(
      maxContentWidth: 560,
      child: AppContentCard(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 56,
                height: 56,
                decoration: ShapeDecoration(
                  color: negativeContainer,
                  shape: const OvalBorder(),
                ),
                child: Icon(
                  Icons.home_work_outlined,
                  color: onNegativeContainer,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Household setup failed',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 0),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                AppActionPill.primary(
                  label: 'Try again',
                  icon: Icons.refresh,
                  onPressed: () {
                    ref.invalidate(householdContextProvider);
                  },
                ),
                AppActionPill.secondary(
                  label: 'Sign out',
                  icon: Icons.logout,
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signOut();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Your route will continue once the household context loads.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: negative),
            ),
          ],
        ),
      ),
    );
  }
}
