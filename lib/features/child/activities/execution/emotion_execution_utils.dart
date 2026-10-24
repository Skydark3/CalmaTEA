String normalizeEmotionAnswer(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

bool emotionAnswersMatch(String answer, String expectedValue) {
  return normalizeEmotionAnswer(answer) ==
      normalizeEmotionAnswer(expectedValue);
}
