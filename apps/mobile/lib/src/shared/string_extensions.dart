extension TitleCaseString on String {
  String toTitleCaseWords() {
    final normalized = trim();
    if (normalized.isEmpty) return normalized;

    final words = normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) {
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        });

    return words.join(' ');
  }
}
