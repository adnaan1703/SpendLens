import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/bootstrap/app_bootstrap.dart';
import '../data/repositories/household_repository.dart';
import '../features/ai/ai_screen.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/merchant_review/merchant_review_screen.dart';
import '../features/piggy_banks/piggy_banks_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/transactions/transactions_screen.dart';
import '../features/trends/trends_screen.dart';
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
        builder: (_, _) => const SignInScreen(),
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
            path: AiScreen.routePath,
            builder: (_, _) => const AiScreen(),
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
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading household context...'),
            ],
          ),
        ),
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.home_work_outlined,
                        size: 42,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Household setup failed',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () {
                          ref.invalidate(householdContextProvider);
                        },
                        child: const Text('Try again'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await ref.read(authRepositoryProvider).signOut();
                        },
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
