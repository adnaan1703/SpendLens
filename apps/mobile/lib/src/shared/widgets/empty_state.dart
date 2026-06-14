import 'package:flutter/material.dart';

import 'app_card.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppEntranceMotion(
      child: AppContentCard(
        padding: EdgeInsets.all(compact ? 20 : 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacks =
                constraints.hasBoundedWidth && constraints.maxWidth < 420;
            final iconFrame = Container(
              width: compact ? 40 : 48,
              height: compact ? 40 : 48,
              decoration: ShapeDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: const OvalBorder(),
              ),
              child: Icon(
                icon,
                color: theme.colorScheme.onPrimaryContainer,
                size: compact ? 22 : 26,
              ),
            );
            final text = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(message, style: theme.textTheme.bodyMedium),
                if (action != null) ...[const SizedBox(height: 16), action!],
              ],
            );

            if (stacks) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [iconFrame, const SizedBox(height: 16), text],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconFrame,
                const SizedBox(width: 16),
                Expanded(child: text),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.title = 'Loading', this.message});

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppEntranceMotion(
      child: AppContentCard(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                if (message != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: title,
      message: message,
      action: action,
    );
  }
}
