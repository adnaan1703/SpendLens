import 'package:flutter/material.dart';

import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/empty_state.dart';

class PiggyBanksScreen extends StatelessWidget {
  const PiggyBanksScreen({super.key});

  static const routePath = '/piggy-banks';

  @override
  Widget build(BuildContext context) {
    return const AppPage(
      title: 'Piggy Banks',
      subtitle: 'Manual ledgers',
      child: EmptyState(
        icon: Icons.savings_outlined,
        title: 'No piggy banks',
        message: 'Future-expense ledgers will appear here.',
      ),
    );
  }
}
