abstract interface class ActivityConfiguration {
  int get version;

  bool get isValid;

  Map<String, dynamic> toMap();
}
