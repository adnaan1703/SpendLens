import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_primitives.dart';
import 'data/auth_repository.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  static const routePath = '/sign-in';

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on AuthException catch (error) {
      _setError(error.message);
    } on AuthUnavailableException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Google sign-in could not be started.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setError(String message) {
    if (!mounted) return;

    setState(() {
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(appBootstrapProvider);
    final config = ref.watch(appConfigProvider);
    final canSignIn = bootstrap.isSupabaseReady && !_isLoading;

    return AppGateScaffold(
      maxContentWidth: 960,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final usesWideLayout =
              constraints.hasBoundedWidth && constraints.maxWidth >= 760;
          final brand = _AuthBrand(environmentLabel: config.environment.label);
          final card = _SignInCard(
            canSignIn: canSignIn,
            isLoading: _isLoading,
            errorMessage: _errorMessage,
            bootstrap: bootstrap,
            onSignIn: _signInWithGoogle,
          );

          if (!usesWideLayout) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [brand, const SizedBox(height: 24), card],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: brand),
              const SizedBox(width: 40),
              SizedBox(width: 420, child: card),
            ],
          );
        },
      ),
    );
  }
}

class _AuthBrand extends StatelessWidget {
  const _AuthBrand({required this.environmentLabel});

  final String environmentLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: ShapeDecoration(
            color: theme.colorScheme.primary,
            shape: const OvalBorder(),
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            color: AppThemeTokens.onPrimary,
            size: 30,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          AppConfig.appName,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Household expense intelligence for Android.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        _EnvironmentBadge(label: environmentLabel),
      ],
    );
  }
}

class _EnvironmentBadge extends StatelessWidget {
  const _EnvironmentBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          'Environment: $label',
          style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 0),
        ),
      ),
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({
    required this.canSignIn,
    required this.isLoading,
    required this.errorMessage,
    required this.bootstrap,
    required this.onSignIn,
  });

  final bool canSignIn;
  final bool isLoading;
  final String? errorMessage;
  final AppBootstrap bootstrap;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppContentCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sign in',
            style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 0),
          ),
          const SizedBox(height: 8),
          Text(
            'Use the Google account configured for your Supabase development '
            'project.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: canSignIn ? onSignIn : null,
            icon: isLoading
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.login),
            label: Text(
              isLoading ? 'Opening Google...' : 'Continue with Google',
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            _AuthNotice(
              icon: Icons.error_outline,
              title: 'Sign-in issue',
              message: errorMessage!,
              isError: true,
            ),
          ],
          if (!bootstrap.isSupabaseReady) ...[
            const SizedBox(height: 16),
            _AuthNotice(
              icon: Icons.info_outline,
              title: 'Supabase setup required',
              message: switch (bootstrap.supabaseStatus) {
                SupabaseStatus.failed =>
                  'Initialization failed. Check your runtime defines and '
                      'local Supabase status.',
                SupabaseStatus.notConfigured =>
                  'Provide SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY to '
                      'enable auth.',
                SupabaseStatus.ready => '',
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _AuthNotice extends StatelessWidget {
  const _AuthNotice({
    required this.icon,
    required this.title,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semanticColors = theme.extension<AppSemanticColors>();
    final background = isError
        ? semanticColors?.negativeContainer ?? theme.colorScheme.errorContainer
        : theme.colorScheme.primaryContainer;
    final foreground = isError
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimaryContainer;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: foreground.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
