import 'package:flutter/material.dart';

import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/empty_state.dart';

class MerchantReviewScreen extends StatelessWidget {
  const MerchantReviewScreen({super.key});

  static const routePath = '/merchant-review';

  @override
  Widget build(BuildContext context) {
    return const AppPage(
      title: 'Merchant Review',
      subtitle: 'Open mappings',
      child: EmptyState(
        icon: Icons.rule_folder_outlined,
        title: 'No review items',
        message: 'Low-confidence merchant mappings will appear here.',
      ),
    );
  }
}
