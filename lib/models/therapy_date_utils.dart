DateTime normalizeTherapyDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

DateTime therapyDateForStorage(DateTime date) {
  final normalized = normalizeTherapyDate(date);
  return DateTime(normalized.year, normalized.month, normalized.day, 12);
}

DateTime therapyDateFromStorage(DateTime date) {
  final localDate = date.toLocal();
  return normalizeTherapyDate(localDate);
}

DateTime clampTherapyDate(
  DateTime date, {
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final normalized = normalizeTherapyDate(date);
  final normalizedFirst = normalizeTherapyDate(firstDate);
  final normalizedLast = normalizeTherapyDate(lastDate);

  if (normalized.isBefore(normalizedFirst)) return normalizedFirst;
  if (normalized.isAfter(normalizedLast)) return normalizedLast;
  return normalized;
}

bool isTherapyDateInRange(
  DateTime date, {
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final normalized = normalizeTherapyDate(date);
  final normalizedFirst = normalizeTherapyDate(firstDate);
  final normalizedLast = normalizeTherapyDate(lastDate);
  return !normalized.isBefore(normalizedFirst) &&
      !normalized.isAfter(normalizedLast);
}
