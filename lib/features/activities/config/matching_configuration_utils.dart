import 'models/activity_configurations.dart';

List<MatchingPairConfig> prepareMatchingPairsForSave(
  Iterable<MatchingPairConfig> pairs,
) {
  return pairs
      .map(
        (pair) => MatchingPairConfig(
          id: pair.id,
          left: pair.left.trim(),
          right: pair.right.trim(),
          leftResourceReference: pair.leftResourceReference,
          rightResourceReference: pair.rightResourceReference,
        ),
      )
      .toList(growable: false);
}

bool hasDuplicateMatchingPairs(Iterable<MatchingPairConfig> pairs) {
  final keys = <String>{};
  for (final pair in pairs) {
    final key = '${pair.left.trim()}\u0000${pair.right.trim()}';
    if (!keys.add(key)) return true;
  }
  return false;
}
