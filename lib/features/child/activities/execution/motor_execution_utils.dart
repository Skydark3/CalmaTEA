String formatMotorDuration(int totalSeconds) {
  if (totalSeconds <= 0) return '';

  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final parts = <String>[
    if (hours > 0) '$hours ${hours == 1 ? 'hora' : 'horas'}',
    if (minutes > 0) '$minutes ${minutes == 1 ? 'minuto' : 'minutos'}',
    if (seconds > 0) '$seconds ${seconds == 1 ? 'segundo' : 'segundos'}',
  ];

  if (parts.length == 1) return parts.single;
  if (parts.length == 2) return '${parts.first} y ${parts.last}';
  return '${parts[0]}, ${parts[1]} y ${parts[2]}';
}
