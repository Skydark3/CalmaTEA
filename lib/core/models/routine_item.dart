/// Modelo que representa un ítem de la rutina diaria del usuario.
class RoutineItem {
  final String id;
  final String title;
  final String iconEmoji;
  final String time; // Ej: "08:00"
  RoutineStatus status;

  RoutineItem({
    required this.id,
    required this.title,
    required this.iconEmoji,
    required this.time,
    this.status = RoutineStatus.pending,
  });

  bool get isCompleted => status == RoutineStatus.completed;

  RoutineItem copyWith({RoutineStatus? status}) {
    return RoutineItem(
      id: id,
      title: title,
      iconEmoji: iconEmoji,
      time: time,
      status: status ?? this.status,
    );
  }
}

enum RoutineStatus { pending, inProgress, completed }
