import 'package:flutter_riverpod/flutter_riverpod.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return const PlaceholderFinanceRepository();
});

abstract interface class FinanceRepository {
  Future<int> fetchOpenReviewCount();
}

class PlaceholderFinanceRepository implements FinanceRepository {
  const PlaceholderFinanceRepository();

  @override
  Future<int> fetchOpenReviewCount() async {
    return 0;
  }
}
