import 'dart:math' as math;

import '../../data/repositories/finance_repository.dart';

const merchantCloseMatchThreshold = 0.82;
const merchantCloseMatchLeadMargin = 0.05;

enum MerchantNameMatchKind { exact, close }

final class MerchantNameMatch {
  const MerchantNameMatch({
    required this.kind,
    required this.merchant,
    required this.normalizedInput,
    required this.score,
    required this.nextBestScore,
  });

  final MerchantNameMatchKind kind;
  final MerchantOption merchant;
  final String normalizedInput;
  final double score;
  final double nextBestScore;
}

MerchantNameMatch? findMerchantNameMatch({
  required String input,
  required Iterable<MerchantOption> merchants,
}) {
  final normalizedInput = normalizeMerchantName(input);
  if (normalizedInput.isEmpty) return null;

  final candidates = <_ScoredMerchant>[];
  for (final merchant in merchants) {
    final normalizedMerchant = normalizeMerchantName(merchant.displayName);
    if (normalizedMerchant.isEmpty) continue;

    if (normalizedMerchant == normalizedInput) {
      return MerchantNameMatch(
        kind: MerchantNameMatchKind.exact,
        merchant: merchant,
        normalizedInput: normalizedInput,
        score: 1,
        nextBestScore: 0,
      );
    }

    candidates.add(
      _ScoredMerchant(
        merchant: merchant,
        score: _merchantNameSimilarity(normalizedInput, normalizedMerchant),
      ),
    );
  }
  if (candidates.isEmpty) return null;

  candidates.sort((a, b) => b.score.compareTo(a.score));
  final best = candidates.first;
  final nextBestScore = candidates.length > 1 ? candidates[1].score : 0.0;
  if (best.score < merchantCloseMatchThreshold ||
      best.score - nextBestScore < merchantCloseMatchLeadMargin) {
    return null;
  }

  return MerchantNameMatch(
    kind: MerchantNameMatchKind.close,
    merchant: best.merchant,
    normalizedInput: normalizedInput,
    score: best.score,
    nextBestScore: nextBestScore,
  );
}

String normalizeMerchantName(String value) {
  return value
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

double _merchantNameSimilarity(String left, String right) {
  if (left == right) return 1;

  final editSimilarity = _levenshteinSimilarity(left, right);
  final tokenSimilarity = _tokenPrefixSimilarity(
    left.split(' '),
    right.split(' '),
  );
  return math.max(editSimilarity, tokenSimilarity);
}

double _levenshteinSimilarity(String left, String right) {
  final maxLength = math.max(left.length, right.length);
  if (maxLength == 0) return 1;

  return 1 - (_levenshteinDistance(left, right) / maxLength);
}

int _levenshteinDistance(String left, String right) {
  if (left == right) return 0;
  if (left.isEmpty) return right.length;
  if (right.isEmpty) return left.length;

  var previous = List<int>.generate(right.length + 1, (index) => index);
  for (var leftIndex = 0; leftIndex < left.length; leftIndex += 1) {
    final current = List<int>.filled(right.length + 1, 0);
    current[0] = leftIndex + 1;

    for (var rightIndex = 0; rightIndex < right.length; rightIndex += 1) {
      final substitutionCost =
          left.codeUnitAt(leftIndex) == right.codeUnitAt(rightIndex) ? 0 : 1;
      current[rightIndex + 1] = math.min(
        math.min(current[rightIndex] + 1, previous[rightIndex + 1] + 1),
        previous[rightIndex] + substitutionCost,
      );
    }

    previous = current;
  }

  return previous.last;
}

double _tokenPrefixSimilarity(
  List<String> leftTokens,
  List<String> rightTokens,
) {
  if (leftTokens.isEmpty || rightTokens.isEmpty) return 0;

  final maxTokenCount = math.max(leftTokens.length, rightTokens.length);
  var score = 0.0;
  for (var index = 0; index < maxTokenCount; index += 1) {
    if (index >= leftTokens.length || index >= rightTokens.length) continue;

    final left = leftTokens[index];
    final right = rightTokens[index];
    if (left == right) {
      score += 1;
    } else if (_isUsefulPrefix(left, right) || _isUsefulPrefix(right, left)) {
      score += 0.94;
    } else {
      score += _levenshteinSimilarity(left, right);
    }
  }

  return score / maxTokenCount;
}

bool _isUsefulPrefix(String prefix, String value) {
  return prefix.length >= 3 && value.length >= 3 && value.startsWith(prefix);
}

final class _ScoredMerchant {
  const _ScoredMerchant({required this.merchant, required this.score});

  final MerchantOption merchant;
  final double score;
}
