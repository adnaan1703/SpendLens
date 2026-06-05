import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.supportingText,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? supportingText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: SizedBox(
        width: 250,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: theme.colorScheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label, style: theme.textTheme.labelLarge),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value, style: theme.textTheme.headlineSmall),
                ),
              ),
              if (supportingText != null) ...[
                const SizedBox(height: 8),
                Text(supportingText!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
