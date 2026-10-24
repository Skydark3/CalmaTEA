import '../../../activities/config/models/activity_configurations.dart';

class MatchingAnswerOption {
  final String id;
  final String text;

  const MatchingAnswerOption({required this.id, required this.text});
}

List<MatchingAnswerOption> matchingAnswerOptions(
  MatchingActivityConfig configuration,
) {
  return configuration.pairs
      .map((pair) => MatchingAnswerOption(id: pair.id, text: pair.right))
      .toList(growable: false);
}

List<MatchingAnswerOption> initialMatchingAnswerOrder(
  List<MatchingAnswerOption> answers,
) {
  if (answers.length < 2) return List.of(answers);
  return answers.reversed.toList(growable: true);
}

bool isMatchingAnswerCorrect(
  MatchingPairConfig pair,
  MatchingAnswerOption answer,
) {
  return _normalizeText(pair.right) == _normalizeText(answer.text);
}

String _normalizeText(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
