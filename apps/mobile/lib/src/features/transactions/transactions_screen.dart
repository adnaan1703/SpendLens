import 'package:flutter/material.dart';

import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/empty_state.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  static const routePath = '/transactions';

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Transactions',
      subtitle: 'Search and filters',
      child: Column(
        children: [
          TextField(
            enabled: false,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Merchant search',
            ),
          ),
          const SizedBox(height: 16),
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No transactions',
            message: 'Imported card transactions will appear here.',
          ),
        ],
      ),
    );
  }
}
