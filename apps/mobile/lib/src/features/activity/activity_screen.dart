import 'package:flutter/material.dart';

import '../transactions/transactions_screen.dart';
import 'activity_route.dart';

class ActivityScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return TransactionListPane(
      initialFilters: initialFilters,
      clearFiltersPath: routePath,
    );
  }
}
